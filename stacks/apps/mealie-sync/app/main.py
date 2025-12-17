#!/usr/bin/env python3
"""
Mealie Recipe Sync - Main application
Periodically discovers and imports recipes from configured sources
"""

import os
import sys
import time
import yaml
from pathlib import Path
from typing import List, Dict

from logger import setup_logging, get_logger
from state import StateManager
from mealie_client import MealieClient
from crawler import RecipeCrawler, RateLimiter, URLNormalizer
from sources import create_source

# Initialize logging
use_json_logs = os.getenv('JSON_LOGS', 'false').lower() == 'true'
setup_logging(use_json=use_json_logs)
logger = get_logger(__name__)


class RecipeSyncManager:
    """Manages the recipe synchronization process"""
    
    def __init__(self, config_dir: Path, state_dir: Path):
        """
        Initialize sync manager
        
        Args:
            config_dir: Path to configuration files
            state_dir: Path to state/data directory
        """
        self.config_dir = config_dir
        self.state_dir = state_dir
        
        # Load configuration
        self.sources_config = self._load_sources_config()
        
        # Initialize state manager
        db_path = state_dir / 'state.db'
        self.state = StateManager(db_path)
        
        # Get environment configuration
        mealie_url = os.getenv('MEALIE_BASE_URL', 'http://mealie:9000')
        mealie_token = os.getenv('MEALIE_API_TOKEN', '')
        
        if not mealie_token:
            logger.error("MEALIE_API_TOKEN environment variable is required!")
            sys.exit(1)
        
        # Get sync parameters
        self.max_recipes_per_run = int(os.getenv('MAX_NEW_RECIPES_PER_RUN', '10'))
        timeout = int(os.getenv('REQUEST_TIMEOUT_SECONDS', '30'))
        rate_limit = float(os.getenv('RATE_LIMIT_SECONDS_PER_DOMAIN', '2.0'))
        user_agent = os.getenv('USER_AGENT', 
            'Mozilla/5.0 (compatible; MealieRecipeSync/1.0; +https://github.com/orionsentinel/Orion-Sentinel-CoreSrv)')
        dry_run = os.getenv('DRY_RUN', 'false').lower() == 'true'
        
        # Initialize Mealie client
        self.mealie = MealieClient(mealie_url, mealie_token, timeout, dry_run)
        
        # Initialize crawler
        rate_limiter = RateLimiter(rate_limit)
        self.crawler = RecipeCrawler(rate_limiter, user_agent, timeout)
        
        # Store dry_run flag
        self.dry_run = dry_run
        
        logger.info("RecipeSyncManager initialized")
        logger.info(f"  Mealie URL: {mealie_url}")
        logger.info(f"  Max recipes per run: {self.max_recipes_per_run}")
        logger.info(f"  Rate limit: {rate_limit}s per domain")
        logger.info(f"  Timeout: {timeout}s")
        logger.info(f"  Dry run: {dry_run}")
    
    def _load_sources_config(self) -> Dict:
        """Load recipe sources configuration"""
        sources_file = self.config_dir / 'sources.yaml'
        
        if not sources_file.exists():
            # Try recipe_sources.yaml as well (per requirements)
            sources_file = self.config_dir / 'recipe_sources.yaml'
        
        if not sources_file.exists():
            logger.error(f"Configuration file not found: {sources_file}")
            logger.error("Please create config/sources.yaml or config/recipe_sources.yaml")
            sys.exit(1)
        
        try:
            with open(sources_file) as f:
                config = yaml.safe_load(f)
                if not config or 'sources' not in config:
                    logger.error(f"Invalid configuration: missing 'sources' key")
                    sys.exit(1)
                return config
        except Exception as e:
            logger.error(f"Error loading configuration: {e}")
            sys.exit(1)
    
    def discover_urls(self) -> List[str]:
        """
        Discover recipe URLs from all enabled sources
        
        Returns:
            List of discovered URLs
        """
        all_urls = []
        
        for source_config in self.sources_config.get('sources', []):
            # Check if source is enabled (default to True)
            if not source_config.get('enabled', True):
                continue
            
            name = source_config.get('name', 'Unnamed Source')
            
            # Create source instance
            source = create_source(name, source_config)
            if not source:
                continue
            
            try:
                # Discover URLs from this source
                urls = source.get_recipe_urls(self.crawler)
                
                # Mark URLs as seen and associate with domain
                for url in urls:
                    domain = URLNormalizer.extract_domain(url)
                    self.state.mark_url_seen(url, domain)
                
                all_urls.extend(urls)
                
            except Exception as e:
                logger.error(f"Error processing source '{name}': {e}", exc_info=True)
                continue
        
        return all_urls
    
    def sync(self):
        """Run a single sync cycle"""
        logger.info("=" * 70)
        logger.info("Starting Mealie Recipe Sync")
        logger.info("=" * 70)
        
        # Start sync run tracking
        run_id = self.state.start_sync_run()
        
        try:
            # Test Mealie connection
            if not self.mealie.test_connection():
                logger.error("Cannot proceed without Mealie connection")
                self.state.complete_sync_run(run_id, 0, 0, 0, "Failed to connect to Mealie")
                return
            
            # Discover URLs from all sources
            logger.info("Discovering recipe URLs from sources...")
            discovered_urls = self.discover_urls()
            logger.info(f"Total URLs discovered: {len(discovered_urls)}")
            
            # Deduplicate
            unique_urls = list(dict.fromkeys(discovered_urls))  # Preserve order
            logger.info(f"Unique URLs after deduplication: {len(unique_urls)}")
            
            # Filter out already imported
            imported_urls = self.state.get_imported_urls()
            new_urls = [url for url in unique_urls if url not in imported_urls]
            logger.info(f"New URLs not yet imported: {len(new_urls)}")
            
            if not new_urls:
                logger.info("No new recipes to import")
                self.state.complete_sync_run(run_id, len(discovered_urls), 0, 0)
                return
            
            # Limit imports per run
            urls_to_import = new_urls[:self.max_recipes_per_run]
            logger.info(f"Importing up to {len(urls_to_import)} recipes (limit: {self.max_recipes_per_run})")
            
            if self.dry_run:
                logger.info("[DRY RUN] Would import the following URLs:")
                for i, url in enumerate(urls_to_import, 1):
                    logger.info(f"  {i}. {url}")
                logger.info("[DRY RUN] Skipping actual import")
                self.state.complete_sync_run(run_id, len(discovered_urls), 0, 0)
                return
            
            # Import recipes
            imported_count = 0
            failed_count = 0
            
            for i, url in enumerate(urls_to_import, 1):
                logger.info(f"[{i}/{len(urls_to_import)}] Processing: {url}")
                
                try:
                    recipe = self.mealie.import_recipe_from_url(url)
                    
                    if recipe:
                        # Record success
                        recipe_name = recipe.get('name', 'Unknown')
                        source_name = None  # Could be enhanced to track source
                        
                        self.state.record_import(url, recipe_name, source_name)
                        self.state.record_attempt(url, success=True)
                        imported_count += 1
                    else:
                        # Record failure
                        self.state.record_attempt(url, success=False, 
                                                 error_message="Import failed")
                        failed_count += 1
                    
                    # Small delay between imports to be polite
                    time.sleep(2)
                    
                except Exception as e:
                    logger.error(f"Error importing {url}: {e}", exc_info=True)
                    self.state.record_attempt(url, success=False, 
                                             error_message=str(e))
                    failed_count += 1
            
            # Complete sync run
            self.state.complete_sync_run(run_id, len(discovered_urls), 
                                        imported_count, failed_count)
            
            # Log summary
            logger.info("=" * 70)
            logger.info(f"Sync complete!")
            logger.info(f"  Discovered: {len(discovered_urls)} URLs")
            logger.info(f"  Imported: {imported_count} recipes")
            logger.info(f"  Failed: {failed_count} recipes")
            
            # Show overall stats
            stats = self.state.get_stats()
            logger.info(f"  Total imported to date: {stats['total_imports']}")
            logger.info("=" * 70)
            
        except Exception as e:
            logger.error(f"Fatal error during sync: {e}", exc_info=True)
            self.state.complete_sync_run(run_id, 0, 0, 0, str(e))


def main():
    """Main entry point"""
    # Get configuration paths
    config_dir = Path('/config')
    state_dir = Path('/data')
    
    # Get sync interval
    interval_minutes = int(os.getenv('SYNC_INTERVAL_MINUTES', '1440'))  # Default: 24 hours
    
    logger.info(f"Mealie Recipe Sync starting")
    logger.info(f"  Sync interval: {interval_minutes} minutes")
    logger.info(f"  Config directory: {config_dir}")
    logger.info(f"  State directory: {state_dir}")
    
    # Create sync manager
    manager = RecipeSyncManager(config_dir, state_dir)
    
    # Run sync loop
    while True:
        try:
            manager.sync()
        except Exception as e:
            logger.error(f"Unhandled error during sync: {e}", exc_info=True)
        
        # Wait for next sync
        logger.info(f"Next sync in {interval_minutes} minutes")
        logger.info("")
        time.sleep(interval_minutes * 60)


if __name__ == '__main__':
    main()
