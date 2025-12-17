#!/usr/bin/env python3
"""
Mealie API client for recipe import operations
Handles retries, rate limiting, and error handling
"""

import time
import requests
from typing import Optional, Dict
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from logger import get_logger

logger = get_logger(__name__)


class MealieClient:
    """Client for interacting with Mealie API"""
    
    def __init__(self, base_url: str, api_token: str, timeout: int = 30, dry_run: bool = False):
        """
        Initialize Mealie client
        
        Args:
            base_url: Mealie instance base URL
            api_token: API authentication token
            timeout: Request timeout in seconds
            dry_run: If True, don't actually import recipes
        """
        self.base_url = base_url.rstrip('/')
        self.api_token = api_token
        self.timeout = timeout
        self.dry_run = dry_run
        
        # Configure session with retries
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_token}',
            'Content-Type': 'application/json'
        })
        
        # Configure retry strategy
        retry_strategy = Retry(
            total=3,
            backoff_factor=2,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)
    
    def test_connection(self) -> bool:
        """
        Test API connection
        
        Returns:
            True if connection successful, False otherwise
        """
        try:
            response = self.session.get(
                f'{self.base_url}/api/app/about',
                timeout=self.timeout
            )
            response.raise_for_status()
            logger.info(f"✓ Connected to Mealie API at {self.base_url}")
            return True
        except requests.exceptions.Timeout:
            logger.error(f"✗ Connection to Mealie timed out after {self.timeout}s")
            return False
        except requests.exceptions.ConnectionError as e:
            logger.error(f"✗ Failed to connect to Mealie: {e}")
            return False
        except Exception as e:
            logger.error(f"✗ Error connecting to Mealie: {e}")
            return False
    
    def import_recipe_from_url(self, url: str) -> Optional[Dict]:
        """
        Import a recipe from URL using Mealie's scraper
        
        Args:
            url: Recipe URL to import
        
        Returns:
            Recipe data if successful, None otherwise
        """
        if self.dry_run:
            logger.info(f"[DRY RUN] Would import recipe from: {url}")
            return {'name': 'Dry Run Recipe', 'url': url, 'dry_run': True}
        
        try:
            logger.info(f"Importing recipe from: {url}")
            response = self.session.post(
                f'{self.base_url}/api/recipes/create-url',
                json={'url': url},
                timeout=self.timeout
            )
            response.raise_for_status()
            recipe = response.json()
            recipe_name = recipe.get('name', 'Unknown')
            logger.info(f"✓ Imported: {recipe_name}")
            return recipe
            
        except requests.exceptions.Timeout:
            logger.warning(f"✗ Timeout importing {url} after {self.timeout}s")
            return None
            
        except requests.exceptions.HTTPError as e:
            if hasattr(e, 'response') and e.response is not None:
                status = e.response.status_code
                if status == 400:
                    logger.warning(f"✗ Failed to scrape recipe from {url}: Invalid or unsupported format")
                elif status == 409:
                    logger.info(f"⊙ Recipe already exists in Mealie: {url}")
                    # Return a minimal dict to indicate it was "imported" (already exists)
                    return {'name': 'Existing Recipe', 'url': url, 'already_exists': True}
                elif status == 429:
                    logger.warning(f"✗ Rate limited by Mealie for {url}")
                else:
                    logger.error(f"✗ HTTP {status} error importing {url}: {e}")
            else:
                logger.error(f"✗ Network error importing {url}: {e}")
            return None
            
        except Exception as e:
            logger.error(f"✗ Unexpected error importing {url}: {e}")
            return None
    
    def search_recipes(self, query: str) -> list:
        """
        Search for existing recipes
        
        Args:
            query: Search query string
        
        Returns:
            List of matching recipes
        """
        if self.dry_run:
            logger.info(f"[DRY RUN] Would search for: {query}")
            return []
        
        try:
            response = self.session.get(
                f'{self.base_url}/api/recipes',
                params={'search': query},
                timeout=self.timeout
            )
            response.raise_for_status()
            return response.json().get('items', [])
        except Exception as e:
            logger.error(f"Error searching recipes for '{query}': {e}")
            return []
