#!/usr/bin/env python3
"""
Recipe source implementations
Supports RSS feeds, crawling, and hybrid approaches
"""

import feedparser
from typing import List, Optional, Dict
from abc import ABC, abstractmethod

from logger import get_logger
from crawler import RecipeCrawler, URLNormalizer

logger = get_logger(__name__)


class RecipeSource(ABC):
    """Base class for recipe sources"""
    
    def __init__(self, name: str, config: Dict):
        """
        Initialize recipe source
        
        Args:
            name: Source name
            config: Source configuration dictionary
        """
        self.name = name
        self.config = config
        self.allow_domains = config.get('allow_domains', [])
    
    @abstractmethod
    def get_recipe_urls(self, crawler: RecipeCrawler) -> List[str]:
        """
        Discover recipe URLs from this source
        
        Args:
            crawler: Crawler instance for fetching pages
        
        Returns:
            List of recipe URLs
        """
        pass


class RSSFeedSource(RecipeSource):
    """Standard RSS/Atom feed source"""
    
    def get_recipe_urls(self, crawler: RecipeCrawler) -> List[str]:
        """Parse RSS feed and extract recipe URLs"""
        rss_url = self.config.get('rss_url')
        max_entries = self.config.get('max_entries', 20)
        
        if not rss_url:
            logger.error(f"{self.name}: Missing rss_url")
            return []
        
        try:
            logger.info(f"{self.name}: Fetching RSS feed from {rss_url}")
            feed = feedparser.parse(rss_url)
            
            if feed.bozo:
                logger.warning(f"{self.name}: RSS feed may be malformed")
            
            urls = []
            for entry in feed.entries[:max_entries]:
                url = entry.get('link', '')
                if url:
                    # Check domain restrictions
                    if self.allow_domains and not URLNormalizer.matches_domain(url, self.allow_domains):
                        continue
                    normalized = URLNormalizer.normalize(url)
                    urls.append(normalized)
            
            logger.info(f"{self.name}: Found {len(urls)} URLs in RSS feed")
            return urls
            
        except Exception as e:
            logger.error(f"{self.name}: Error parsing RSS feed: {e}")
            return []


class RSSSuffixSource(RecipeSource):
    """RSS feed source where RSS URL = index_url + rss_suffix"""
    
    def get_recipe_urls(self, crawler: RecipeCrawler) -> List[str]:
        """Build RSS URL from index + suffix, then parse"""
        index_url = self.config.get('index_url')
        rss_suffix = self.config.get('rss_suffix', '/rss')
        max_entries = self.config.get('max_entries', 20)
        
        if not index_url:
            logger.error(f"{self.name}: Missing index_url")
            return []
        
        # Construct RSS URL
        rss_url = index_url.rstrip('/') + rss_suffix
        
        try:
            logger.info(f"{self.name}: Fetching RSS from {rss_url}")
            feed = feedparser.parse(rss_url)
            
            if feed.bozo:
                logger.warning(f"{self.name}: RSS feed may be malformed")
            
            urls = []
            for entry in feed.entries[:max_entries]:
                url = entry.get('link', '')
                if url:
                    # Check domain restrictions
                    if self.allow_domains and not URLNormalizer.matches_domain(url, self.allow_domains):
                        continue
                    normalized = URLNormalizer.normalize(url)
                    urls.append(normalized)
            
            logger.info(f"{self.name}: Found {len(urls)} URLs via RSS suffix")
            return urls
            
        except Exception as e:
            logger.error(f"{self.name}: Error parsing RSS feed: {e}")
            return []


