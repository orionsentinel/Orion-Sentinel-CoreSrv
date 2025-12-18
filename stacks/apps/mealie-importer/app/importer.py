#!/usr/bin/env python3
"""
Mealie Recipe Importer - Main Application

A production-ready recipe importer for Mealie that:
- Does ONE-TIME backfill of newest 75 recipes per site for 20 sites
- Runs MONTHLY to fetch new recipes (delta) and import them into Mealie
- Uses Mealie API token auth (Bearer token)
- Forces Accept-Language: en-US header
- Maintains idempotency via SQLite state database
- Respects robots.txt and implements polite crawling
"""

import argparse
import os
import sys
import signal
import json
from pathlib import Path
from datetime import datetime

from logger import setup_logging, get_logger
from state_db import StateDB
from mealie_api import MealieAPI
from discovery import DiscoveryManager
from domain_filters import DomainFilterManager
from sources_loader import load_sources

# Initialize logging
use_json_logs = os.getenv('JSON_LOGS', 'false').lower() == 'true'
setup_logging(use_json=use_json_logs)
logger = get_logger(__name__)


class GracefulExit:
    """Handle graceful shutdown on SIGTERM/SIGINT"""
    shutdown_requested = False

    @classmethod
    def request_shutdown(cls, signum, frame):
        logger.info(f"Received signal {signum}, requesting graceful shutdown...")
        cls.shutdown_requested = True


