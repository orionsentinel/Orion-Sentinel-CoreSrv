#!/usr/bin/env python3
"""
Mealie Recipe Sync - Automated recipe importing from RSS feeds and URL lists
"""

import os
import sys
import time
import logging
import yaml
import json
import requests
import feedparser
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Dict, Set, Optional
from urllib.parse import urlparse

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


class MealieClient:
    """Client for interacting with Mealie API"""
    
    def __init__(self, base_url: str, api_token: str):
        self.base_url = base_url.rstrip('/')
        self.api_token = api_token
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_token}',
            'Content-Type': 'application/json'
        })
    
    def test_connection(self) -> bool:
        """Test API connection"""
        try:
            response = self.session.get(f'{self.base_url}/api/app/about')
            response.raise_for_status()
            logger.info(f"✓ Connected to Mealie API at {self.base_url}")
            return True
        except Exception as e:
            logger.error(f"✗ Failed to connect to Mealie: {e}")
            return False
    
    def import_recipe_from_url(self, url: str) -> Optional[Dict]:
        """Import a recipe from URL using Mealie's scraper"""
        try:
            logger.info(f"Importing recipe from: {url}")
            response = self.session.post(
                f'{self.base_url}/api/recipes/create-url',
                json={'url': url}
            )
            response.raise_for_status()
            recipe = response.json()
            logger.info(f"✓ Imported: {recipe.get('name', 'Unknown')}")
            return recipe
        except requests.exceptions.HTTPError as e:
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 400:
                    logger.warning(f"✗ Failed to scrape recipe from {url}: Invalid or unsupported format")
                elif e.response.status_code == 409:
                    logger.warning(f"⊙ Recipe already exists: {url}")
                else:
                    logger.error(f"✗ HTTP error importing {url}: {e}")
            else:
                logger.error(f"✗ Network error importing {url}: {e}")
            return None
        except Exception as e:
            logger.error(f"✗ Error importing {url}: {e}")
            return None
    
    def search_recipes(self, query: str) -> List[Dict]:
        """Search for existing recipes"""
        try:
            response = self.session.get(
                f'{self.base_url}/api/recipes',
                params={'search': query}
            )
            response.raise_for_status()
            return response.json().get('items', [])
        except Exception as e:
            logger.error(f"Error searching recipes: {e}")
            return []


class RecipeSource:
    """Base class for recipe sources"""
    
    def get_recipe_urls(self) -> List[str]:
        """Get list of recipe URLs from this source"""
        raise NotImplementedError


class RSSFeedSource(RecipeSource):
    """Recipe source from RSS/Atom feeds"""
    
    def __init__(self, feed_url: str, max_entries: int = 10):
        self.feed_url = feed_url
        self.max_entries = max_entries
    
    def get_recipe_urls(self) -> List[str]:
        """Parse RSS feed and extract recipe URLs"""
        try:
            logger.info(f"Fetching RSS feed: {self.feed_url}")
            feed = feedparser.parse(self.feed_url)
            
            if feed.bozo:
                logger.warning(f"RSS feed may be malformed: {self.feed_url}")
            
            urls = []
            for entry in feed.entries[:self.max_entries]:
                url = entry.get('link', '')
                if url:
                    urls.append(url)
            
            logger.info(f"Found {len(urls)} entries in RSS feed")
            return urls
        except Exception as e:
            logger.error(f"Error parsing RSS feed {self.feed_url}: {e}")
            return []


class URLListSource(RecipeSource):
    """Recipe source from plain text list of URLs"""
    
    def __init__(self, urls: List[str]):
        self.urls = urls
    
    def get_recipe_urls(self) -> List[str]:
        """Return the list of URLs"""
        return self.urls


class SitemapSource(RecipeSource):
    """Recipe source from XML sitemap"""
    
    def __init__(self, sitemap_url: str, allowlist: Optional[List[str]] = None, max_pages: int = 50):
        self.sitemap_url = sitemap_url
        self.allowlist = allowlist or []
        self.max_pages = max_pages
    
    def get_recipe_urls(self) -> List[str]:
        """Parse sitemap and extract recipe URLs"""
        try:
            logger.info(f"Fetching sitemap: {self.sitemap_url}")
            response = requests.get(self.sitemap_url, timeout=30)
            response.raise_for_status()
            
            # Simple XML parsing for sitemap
            urls = []
            for line in response.text.split('\n'):
                if '<loc>' in line:
                    url = line.split('<loc>')[1].split('</loc>')[0].strip()
                    
                    # Check allowlist if specified
                    if self.allowlist:
                        if any(allowed in url for allowed in self.allowlist):
                            urls.append(url)
                    else:
                        urls.append(url)
                    
                    if len(urls) >= self.max_pages:
                        break
            
            logger.info(f"Found {len(urls)} URLs in sitemap")
            return urls
        except Exception as e:
            logger.error(f"Error parsing sitemap {self.sitemap_url}: {e}")
            return []


