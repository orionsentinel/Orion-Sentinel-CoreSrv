#!/usr/bin/env python3
"""
Recipe URL Discovery Module

Discovers recipe URLs using multiple strategies:
1. RSS feeds (common paths: /feed, /rss, /atom.xml, etc.)
2. Sitemaps (from robots.txt or common paths)
3. HTML listing fallback (category pages)

Implements:
- Rate limiting per domain
- Exponential backoff on 429/503
- robots.txt respect
- Date-based sorting (newest first)
"""

import re
import time
import hashlib
import xml.etree.ElementTree as ET
from datetime import datetime
from collections import defaultdict
from typing import List, Dict, Optional, Tuple
from urllib.parse import urlparse, urljoin
from urllib.robotparser import RobotFileParser

import requests
import feedparser
from bs4 import BeautifulSoup

from logger import get_logger

logger = get_logger(__name__)


class RobotsTxtChecker:
    """Checks robots.txt compliance"""

    def __init__(self, user_agent: str):
        self.user_agent = user_agent
        self._parsers: Dict[str, RobotFileParser] = {}
        self._sitemaps: Dict[str, List[str]] = {}

    def is_allowed(self, url: str) -> bool:
        """Check if URL is allowed by robots.txt"""
        parsed = urlparse(url)
        base_url = f"{parsed.scheme}://{parsed.netloc}"

        if base_url not in self._parsers:
            self._fetch_robots(base_url)

        parser = self._parsers.get(base_url)
        if parser:
            return parser.can_fetch(self.user_agent, url)
        return True  # Allow if no robots.txt

    def get_sitemaps(self, base_url: str) -> List[str]:
        """Get sitemap URLs from robots.txt"""
        parsed = urlparse(base_url)
        base = f"{parsed.scheme}://{parsed.netloc}"

        if base not in self._sitemaps:
            self._fetch_robots(base)

        return self._sitemaps.get(base, [])

    def _fetch_robots(self, base_url: str):
        """Fetch and parse robots.txt"""
        robots_url = f"{base_url}/robots.txt"

        try:
            response = requests.get(robots_url, timeout=10)
            if response.status_code == 200:
                parser = RobotFileParser()
                parser.parse(response.text.splitlines())
                self._parsers[base_url] = parser

                # Extract sitemap URLs
                sitemaps = []
                for line in response.text.splitlines():
                    line_lower = line.lower().strip()
                    if line_lower.startswith('sitemap:'):
                        sitemap_url = line.split(':', 1)[1].strip()
                        sitemaps.append(sitemap_url)
                self._sitemaps[base_url] = sitemaps
            else:
                self._parsers[base_url] = None
                self._sitemaps[base_url] = []
        except Exception as e:
            logger.debug(f"Error fetching robots.txt from {base_url}: {e}")
            self._parsers[base_url] = None
            self._sitemaps[base_url] = []


class RateLimiter:
    """Rate limiter with exponential backoff"""

    def __init__(self, base_delay: float = 1.0):
        self.base_delay = base_delay
        self.last_request: Dict[str, float] = defaultdict(float)
        self.backoff_multiplier: Dict[str, float] = defaultdict(lambda: 1.0)

    def wait_if_needed(self, domain: str):
        """Wait before making request to domain"""
        now = time.time()
        delay = self.base_delay * self.backoff_multiplier[domain]
        time_since_last = now - self.last_request[domain]

        if time_since_last < delay:
            wait_time = delay - time_since_last
            logger.debug(f"Rate limiting: waiting {wait_time:.2f}s for {domain}")
            time.sleep(wait_time)

        self.last_request[domain] = time.time()

    def record_success(self, domain: str):
        """Record successful request, reduce backoff"""
        self.backoff_multiplier[domain] = max(1.0, self.backoff_multiplier[domain] * 0.9)

    def record_rate_limit(self, domain: str):
        """Record rate limit (429/503), increase backoff"""
        self.backoff_multiplier[domain] = min(32.0, self.backoff_multiplier[domain] * 2)
        logger.warning(f"Rate limited on {domain}, backoff now {self.backoff_multiplier[domain]}x")


