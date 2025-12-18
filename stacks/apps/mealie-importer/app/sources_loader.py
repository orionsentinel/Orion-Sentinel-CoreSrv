#!/usr/bin/env python3
"""
Sources Configuration Loader

Loads and validates the 20 recipe source configurations from sources.yaml
and allowlist.yaml (authoritative configurations).
"""

import sys
from pathlib import Path
from typing import List, Dict, Any, Optional

import yaml

from logger import get_logger

logger = get_logger(__name__)


class SourcesConfig:
    """Container for loaded sources configuration including defaults and allowlist"""

    def __init__(self, config_dir: Path):
        self.config_dir = config_dir
        self.defaults: Dict[str, Any] = {}
        self.sources: List[Dict[str, Any]] = []
        self.allowlist: Dict[str, Any] = {}

        self._load_sources()
        self._load_allowlist()

    def _load_sources(self):
        """Load sources.yaml"""
        sources_path = self.config_dir / 'sources.yaml'
        if not sources_path.exists():
            logger.error(f"Sources configuration not found: {sources_path}")
            sys.exit(1)

        try:
            with open(sources_path) as f:
                config = yaml.safe_load(f)
        except Exception as e:
            logger.error(f"Error loading sources config: {e}")
            sys.exit(1)

        if not config:
            logger.error("Invalid sources configuration: empty file")
            sys.exit(1)

        # Load defaults
        self.defaults = config.get('defaults', {})

        # Load sites
        sites = config.get('sites', [])
        if not isinstance(sites, list):
            logger.error("Invalid sources configuration: 'sites' must be a list")
            sys.exit(1)

        # Validate and enhance each source
        for site in sites:
            validated = self._validate_source(site)
            if validated:
                self.sources.append(validated)

        logger.info(f"Loaded {len(self.sources)} sources from sources.yaml")

    def _load_allowlist(self):
        """Load allowlist.yaml"""
        allowlist_path = self.config_dir / 'allowlist.yaml'
        if not allowlist_path.exists():
            logger.warning(f"Allowlist not found: {allowlist_path}, using empty allowlist")
            self.allowlist = {'common': {}, 'sites': {}}
            return

        try:
            with open(allowlist_path) as f:
                self.allowlist = yaml.safe_load(f) or {}
        except Exception as e:
            logger.error(f"Error loading allowlist: {e}")
            self.allowlist = {'common': {}, 'sites': {}}

        logger.info(f"Loaded allowlist with {len(self.allowlist.get('sites', {}))} site rules")

    def _validate_source(self, source: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Validate and normalize a source configuration"""
        if 'key' not in source:
            logger.warning("Source missing 'key' field, skipping")
            return None

        if 'name' not in source:
            source['name'] = source['key']

        # Extract discovery config
        discovery = source.get('discovery', {})

        # Build normalized source dict
        normalized = {
            'key': source['key'],
            'name': source['name'],
            'base_url': source.get('base', ''),
            'categories': source.get('categories', []),
            'tags': source.get('tags', []),
            'rss_urls': discovery.get('rss_candidates', []),
            'listing_urls': discovery.get('listing_pages', []),
            'sitemap_urls': discovery.get('sitemap_candidates', []),
            'enabled': source.get('enabled', True),
        }

        # Extract domain from base URL
        if normalized['base_url']:
            from urllib.parse import urlparse
            parsed = urlparse(normalized['base_url'])
            normalized['domains'] = [parsed.netloc.lower().replace('www.', '')]
        else:
            normalized['domains'] = []

        return normalized

    def get_defaults(self) -> Dict[str, Any]:
        """Get defaults configuration"""
        return self.defaults

    def get_sources(self) -> List[Dict[str, Any]]:
        """Get list of enabled sources"""
        return [s for s in self.sources if s.get('enabled', True)]

    def get_allowlist_for_site(self, site_key: str) -> Dict[str, Any]:
        """Get allowlist rules for a specific site"""
        sites = self.allowlist.get('sites', {})
        return sites.get(site_key, {})

    def get_common_allowlist(self) -> Dict[str, Any]:
        """Get common allowlist rules (applied to all sites)"""
        return self.allowlist.get('common', {})


def load_sources(config_path: Path) -> List[Dict[str, Any]]:
    """
    Load source configurations from YAML file.

    Args:
        config_path: Path to sources.yaml

    Returns:
        List of source configuration dictionaries
    """
    # Handle both file path and directory path
    if config_path.is_file():
        config_dir = config_path.parent
    else:
        config_dir = config_path

    config = SourcesConfig(config_dir)
    return config.get_sources()


def load_full_config(config_dir: Path) -> SourcesConfig:
    """
    Load full configuration including sources, defaults, and allowlist.

    Args:
        config_dir: Path to config directory

    Returns:
        SourcesConfig object with all configuration
    """
    return SourcesConfig(config_dir)


def get_default_limits() -> Dict[str, int]:
    """
    Get default import limits from sources.yaml defaults.

    Returns:
        Dict with limit values
    """
    return {
        'backfill_per_site': 75,
        'monthly_max_new_per_site': 40,
        'backfill_total_cap': 1500,
        'monthly_total_cap': 800,
        'bulk_batch_size': 25
    }