class RecipeSyncManager:
    """Manages recipe synchronization process"""
    
    def __init__(self, config_dir: Path, state_dir: Path):
        self.config_dir = config_dir
        self.state_dir = state_dir
        self.state_file = state_dir / 'sync_state.json'
        self.imported_urls_file = state_dir / 'imported_urls.txt'
        
        # Load configuration
        self.config = self._load_config()
        self.settings = self._load_settings()
        
        # Initialize Mealie client
        mealie_url = os.getenv('MEALIE_BASE_URL', self.settings.get('mealie_url', 'http://mealie:9000'))
        mealie_token = os.getenv('MEALIE_API_TOKEN', '')
        
        if not mealie_token:
            logger.error("MEALIE_API_TOKEN environment variable is required!")
            sys.exit(1)
        
        self.mealie = MealieClient(mealie_url, mealie_token)
        
        # Load state
        self.state = self._load_state()
        self.imported_urls = self._load_imported_urls()
    
    def _load_config(self) -> Dict:
        """Load sources configuration"""
        sources_file = self.config_dir / 'sources.yaml'
        if not sources_file.exists():
            logger.error(f"Configuration file not found: {sources_file}")
            return {'sources': []}
        
        with open(sources_file) as f:
            return yaml.safe_load(f) or {'sources': []}
    
    def _load_settings(self) -> Dict:
        """Load settings configuration"""
        settings_file = self.config_dir / 'settings.yaml'
        if not settings_file.exists():
            logger.warning(f"Settings file not found: {settings_file}, using defaults")
            return {}
        
        with open(settings_file) as f:
            return yaml.safe_load(f) or {}
    
    def _load_state(self) -> Dict:
        """Load sync state"""
        if not self.state_file.exists():
            return {
                'last_run': None,
                'total_imported': 0,
                'last_import_count': 0
            }
        
        with open(self.state_file) as f:
            return json.load(f)
    
    def _save_state(self):
        """Save sync state"""
        self.state_dir.mkdir(parents=True, exist_ok=True)
        with open(self.state_file, 'w') as f:
            json.dump(self.state, f, indent=2)
    
    def _load_imported_urls(self) -> Set[str]:
        """Load set of already imported URLs"""
        if not self.imported_urls_file.exists():
            return set()
        
        with open(self.imported_urls_file) as f:
            return set(line.strip() for line in f if line.strip())
    
    def _save_imported_url(self, url: str):
        """Add URL to imported list"""
        self.state_dir.mkdir(parents=True, exist_ok=True)
        with open(self.imported_urls_file, 'a') as f:
            f.write(f"{url}\n")
        self.imported_urls.add(url)
    
    def _create_source(self, source_config: Dict) -> Optional[RecipeSource]:
        """Create a RecipeSource from configuration"""
        source_type = source_config.get('type')
        
        if source_type == 'rss':
            return RSSFeedSource(
                source_config['url'],
                max_entries=source_config.get('max_entries', 10)
            )
        elif source_type == 'url_list':
            return URLListSource(source_config.get('urls', []))
        elif source_type == 'sitemap':
            return SitemapSource(
                source_config['url'],
                allowlist=source_config.get('allowlist', []),
                max_pages=source_config.get('max_pages', 50)
            )
        else:
            logger.warning(f"Unknown source type: {source_type}")
            return None
    
    def sync(self):
        """Run recipe sync"""
        logger.info("=" * 60)
        logger.info("Starting Mealie Recipe Sync")
        logger.info("=" * 60)
        
        # Test Mealie connection
        if not self.mealie.test_connection():
            logger.error("Cannot proceed without Mealie connection")
            return
        
        # Get settings
        max_recipes = int(os.getenv('MAX_NEW_RECIPES_PER_RUN', 
                                    self.settings.get('max_new_recipes_per_run', 20)))
        
        # Collect URLs from all sources
        all_urls = []
        for source_config in self.config.get('sources', []):
            if not source_config.get('enabled', True):
                continue
            
            source = self._create_source(source_config)
            if source:
                urls = source.get_recipe_urls()
                all_urls.extend(urls)
        
        logger.info(f"Total URLs collected from all sources: {len(all_urls)}")
        
        # Filter out already imported URLs
        new_urls = [url for url in all_urls if url not in self.imported_urls]
        logger.info(f"New URLs to import: {len(new_urls)}")
        
        if not new_urls:
            logger.info("No new recipes to import")
            self.state['last_run'] = datetime.now().isoformat()
            self.state['last_import_count'] = 0
            self._save_state()
            return
        
        # Limit number of imports per run
        urls_to_import = new_urls[:max_recipes]
        logger.info(f"Importing {len(urls_to_import)} recipes (limited to {max_recipes} per run)")
        
        # Import recipes
        imported_count = 0
        for url in urls_to_import:
            recipe = self.mealie.import_recipe_from_url(url)
            if recipe:
                self._save_imported_url(url)
                imported_count += 1
            
            # Small delay to avoid overwhelming the API
            time.sleep(2)
        
        # Update state
        self.state['last_run'] = datetime.now().isoformat()
        self.state['last_import_count'] = imported_count
        self.state['total_imported'] = self.state.get('total_imported', 0) + imported_count
        self._save_state()
        
        logger.info("=" * 60)
        logger.info(f"Sync complete! Imported {imported_count} new recipes")
        logger.info(f"Total recipes imported to date: {self.state['total_imported']}")
        logger.info("=" * 60)


def main():
    """Main entry point"""
    config_dir = Path('/config')
    state_dir = Path('/data')
    
    # Get sync interval from environment
    interval_minutes = int(os.getenv('SYNC_INTERVAL_MINUTES', 360))  # Default: 6 hours
    
    logger.info(f"Mealie Recipe Sync starting with {interval_minutes} minute interval")
    
    # Create sync manager
    manager = RecipeSyncManager(config_dir, state_dir)
    
    # Run sync loop
    while True:
        try:
            manager.sync()
        except Exception as e:
            logger.error(f"Error during sync: {e}", exc_info=True)
        
        # Wait for next sync
        logger.info(f"Next sync in {interval_minutes} minutes")
        time.sleep(interval_minutes * 60)


if __name__ == '__main__':
    main()