class MealieImporter:
    """Main importer class orchestrating the recipe import process"""

    def __init__(self, config_dir: Path, data_dir: Path):
        """
        Initialize the importer.

        Args:
            config_dir: Path to configuration files (sources.yaml)
            data_dir: Path to data directory (SQLite DB, logs)
        """
        self.config_dir = config_dir
        self.data_dir = data_dir

        # Load environment configuration
        self.mealie_url = os.getenv('MEALIE_BASE_URL', 'http://mealie:9000')
        self.mealie_token = os.getenv('MEALIE_IMPORTER_TOKEN', '')

        if not self.mealie_token:
            logger.error("MEALIE_IMPORTER_TOKEN environment variable is required!")
            sys.exit(1)

        # Load import limits
        self.backfill_per_site = int(os.getenv('BACKFILL_PER_SITE', '75'))
        self.backfill_total_cap = int(os.getenv('BACKFILL_TOTAL_CAP', '1500'))
        self.monthly_per_site = int(os.getenv('MONTHLY_PER_SITE', '40'))
        self.monthly_total_cap = int(os.getenv('MONTHLY_TOTAL_CAP', '800'))

        # Throttling settings
        self.throttle_seconds = float(os.getenv('THROTTLE_SECONDS', '1.0'))
        self.request_timeout = int(os.getenv('REQUEST_TIMEOUT', '30'))
        self.user_agent = os.getenv(
            'USER_AGENT',
            'OrionSentinelMealieImporter/1.0 (+local homelab)'
        )

        # Initialize components
        self.state_db = StateDB(data_dir / 'importer_state.db')
        self.mealie = MealieAPI(
            self.mealie_url,
            self.mealie_token,
            timeout=self.request_timeout
        )
        self.sources = load_sources(config_dir / 'sources.yaml')
        self.domain_filters = DomainFilterManager()
        self.discovery = DiscoveryManager(
            user_agent=self.user_agent,
            throttle_seconds=self.throttle_seconds,
            timeout=self.request_timeout
        )

        logger.info("MealieImporter initialized")
        logger.info(f"  Mealie URL: {self.mealie_url}")
        logger.info(f"  Sources: {len(self.sources)} configured")
        logger.info(f"  Backfill: {self.backfill_per_site}/site, {self.backfill_total_cap} total cap")
        logger.info(f"  Monthly: {self.monthly_per_site}/site, {self.monthly_total_cap} total cap")
        logger.info(f"  Throttle: {self.throttle_seconds}s between requests")

    def run(
        self,
        mode: str = 'backfill',
        dry_run: bool = False,
        force_url: str = None,
        force_domain: str = None,
        reset_domain: str = None
    ):
        """
        Run the importer.

        Args:
            mode: 'backfill' for initial import, 'monthly' for delta updates
            dry_run: If True, discover but don't import
            force_url: Force import of specific URL even if already imported
            force_domain: Force reimport of all URLs from domain
            reset_domain: Reset state for a domain (clear from DB)
        """
        run_start = datetime.utcnow()
        run_id = self.state_db.start_run(mode)

        logger.info("=" * 70)
        logger.info(f"Starting Mealie Recipe Import - Mode: {mode}")
        logger.info(f"  Run ID: {run_id}")
        logger.info(f"  Dry Run: {dry_run}")
        if force_url:
            logger.info(f"  Force URL: {force_url}")
        if force_domain:
            logger.info(f"  Force Domain: {force_domain}")
        if reset_domain:
            logger.info(f"  Reset Domain: {reset_domain}")
        logger.info("=" * 70)

        # Handle reset domain
        if reset_domain:
            count = self.state_db.reset_domain(reset_domain)
            logger.info(f"Reset {count} URLs for domain: {reset_domain}")

        # Test Mealie connection
        if not self.mealie.test_connection():
            logger.error("Cannot connect to Mealie API")
            self.state_db.complete_run(run_id, 0, 0, 0, 0, "Failed to connect to Mealie")
            return False

        # Ensure tags and categories exist
        if not dry_run:
            self._ensure_organizers()

        # Set limits based on mode
        if mode == 'backfill':
            per_site_limit = self.backfill_per_site
            total_cap = self.backfill_total_cap
        else:
            per_site_limit = self.monthly_per_site
            total_cap = self.monthly_total_cap

        # Handle force URL
        if force_url:
            return self._import_single_url(run_id, force_url, dry_run)

        # Handle force domain
        if force_domain:
            # Get all URLs for this domain and mark for reimport
            self.state_db.mark_domain_for_reimport(force_domain)
            logger.info(f"Marked domain {force_domain} for reimport")

        # Discover and import recipes
        stats = {
            'discovered': 0,
            'filtered': 0,
            'skipped': 0,
            'imported': 0,
            'failed': 0,
            'queued': 0
        }

        total_imported = 0

        for source in self.sources:
            if GracefulExit.shutdown_requested:
                logger.info("Shutdown requested, stopping import...")
                break

            if total_imported >= total_cap:
                logger.info(f"Reached total cap of {total_cap} imports")
                break

            source_name = source['name']
            source_key = source['key']
            logger.info(f"\n--- Processing source: {source_name} ---")

            try:
                # Discover URLs from this source
                discovered_urls = self.discovery.discover(
                    source,
                    limit=per_site_limit * 2  # Discover more, filter later
                )
                stats['discovered'] += len(discovered_urls)
                logger.info(f"Discovered {len(discovered_urls)} URLs from {source_name}")

                # Filter URLs
                filtered_urls = []
                for url in discovered_urls:
                    if self.domain_filters.is_valid_recipe_url(url, source_key):
                        filtered_urls.append(url)
                    else:
                        stats['filtered'] += 1

                logger.info(f"After filtering: {len(filtered_urls)} valid recipe URLs")

                # Check already imported (unless force_domain matches this source)
                new_urls = []
                for url in filtered_urls:
                    # Skip already imported unless we're forcing this domain
                    should_check = True
                    if force_domain:
                        # Check if this URL is from the forced domain
                        from urllib.parse import urlparse
                        url_domain = urlparse(url).netloc.lower().replace('www.', '')
                        if force_domain.lower() in url_domain:
                            should_check = False  # Don't skip even if imported

                    if should_check and self.state_db.is_url_imported(url):
                        stats['skipped'] += 1
                    else:
                        new_urls.append(url)
                filtered_urls = new_urls

                logger.info(f"New URLs to import: {len(filtered_urls)}")

                # Limit per site
                urls_to_import = filtered_urls[:per_site_limit]
                remaining_cap = total_cap - total_imported
                urls_to_import = urls_to_import[:remaining_cap]

                # Import URLs
                for url in urls_to_import:
                    if GracefulExit.shutdown_requested:
                        break

                    result = self._import_url(
                        url,
                        source_name,
                        source_key,
                        dry_run=dry_run
                    )

                    if result == 'imported':
                        stats['imported'] += 1
                        total_imported += 1
                    elif result == 'queued':
                        stats['queued'] += 1
                    elif result == 'failed':
                        stats['failed'] += 1
                    elif result == 'skipped':
                        stats['skipped'] += 1

            except Exception as e:
                logger.error(f"Error processing source {source_name}: {e}", exc_info=True)
                continue

        # Complete run
        run_duration = (datetime.utcnow() - run_start).total_seconds()
        self.state_db.complete_run(
            run_id,
            stats['discovered'],
            stats['imported'],
            stats['failed'],
            stats['skipped'],
            None
        )

        # Log summary
        logger.info("\n" + "=" * 70)
        logger.info("Import Complete - Summary")
        logger.info("=" * 70)
        logger.info(f"  Duration: {run_duration:.1f} seconds")
        logger.info(f"  Discovered: {stats['discovered']}")
        logger.info(f"  Filtered out: {stats['filtered']}")
        logger.info(f"  Skipped (already imported): {stats['skipped']}")
        logger.info(f"  Imported: {stats['imported']}")
        logger.info(f"  Failed: {stats['failed']}")
        logger.info(f"  Queued: {stats['queued']}")
        logger.info("=" * 70)

        # Write structured log summary
        self._write_log_summary(stats, run_duration)

        return stats['failed'] == 0

    def _ensure_organizers(self):
        """Ensure required tags and categories exist in Mealie"""
        logger.info("Ensuring organizers (tags/categories) exist...")

        # Source tags
        for source in self.sources:
            tag_name = f"source:{source['key']}"
            self.mealie.ensure_tag(tag_name)

            # Cuisine/style tags
            for tag in source.get('tags', []):
                self.mealie.ensure_tag(tag)

            # Categories
            for category in source.get('categories', []):
                self.mealie.ensure_category(category)

    def _import_url(
        self,
        url: str,
        source_name: str,
        source_key: str,
        dry_run: bool = False
    ) -> str:
        """
        Import a single URL.

        Returns: 'imported', 'failed', 'queued', or 'skipped'
        """
        logger.info(f"Importing: {url}")

        if dry_run:
            logger.info(f"  [DRY RUN] Would import: {url}")
            return 'skipped'

        # Get tags and categories for this source
        tags = [f"source:{source_key}"]
        categories = []
        for source in self.sources:
            if source['key'] == source_key:
                # Add source-specific tags (excluding the source: tag we already added)
                source_tags = [t for t in source.get('tags', []) if not t.startswith('source:')]
                tags.extend(source_tags)
                categories = source.get('categories', [])
                break

        # Try URL import first
        try:
            result = self.mealie.import_recipe_url(url, tags=tags, categories=categories)

            if result.get('success'):
                recipe_slug = result.get('slug', '')
                self.state_db.record_import(
                    url,
                    source_key,
                    status='imported',
                    recipe_slug=recipe_slug
                )
                logger.info(f"  ✓ Imported: {result.get('name', url)}")
                return 'imported'

            elif result.get('status_code') == 202:
                # Bulk import queued
                self.state_db.record_import(
                    url,
                    source_key,
                    status='queued'
                )
                logger.info(f"  ⊙ Queued for import: {url}")
                return 'queued'

        except Exception as e:
            logger.warning(f"  URL import failed for {url}: {e}")

        # Fallback to HTML import
        logger.info(f"  Trying HTML fallback for: {url}")
        try:
            html_content = self.discovery.fetch_html(url)
            if html_content:
                result = self.mealie.import_recipe_html(
                    url,
                    html_content,
                    tags=tags,
                    categories=categories
                )

                if result.get('success'):
                    import hashlib
                    html_hash = hashlib.sha256(html_content.encode()).hexdigest()[:16]
                    self.state_db.record_import(
                        url,
                        source_key,
                        status='imported_html',
                        recipe_slug=result.get('slug', ''),
                        html_hash=html_hash
                    )
                    logger.info(f"  ✓ Imported via HTML: {result.get('name', url)}")
                    return 'imported'

        except Exception as e:
            logger.error(f"  HTML import also failed for {url}: {e}")

        # Record failure
        self.state_db.record_import(
            url,
            source_key,
            status='failed',
            last_error=str(e) if 'e' in locals() else 'Unknown error'
        )
        logger.error(f"  ✗ Failed to import: {url}")
        return 'failed'

    def _import_single_url(self, run_id: int, url: str, dry_run: bool) -> bool:
        """Import a single forced URL"""
        logger.info(f"Force importing single URL: {url}")

        # Determine source from URL
        source_key = 'unknown'
        for source in self.sources:
            for domain in source.get('domains', []):
                if domain in url:
                    source_key = source['key']
                    break

        result = self._import_url(url, 'Force Import', source_key, dry_run)
        success = result in ('imported', 'queued')

        self.state_db.complete_run(
            run_id,
            discovered=1,
            imported=1 if success else 0,
            failed=0 if success else 1,
            skipped=0,
            error_message=None if success else f"Failed to import {url}"
        )

        return success

    def _write_log_summary(self, stats: dict, duration: float):
        """Write structured JSON log summary"""
        log_file = self.data_dir / 'import.log'

        summary = {
            'timestamp': datetime.utcnow().isoformat(),
            'duration_seconds': duration,
            **stats
        }

        try:
            with open(log_file, 'a') as f:
                f.write(json.dumps(summary) + '\n')
        except Exception as e:
            logger.warning(f"Failed to write log summary: {e}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='Mealie Recipe Importer - Automated recipe discovery and import'
    )
    parser.add_argument(
        '--mode',
        choices=['backfill', 'monthly'],
        default='backfill',
        help='Import mode: backfill (initial) or monthly (delta)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Discover URLs but do not import'
    )
    parser.add_argument(
        '--force-url',
        type=str,
        help='Force import of specific URL'
    )
    parser.add_argument(
        '--force-domain',
        type=str,
        help='Force reimport of all URLs from domain'
    )
    parser.add_argument(
        '--reset-domain',
        type=str,
        help='Reset state for a domain'
    )

    args = parser.parse_args()

    # Set up signal handlers
    signal.signal(signal.SIGTERM, GracefulExit.request_shutdown)
    signal.signal(signal.SIGINT, GracefulExit.request_shutdown)

    # Configuration paths
    config_dir = Path('/config')
    data_dir = Path('/data')

    # Ensure data directory exists
    data_dir.mkdir(parents=True, exist_ok=True)

    logger.info("Mealie Recipe Importer starting")
    logger.info(f"  Mode: {args.mode}")
    logger.info(f"  Config: {config_dir}")
    logger.info(f"  Data: {data_dir}")

    # Create and run importer
    importer = MealieImporter(config_dir, data_dir)
    success = importer.run(
        mode=args.mode,
        dry_run=args.dry_run,
        force_url=args.force_url,
        force_domain=args.force_domain,
        reset_domain=args.reset_domain
    )

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