class DiscoveryManager:
    """Manages URL discovery from various sources"""

    RSS_PATHS = ['/feed', '/rss', '/feed.xml', '/rss.xml', '/atom.xml', '/feed/atom', '/index.xml']
    SITEMAP_PATHS = ['/sitemap.xml', '/sitemap_index.xml', '/sitemap-index.xml', '/post-sitemap.xml']

    def __init__(self, user_agent: str, throttle_seconds: float, timeout: int):
        self.user_agent = user_agent
        self.timeout = timeout

        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': user_agent,
            'Accept-Language': 'en-US,en;q=0.9'
        })

        self.rate_limiter = RateLimiter(throttle_seconds)
        self.robots_checker = RobotsTxtChecker(user_agent)

    def discover(self, source: Dict, limit: int = 150) -> List[str]:
        """
        Discover recipe URLs from a source.

        Args:
            source: Source configuration dict
            limit: Maximum URLs to return

        Returns:
            List of discovered URLs (newest first)
        """
        source_name = source['name']
        domains = source.get('domains', [])
        base_url = source.get('base_url', '')

        if not base_url and domains:
            base_url = f"https://{domains[0]}"

        logger.info(f"Discovering URLs from: {source_name}")

        all_urls: List[Tuple[str, Optional[datetime]]] = []

        # Strategy 1: Try RSS feeds
        rss_urls = source.get('rss_urls', [])
        if not rss_urls:
            # Try to discover RSS feeds
            for path in self.RSS_PATHS:
                rss_url = urljoin(base_url, path)
                if self._url_exists(rss_url):
                    rss_urls.append(rss_url)
                    break

        for rss_url in rss_urls:
            urls = self._parse_rss(rss_url, limit)
            all_urls.extend(urls)
            if len(all_urls) >= limit:
                break

        # Strategy 2: Try sitemaps
        if len(all_urls) < limit:
            # First check robots.txt for sitemaps
            sitemap_urls = self.robots_checker.get_sitemaps(base_url)

            # Also try common paths
            if not sitemap_urls:
                for path in self.SITEMAP_PATHS:
                    sitemap_url = urljoin(base_url, path)
                    if self._url_exists(sitemap_url):
                        sitemap_urls.append(sitemap_url)

            for sitemap_url in sitemap_urls:
                urls = self._parse_sitemap(sitemap_url, limit - len(all_urls))
                all_urls.extend(urls)
                if len(all_urls) >= limit:
                    break

        # Strategy 3: HTML listing fallback
        if len(all_urls) < limit:
            listing_urls = source.get('listing_urls', [])
            for listing_url in listing_urls:
                urls = self._crawl_listing_page(listing_url, domains, limit - len(all_urls))
                all_urls.extend(urls)
                if len(all_urls) >= limit:
                    break

        # Sort by date (newest first) and deduplicate
        all_urls.sort(key=lambda x: x[1] or datetime.min, reverse=True)
        seen = set()
        unique_urls = []
        for url, _ in all_urls:
            normalized = self._normalize_url(url)
            if normalized not in seen:
                seen.add(normalized)
                unique_urls.append(normalized)
                if len(unique_urls) >= limit:
                    break

        logger.info(f"Discovered {len(unique_urls)} unique URLs from {source_name}")
        return unique_urls

    def fetch_html(self, url: str) -> Optional[str]:
        """
        Fetch HTML content of a URL.

        Args:
            url: URL to fetch

        Returns:
            HTML content or None
        """
        if not self.robots_checker.is_allowed(url):
            logger.warning(f"URL blocked by robots.txt: {url}")
            return None

        domain = urlparse(url).netloc
        self.rate_limiter.wait_if_needed(domain)

        try:
            response = self.session.get(url, timeout=self.timeout)

            if response.status_code in (429, 503):
                self.rate_limiter.record_rate_limit(domain)
                return None

            response.raise_for_status()
            self.rate_limiter.record_success(domain)
            return response.text

        except Exception as e:
            logger.warning(f"Error fetching {url}: {e}")
            return None

    def _url_exists(self, url: str) -> bool:
        """Check if URL exists (HEAD request)"""
        domain = urlparse(url).netloc
        self.rate_limiter.wait_if_needed(domain)

        try:
            response = self.session.head(url, timeout=5, allow_redirects=True)
            return response.status_code == 200
        except Exception:
            return False

    def _parse_rss(self, rss_url: str, limit: int) -> List[Tuple[str, Optional[datetime]]]:
        """Parse RSS/Atom feed"""
        logger.debug(f"Parsing RSS: {rss_url}")

        domain = urlparse(rss_url).netloc
        self.rate_limiter.wait_if_needed(domain)

        try:
            feed = feedparser.parse(rss_url)
            urls = []

            for entry in feed.entries[:limit]:
                url = entry.get('link', '')
                if not url:
                    continue

                # Parse date
                pub_date = None
                if entry.get('published_parsed'):
                    try:
                        pub_date = datetime(*entry.published_parsed[:6])
                    except Exception:
                        pass
                elif entry.get('updated_parsed'):
                    try:
                        pub_date = datetime(*entry.updated_parsed[:6])
                    except Exception:
                        pass

                urls.append((url, pub_date))

            self.rate_limiter.record_success(domain)
            logger.debug(f"Found {len(urls)} entries in RSS feed")
            return urls

        except Exception as e:
            logger.warning(f"Error parsing RSS {rss_url}: {e}")
            return []

    def _parse_sitemap(self, sitemap_url: str, limit: int) -> List[Tuple[str, Optional[datetime]]]:
        """Parse sitemap XML"""
        logger.debug(f"Parsing sitemap: {sitemap_url}")

        domain = urlparse(sitemap_url).netloc
        self.rate_limiter.wait_if_needed(domain)

        try:
            response = self.session.get(sitemap_url, timeout=self.timeout)

            if response.status_code in (429, 503):
                self.rate_limiter.record_rate_limit(domain)
                return []

            response.raise_for_status()
            self.rate_limiter.record_success(domain)

            # Parse XML
            root = ET.fromstring(response.content)

            # Handle sitemap index
            ns = {'sm': 'http://www.sitemaps.org/schemas/sitemap/0.9'}

            # Check if this is a sitemap index
            sitemaps = root.findall('.//sm:sitemap/sm:loc', ns)
            if sitemaps:
                # It's a sitemap index, parse each sitemap
                all_urls = []
                for sitemap_loc in sitemaps[:5]:  # Limit to first 5 sitemaps
                    sub_urls = self._parse_sitemap(sitemap_loc.text, limit - len(all_urls))
                    all_urls.extend(sub_urls)
                    if len(all_urls) >= limit:
                        break
                return all_urls

            # Parse regular sitemap
            urls = []
            for url_elem in root.findall('.//sm:url', ns)[:limit * 2]:
                loc = url_elem.find('sm:loc', ns)
                if loc is None:
                    continue

                url = loc.text

                # Parse lastmod date
                lastmod = None
                lastmod_elem = url_elem.find('sm:lastmod', ns)
                if lastmod_elem is not None and lastmod_elem.text:
                    try:
                        # Handle various date formats
                        date_str = lastmod_elem.text.strip()
                        if 'T' in date_str:
                            lastmod = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                        else:
                            lastmod = datetime.strptime(date_str[:10], '%Y-%m-%d')
                    except Exception:
                        pass

                urls.append((url, lastmod))

            logger.debug(f"Found {len(urls)} URLs in sitemap")
            return urls[:limit]

        except Exception as e:
            logger.warning(f"Error parsing sitemap {sitemap_url}: {e}")
            return []

    def _crawl_listing_page(
        self,
        listing_url: str,
        allowed_domains: List[str],
        limit: int
    ) -> List[Tuple[str, Optional[datetime]]]:
        """Crawl an HTML listing page for links"""
        logger.debug(f"Crawling listing: {listing_url}")

        html = self.fetch_html(listing_url)
        if not html:
            return []

        try:
            soup = BeautifulSoup(html, 'html.parser')
            urls = []

            for anchor in soup.find_all('a', href=True):
                href = anchor['href']
                abs_url = urljoin(listing_url, href)

                # Check domain
                url_domain = urlparse(abs_url).netloc.lower()
                is_allowed = False
                for domain in allowed_domains:
                    if domain in url_domain or url_domain.endswith('.' + domain):
                        is_allowed = True
                        break

                if not is_allowed:
                    continue

                # Skip non-HTTP URLs
                if not abs_url.startswith(('http://', 'https://')):
                    continue

                urls.append((abs_url, None))

                if len(urls) >= limit:
                    break

            logger.debug(f"Found {len(urls)} links on listing page")
            return urls

        except Exception as e:
            logger.warning(f"Error crawling {listing_url}: {e}")
            return []

    def _normalize_url(self, url: str) -> str:
        """Normalize URL by removing tracking parameters and fragments"""
        STRIP_PARAMS = {
            'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
            'fbclid', 'gclid', 'ref', 'source', 'campaign', 'mc_cid', 'mc_eid'
        }

        from urllib.parse import urlparse, parse_qs, urlencode, urlunparse

        parsed = urlparse(url)

        # Filter query params
        query_params = parse_qs(parsed.query)
        filtered = {k: v for k, v in query_params.items() if k not in STRIP_PARAMS}
        new_query = urlencode(filtered, doseq=True)

        # Rebuild without fragment
        normalized = urlunparse((
            parsed.scheme,
            parsed.netloc.lower(),
            parsed.path.rstrip('/'),
            parsed.params,
            new_query,
            ''  # No fragment
        ))

        return normalized

    def has_recipe_schema(self, url: str) -> bool:
        """
        Check if URL contains Recipe schema.org JSON-LD.

        Args:
            url: URL to check

        Returns:
            True if recipe schema found
        """
        html = self.fetch_html(url)
        if not html:
            return False

        try:
            soup = BeautifulSoup(html, 'html.parser')

            # Check for JSON-LD
            for script in soup.find_all('script', type='application/ld+json'):
                try:
                    import json
                    data = json.loads(script.string)

                    # Handle @graph
                    if isinstance(data, dict) and '@graph' in data:
                        data = data['@graph']

                    # Handle list
                    if isinstance(data, list):
                        for item in data:
                            if item.get('@type') == 'Recipe':
                                return True
                    elif isinstance(data, dict):
                        if data.get('@type') == 'Recipe':
                            return True
                except Exception:
                    continue

            # Fallback: check for recipe markers in HTML
            text_lower = html.lower()
            has_ingredients = 'ingredient' in text_lower
            has_instructions = 'instruction' in text_lower or 'direction' in text_lower or 'method' in text_lower

            return has_ingredients and has_instructions

        except Exception as e:
            logger.debug(f"Error checking recipe schema for {url}: {e}")
            return False
