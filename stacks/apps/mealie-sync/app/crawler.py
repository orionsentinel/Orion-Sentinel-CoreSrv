#!/usr/bin/env python3
"""
Web crawler for recipe discovery
Includes rate limiting, domain filtering, and URL normalization
"""

import time
import requests
from urllib.parse import urlparse, urljoin, urlunparse, parse_qs, urlencode
from typing import List, Set, Optional
from bs4 import BeautifulSoup
from collections import defaultdict

from logger import get_logger

logger = get_logger(__name__)


class RateLimiter:
    """Rate limiter per domain"""
    
    def __init__(self, seconds_per_domain: float = 1.0):
        """
        Initialize rate limiter
        
        Args:
            seconds_per_domain: Minimum seconds between requests to same domain
        """
        self.seconds_per_domain = seconds_per_domain
        self.last_request_time = defaultdict(float)
    
    def wait_if_needed(self, domain: str):
        """Wait if necessary before making request to domain"""
        now = time.time()
        last_time = self.last_request_time[domain]
        time_since_last = now - last_time
        
        if time_since_last < self.seconds_per_domain:
            wait_time = self.seconds_per_domain - time_since_last
            logger.debug(f"Rate limiting: waiting {wait_time:.2f}s for {domain}")
            time.sleep(wait_time)
        
        self.last_request_time[domain] = time.time()


class URLNormalizer:
    """Normalize and filter URLs"""
    
    # URL parameters to strip (tracking, analytics, etc.)
    STRIP_PARAMS = {
        'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
        'fbclid', 'gclid', 'ref', 'source', 'campaign'
    }
    
    @staticmethod
    def normalize(url: str) -> str:
        """
        Normalize URL by removing fragments and tracking parameters
        
        Args:
            url: Raw URL
        
        Returns:
            Normalized URL
        """
        parsed = urlparse(url)
        
        # Parse query string and filter out tracking params
        query_params = parse_qs(parsed.query)
        filtered_params = {
            k: v for k, v in query_params.items() 
            if k not in URLNormalizer.STRIP_PARAMS
        }
        
        # Rebuild query string
        new_query = urlencode(filtered_params, doseq=True)
        
        # Rebuild URL without fragment, using netloc as-is
        normalized = urlunparse((
            parsed.scheme,
            parsed.netloc,  # Use netloc directly to preserve domain correctly
            parsed.path,
            parsed.params,
            new_query,
            ''  # Remove fragment
        ))
        
        return normalized
    
    @staticmethod
    def extract_domain(url: str) -> str:
        """Extract domain from URL"""
        parsed = urlparse(url)
        return parsed.netloc.lower()
    
    @staticmethod
    def matches_domain(url: str, allowed_domains: List[str]) -> bool:
        """
        Check if URL matches allowed domains
        
        Args:
            url: URL to check
            allowed_domains: List of allowed domain patterns
        
        Returns:
            True if URL matches any allowed domain
        """
        domain = URLNormalizer.extract_domain(url)
        
        for allowed in allowed_domains:
            allowed = allowed.lower()
            # Support subdomain wildcards
            if allowed.startswith('.'):
                # .example.com matches www.example.com, blog.example.com, etc.
                if domain.endswith(allowed) or domain == allowed[1:]:
                    return True
            else:
                # Exact match or subdomain
                if domain == allowed or domain.endswith('.' + allowed):
                    return True
        
        return False


class RecipeCrawler:
    """Polite web crawler for recipe discovery"""
    
    def __init__(self, rate_limiter: RateLimiter, user_agent: str, timeout: int = 10):
        """
        Initialize crawler
        
        Args:
            rate_limiter: Rate limiter instance
            user_agent: User agent string for requests
            timeout: Request timeout in seconds
        """
        self.rate_limiter = rate_limiter
        self.timeout = timeout
        
        self.session = requests.Session()
        self.session.headers.update({
            'User-Agent': user_agent
        })
    
    def fetch_page(self, url: str, allowed_domains: Optional[List[str]] = None) -> Optional[str]:
        """
        Fetch a page with rate limiting and error handling
        
        Args:
            url: URL to fetch
            allowed_domains: Optional list of allowed domains
        
        Returns:
            Page HTML content or None if failed
        """
        # Check domain if restrictions apply
        if allowed_domains and not URLNormalizer.matches_domain(url, allowed_domains):
            logger.warning(f"URL not in allowed domains: {url}")
            return None
        
        domain = URLNormalizer.extract_domain(url)
        
        try:
            # Rate limit
            self.rate_limiter.wait_if_needed(domain)
            
            # Fetch page
            logger.debug(f"Fetching: {url}")
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            
            return response.text
            
        except requests.exceptions.Timeout:
            logger.warning(f"Timeout fetching {url}")
            return None
        except requests.exceptions.RequestException as e:
            logger.warning(f"Error fetching {url}: {e}")
            return None
    
    def extract_links(self, html: str, base_url: str, 
                     allowed_domains: Optional[List[str]] = None,
                     max_links: Optional[int] = None) -> List[str]:
        """
        Extract and normalize links from HTML
        
        Args:
            html: HTML content
            base_url: Base URL for resolving relative links
            allowed_domains: Optional list of allowed domains
            max_links: Maximum number of links to return
        
        Returns:
            List of normalized URLs
        """
        try:
            soup = BeautifulSoup(html, 'html.parser')
            links: Set[str] = set()
            
            for anchor in soup.find_all('a', href=True):
                href = anchor['href']
                
                # Resolve relative URLs
                absolute_url = urljoin(base_url, href)
                
                # Skip non-HTTP(S) URLs
                if not absolute_url.startswith(('http://', 'https://')):
                    continue
                
                # Check domain restrictions
                if allowed_domains and not URLNormalizer.matches_domain(absolute_url, allowed_domains):
                    continue
                
                # Normalize URL
                normalized = URLNormalizer.normalize(absolute_url)
                links.add(normalized)
                
                # Check limit
                if max_links and len(links) >= max_links:
                    break
            
            return list(links)[:max_links] if max_links else list(links)
            
        except Exception as e:
            logger.error(f"Error extracting links from {base_url}: {e}")
            return []
    
    def crawl_index_page(self, index_url: str, allowed_domains: List[str], 
                        max_pages: int = 100) -> List[str]:
        """
        Crawl an index page to discover recipe URLs
        
        Args:
            index_url: Index page URL
            allowed_domains: List of allowed domains
            max_pages: Maximum number of links to extract
        
        Returns:
            List of discovered recipe URLs
        """
        logger.info(f"Crawling index page: {index_url}")
        
        html = self.fetch_page(index_url, allowed_domains)
        if not html:
            return []
        
        links = self.extract_links(html, index_url, allowed_domains, max_pages)
        logger.info(f"Found {len(links)} links on index page")
        
        return links