class CrawlIndexSource(RecipeSource):
    """Crawl an index page to discover recipe URLs"""
    
    def get_recipe_urls(self, crawler: RecipeCrawler) -> List[str]:
        """Crawl index page and extract links"""
        index_url = self.config.get('index_url')
        max_pages = self.config.get('max_pages', 100)
        
        if not index_url:
            logger.error(f"{self.name}: Missing index_url")
            return []
        
        if not self.allow_domains:
            logger.error(f"{self.name}: allow_domains required for crawling")
            return []
        
        try:
            logger.info(f"{self.name}: Crawling index page {index_url}")
            urls = crawler.crawl_index_page(index_url, self.allow_domains, max_pages)
            logger.info(f"{self.name}: Found {len(urls)} URLs via crawling")
            return urls
            
        except Exception as e:
            logger.error(f"{self.name}: Error crawling index: {e}")
            return []


class RSSOrCrawlSource(RecipeSource):
    """Try RSS feeds first, fall back to crawling if none work"""
    
    def get_recipe_urls(self, crawler: RecipeCrawler) -> List[str]:
        """Try RSS candidates, fallback to crawling"""
        rss_candidates = self.config.get('rss_url_candidates', [])
        crawl_fallback = self.config.get('crawl_fallback_url')
        max_entries = self.config.get('max_entries', 20)
        max_pages = self.config.get('max_pages', 100)
        
        # Try RSS feeds first
        for rss_url in rss_candidates:
            try:
                logger.info(f"{self.name}: Trying RSS feed {rss_url}")
                feed = feedparser.parse(rss_url)
                
                # Check if feed is valid and has entries
                if not feed.bozo and feed.entries:
                    urls = []
                    for entry in feed.entries[:max_entries]:
                        url = entry.get('link', '')
                        if url:
                            # Check domain restrictions
                            if self.allow_domains and not URLNormalizer.matches_domain(url, self.allow_domains):
                                continue
                            normalized = URLNormalizer.normalize(url)
                            urls.append(normalized)
                    
                    if urls:
                        logger.info(f"{self.name}: Found {len(urls)} URLs via RSS")
                        return urls
                        
            except Exception as e:
                logger.warning(f"{self.name}: RSS feed {rss_url} failed: {e}")
                continue
        
        # Fallback to crawling if RSS failed
        if crawl_fallback:
            if not self.allow_domains:
                logger.error(f"{self.name}: allow_domains required for crawl fallback")
                return []
            
            try:
                logger.info(f"{self.name}: Falling back to crawling {crawl_fallback}")
                urls = crawler.crawl_index_page(crawl_fallback, self.allow_domains, max_pages)
                logger.info(f"{self.name}: Found {len(urls)} URLs via crawl fallback")
                return urls
                
            except Exception as e:
                logger.error(f"{self.name}: Crawl fallback failed: {e}")
                return []
        
        logger.warning(f"{self.name}: All methods failed")
        return []


class URLListSource(RecipeSource):
    """Static list of URLs"""
    
    def get_recipe_urls(self, crawler: RecipeCrawler) -> List[str]:
        """Return configured URL list"""
        urls = self.config.get('urls', [])
        
        # Normalize URLs
        normalized = []
        for url in urls:
            # Check domain restrictions if specified
            if self.allow_domains and not URLNormalizer.matches_domain(url, self.allow_domains):
                logger.warning(f"{self.name}: Skipping URL not in allowed domains: {url}")
                continue
            normalized.append(URLNormalizer.normalize(url))
        
        logger.info(f"{self.name}: Loaded {len(normalized)} URLs from list")
        return normalized


def create_source(name: str, config: Dict) -> Optional[RecipeSource]:
    """
    Factory function to create source from config
    
    Args:
        name: Source name
        config: Source configuration
    
    Returns:
        RecipeSource instance or None if type unknown
    """
    source_type = config.get('type')
    
    if source_type == 'rss':
        return RSSFeedSource(name, config)
    elif source_type == 'rss_suffix':
        return RSSSuffixSource(name, config)
    elif source_type == 'crawl_index':
        return CrawlIndexSource(name, config)
    elif source_type == 'rss_or_crawl':
        return RSSOrCrawlSource(name, config)
    elif source_type == 'url_list':
        return URLListSource(name, config)
    else:
        logger.warning(f"{name}: Unknown source type: {source_type}")
        return None
