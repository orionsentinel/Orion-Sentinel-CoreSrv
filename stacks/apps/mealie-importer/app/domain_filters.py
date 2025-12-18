#!/usr/bin/env python3
"""
Domain URL Filters

Loads and applies per-domain allowlist/denylist regex patterns from allowlist.yaml.
Implements aggressive default-deny policy:
- Only import URLs matching per-domain allowlist patterns
- Exclude obvious non-recipe paths via common deny patterns
"""

import re
from pathlib import Path
from typing import Dict, List, Pattern, Optional, Any
from urllib.parse import urlparse

import yaml

from logger import get_logger

logger = get_logger(__name__)


class DomainFilterManager:
    """Manages URL filtering based on domain-specific rules from allowlist.yaml"""

    # Mapping from site key to domain(s)
    SITE_KEY_TO_DOMAINS = {
        'ottolenghi': ['ottolenghi.co.uk'],
        'guardian_food': ['theguardian.com'],
        'meerasodha': ['meerasodha.com'],
        'thehappyfoodie': ['thehappyfoodie.co.uk'],
        'akis': ['akispetretzikis.com'],
        'recipetineats': ['recipetineats.com'],
        'greatbritishchefs': ['greatbritishchefs.com'],
        'bbcgoodfood': ['bbcgoodfood.com'],
        'themediterraneandish': ['themediterraneandish.com'],
        'seriouseats': ['seriouseats.com'],
        'bonappetit': ['bonappetit.com'],
        'saveur': ['saveur.com'],
        'feastingathome': ['feastingathome.com'],
        'olivemagazine': ['olivemagazine.com'],
        'spainonafork': ['spainonafork.com'],
        'patijinich': ['patijinich.com'],
        'rickbayless': ['rickbayless.com'],
        'hotthaikitchen': ['hot-thai-kitchen.com'],
        'rasamalaysia': ['rasamalaysia.com'],
        'thewoksoflife': ['thewoksoflife.com'],
    }

    def __init__(self, config_dir: Path = None):
        """
        Initialize filter manager.

        Args:
            config_dir: Path to config directory containing allowlist.yaml
        """
        self._common_deny: List[Pattern] = []
        self._common_deny_query: List[Pattern] = []
        self._site_rules: Dict[str, Dict[str, List[Pattern]]] = {}
        self._domain_to_site_key: Dict[str, str] = {}

        # Build reverse mapping
        for site_key, domains in self.SITE_KEY_TO_DOMAINS.items():
            for domain in domains:
                self._domain_to_site_key[domain] = site_key

        # Load allowlist if config_dir provided
        if config_dir:
            self._load_allowlist(config_dir / 'allowlist.yaml')
        else:
            # Try default path
            default_path = Path('/config/allowlist.yaml')
            if default_path.exists():
                self._load_allowlist(default_path)
            else:
                logger.warning("No allowlist.yaml found, using permissive filtering")

    def _load_allowlist(self, path: Path):
        """Load and compile patterns from allowlist.yaml"""
        if not path.exists():
            logger.warning(f"Allowlist not found: {path}")
            return

        try:
            with open(path) as f:
                config = yaml.safe_load(f) or {}
        except Exception as e:
            logger.error(f"Error loading allowlist: {e}")
            return

        # Load common deny patterns
        common = config.get('common', {})
        for pattern in common.get('deny_regex', []):
            try:
                self._common_deny.append(re.compile(pattern, re.IGNORECASE))
            except re.error as e:
                logger.warning(f"Invalid common deny regex '{pattern}': {e}")

        for pattern in common.get('deny_query_regex', []):
            try:
                self._common_deny_query.append(re.compile(pattern, re.IGNORECASE))
            except re.error as e:
                logger.warning(f"Invalid common deny query regex '{pattern}': {e}")

        # Load per-site rules
        sites = config.get('sites', {})
        for site_key, rules in sites.items():
            self._site_rules[site_key] = {
                'allow': [],
                'deny': []
            }

            for pattern in rules.get('allow_regex', []):
                try:
                    self._site_rules[site_key]['allow'].append(
                        re.compile(pattern, re.IGNORECASE)
                    )
                except re.error as e:
                    logger.warning(f"Invalid allow regex for {site_key} '{pattern}': {e}")

            for pattern in rules.get('deny_regex', []):
                try:
                    self._site_rules[site_key]['deny'].append(
                        re.compile(pattern, re.IGNORECASE)
                    )
                except re.error as e:
                    logger.warning(f"Invalid deny regex for {site_key} '{pattern}': {e}")

        logger.info(f"Loaded allowlist with {len(self._site_rules)} site rules, "
                    f"{len(self._common_deny)} common deny patterns")

    def is_valid_recipe_url(self, url: str, source_key: str = None) -> bool:
        """
        Check if URL is a valid recipe URL.

        Args:
            url: URL to check
            source_key: Site key for source-specific rules

        Returns:
            True if URL passes filters (allowed and not denied)
        """
        # Parse URL
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        if domain.startswith('www.'):
            domain = domain[4:]

        # Get site key from domain if not provided
        if not source_key:
            source_key = self._domain_to_site_key.get(domain)

        # Check common deny patterns first
        for pattern in self._common_deny:
            if pattern.search(url):
                logger.debug(f"URL denied by common pattern: {url}")
                return False

        # Check common deny query patterns
        for pattern in self._common_deny_query:
            if pattern.search(url):
                logger.debug(f"URL denied by common query pattern: {url}")
                return False

        # If we have site-specific rules, apply them
        if source_key and source_key in self._site_rules:
            rules = self._site_rules[source_key]

            # Check site-specific deny patterns first
            for pattern in rules.get('deny', []):
                if pattern.search(url):
                    logger.debug(f"URL denied by site pattern for {source_key}: {url}")
                    return False

            # Check site-specific allow patterns
            allow_patterns = rules.get('allow', [])
            if allow_patterns:
                for pattern in allow_patterns:
                    if pattern.search(url):
                        return True
                # No allow pattern matched - reject
                logger.debug(f"URL not in allowlist for {source_key}: {url}")
                return False

        # No site-specific rules or unknown site - default deny
        if source_key:
            logger.debug(f"No rules for site {source_key}, denying: {url}")
            return False

        # Unknown domain - reject
        logger.debug(f"Unknown domain, denying: {url}")
        return False

    def get_site_key_for_url(self, url: str) -> Optional[str]:
        """
        Get site key for a URL based on domain.

        Args:
            url: URL to check

        Returns:
            Site key or None
        """
        parsed = urlparse(url)
        domain = parsed.netloc.lower()
        if domain.startswith('www.'):
            domain = domain[4:]

        return self._domain_to_site_key.get(domain)

    def add_site_rules(
        self,
        site_key: str,
        domains: List[str],
        allow_patterns: List[str],
        deny_patterns: List[str] = None
    ):
        """
        Add custom site rules at runtime.

        Args:
            site_key: Site identifier
            domains: List of domains for this site
            allow_patterns: List of allow regex patterns
            deny_patterns: List of deny regex patterns
        """
        # Update domain mapping
        for domain in domains:
            domain = domain.lower().replace('www.', '')
            self._domain_to_site_key[domain] = site_key

        # Compile patterns
        self._site_rules[site_key] = {
            'allow': [],
            'deny': []
        }

        for pattern in allow_patterns:
            try:
                self._site_rules[site_key]['allow'].append(
                    re.compile(pattern, re.IGNORECASE)
                )
            except re.error as e:
                logger.warning(f"Invalid allow regex '{pattern}': {e}")

        for pattern in (deny_patterns or []):
            try:
                self._site_rules[site_key]['deny'].append(
                    re.compile(pattern, re.IGNORECASE)
                )
            except re.error as e:
                logger.warning(f"Invalid deny regex '{pattern}': {e}")

        logger.info(f"Added custom rules for site: {site_key}")
