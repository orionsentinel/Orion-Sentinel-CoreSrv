#!/usr/bin/env python3
"""
Mealie API Client

Handles all interactions with the Mealie API including:
- Recipe import via URL (POST /api/recipes/create/url)
- Bulk URL import (POST /api/recipes/create/url/bulk)
- HTML/JSON import fallback (POST /api/recipes/create/html-or-json)
- Tag/Category management (POST /api/organizers/tags, /api/organizers/categories)
"""

import time
import requests
from typing import Optional, Dict, List, Any
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from logger import get_logger

logger = get_logger(__name__)


class MealieAPI:
    """Client for Mealie API v3.7.0"""

    def __init__(self, base_url: str, api_token: str, timeout: int = 30):
        """
        Initialize Mealie API client.

        Args:
            base_url: Mealie instance base URL
            api_token: API authentication token (Bearer)
            timeout: Request timeout in seconds
        """
        self.base_url = base_url.rstrip('/')
        self.api_token = api_token
        self.timeout = timeout

        # Cache for tags and categories
        self._tags_cache: Dict[str, str] = {}  # name -> id
        self._categories_cache: Dict[str, str] = {}  # name -> id

        # Configure session with retries
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_token}',
            'Content-Type': 'application/json',
            'Accept-Language': 'en-US'  # Force English
        })

        # Configure retry strategy with exponential backoff
        retry_strategy = Retry(
            total=3,
            backoff_factor=2,
            status_forcelist=[429, 500, 502, 503, 504],
            allowed_methods=["GET", "POST", "PUT"]
        )
        adapter = HTTPAdapter(max_retries=retry_strategy)
        self.session.mount("http://", adapter)
        self.session.mount("https://", adapter)

    def test_connection(self) -> bool:
        """
        Test API connection.

        Returns:
            True if connection successful
        """
        try:
            response = self.session.get(
                f'{self.base_url}/api/app/about',
                timeout=self.timeout
            )
            response.raise_for_status()
            data = response.json()
            logger.info(f"✓ Connected to Mealie v{data.get('version', 'unknown')}")
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

    def import_recipe_url(
        self,
        url: str,
        tags: List[str] = None,
        categories: List[str] = None,
        include_tags: bool = True
    ) -> Dict[str, Any]:
        """
        Import a recipe from URL using Mealie's scraper.

        Uses: POST /api/recipes/create/url

        Args:
            url: Recipe URL to import
            tags: List of tag names to attach
            categories: List of category names to attach
            include_tags: Whether to include tags from scraped page

        Returns:
            Dict with 'success', 'name', 'slug', 'status_code' keys
        """
        try:
            payload = {
                'includeTags': include_tags,
                'url': url
            }

            response = self.session.post(
                f'{self.base_url}/api/recipes/create/url',
                json=payload,
                timeout=self.timeout
            )

            if response.status_code == 201:
                # Success - recipe created
                recipe = response.json()
                recipe_slug = recipe.get('slug', recipe.get('id', ''))

                # Attach tags and categories if provided
                if tags or categories:
                    self._update_recipe_organizers(recipe_slug, tags, categories)

                return {
                    'success': True,
                    'name': recipe.get('name', 'Unknown'),
                    'slug': recipe_slug,
                    'status_code': 201
                }

            elif response.status_code == 202:
                # Accepted - queued for processing
                return {
                    'success': False,
                    'status_code': 202,
                    'message': 'Queued for processing'
                }

            elif response.status_code == 409:
                # Conflict - recipe already exists
                logger.info(f"Recipe already exists: {url}")
                return {
                    'success': True,
                    'name': 'Existing Recipe',
                    'slug': '',
                    'status_code': 409,
                    'already_exists': True
                }

            else:
                error_msg = response.text[:200] if response.text else 'Unknown error'
                logger.warning(f"URL import failed ({response.status_code}): {error_msg}")
                return {
                    'success': False,
                    'status_code': response.status_code,
                    'error': error_msg
                }

        except Exception as e:
            logger.error(f"Exception during URL import: {e}")
            return {
                'success': False,
                'status_code': 0,
                'error': str(e)
            }

    def import_recipe_bulk(
        self,
        imports: List[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """
        Bulk import recipes from URLs.

        Uses: POST /api/recipes/create/url/bulk

        Args:
            imports: List of dicts with 'url', 'categories', 'tags' keys

        Returns:
            Dict with status and details
        """
        try:
            payload = {
                'imports': imports
            }

            response = self.session.post(
                f'{self.base_url}/api/recipes/create/url/bulk',
                json=payload,
                timeout=self.timeout * 2  # Longer timeout for bulk
            )

            if response.status_code in (200, 201, 202):
                return {
                    'success': True,
                    'status_code': response.status_code,
                    'data': response.json() if response.text else {}
                }
            else:
                return {
                    'success': False,
                    'status_code': response.status_code,
                    'error': response.text[:200]
                }

        except Exception as e:
            logger.error(f"Exception during bulk import: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def import_recipe_html(
        self,
        url: str,
        html_or_json: str,
        tags: List[str] = None,
        categories: List[str] = None,
        include_tags: bool = True
    ) -> Dict[str, Any]:
        """
        Import a recipe from HTML content or JSON-LD.

        Uses: POST /api/recipes/create/html-or-json

        Args:
            url: Original URL of the recipe
            html_or_json: Raw HTML or schema Recipe JSON string
            tags: List of tag names to attach
            categories: List of category names to attach
            include_tags: Whether to parse tags from content

        Returns:
            Dict with 'success', 'name', 'slug' keys
        """
        try:
            payload = {
                'includeTags': include_tags,
                'data': html_or_json,
                'url': url
            }

            response = self.session.post(
                f'{self.base_url}/api/recipes/create/html-or-json',
                json=payload,
                timeout=self.timeout * 2  # Longer timeout for HTML parsing
            )

            if response.status_code == 201:
                recipe = response.json()
                recipe_slug = recipe.get('slug', recipe.get('id', ''))

                # Attach tags and categories
                if tags or categories:
                    self._update_recipe_organizers(recipe_slug, tags, categories)

                return {
                    'success': True,
                    'name': recipe.get('name', 'Unknown'),
                    'slug': recipe_slug,
                    'status_code': 201
                }

            elif response.status_code == 409:
                return {
                    'success': True,
                    'name': 'Existing Recipe',
                    'slug': '',
                    'status_code': 409,
                    'already_exists': True
                }

            else:
                logger.warning(f"HTML import failed ({response.status_code}): {response.text[:200]}")
                return {
                    'success': False,
                    'status_code': response.status_code,
                    'error': response.text[:200]
                }

        except Exception as e:
            logger.error(f"Exception during HTML import: {e}")
            return {
                'success': False,
                'error': str(e)
            }

    def ensure_tag(self, name: str) -> Optional[str]:
        """
        Ensure a tag exists, create if missing.

        Args:
            name: Tag name

        Returns:
            Tag ID or None
        """
        # Check cache first
        if name in self._tags_cache:
            return self._tags_cache[name]

        # Try to find existing tag
        try:
            response = self.session.get(
                f'{self.base_url}/api/organizers/tags',
                params={'search': name},
                timeout=self.timeout
            )
            if response.status_code == 200:
                data = response.json()
                items = data.get('items', data) if isinstance(data, dict) else data
                for tag in items:
                    if tag.get('name', '').lower() == name.lower():
                        tag_id = tag.get('id', '')
                        self._tags_cache[name] = tag_id
                        return tag_id
        except Exception as e:
            logger.debug(f"Error searching for tag {name}: {e}")

        # Create new tag
        try:
            response = self.session.post(
                f'{self.base_url}/api/organizers/tags',
                json={'name': name},
                timeout=self.timeout
            )
            if response.status_code in (200, 201):
                tag = response.json()
                tag_id = tag.get('id', '')
                self._tags_cache[name] = tag_id
                logger.debug(f"Created tag: {name}")
                return tag_id
            elif response.status_code == 409:
                # Already exists (race condition), search again
                return self.ensure_tag(name)
        except Exception as e:
            logger.warning(f"Error creating tag {name}: {e}")

        return None

    def ensure_category(self, name: str) -> Optional[str]:
        """
        Ensure a category exists, create if missing.

        Args:
            name: Category name

        Returns:
            Category ID or None
        """
        # Check cache first
        if name in self._categories_cache:
            return self._categories_cache[name]

        # Try to find existing category
        try:
            response = self.session.get(
                f'{self.base_url}/api/organizers/categories',
                params={'search': name},
                timeout=self.timeout
            )
            if response.status_code == 200:
                data = response.json()
                items = data.get('items', data) if isinstance(data, dict) else data
                for cat in items:
                    if cat.get('name', '').lower() == name.lower():
                        cat_id = cat.get('id', '')
                        self._categories_cache[name] = cat_id
                        return cat_id
        except Exception as e:
            logger.debug(f"Error searching for category {name}: {e}")

        # Create new category
        try:
            response = self.session.post(
                f'{self.base_url}/api/organizers/categories',
                json={'name': name},
                timeout=self.timeout
            )
            if response.status_code in (200, 201):
                cat = response.json()
                cat_id = cat.get('id', '')
                self._categories_cache[name] = cat_id
                logger.debug(f"Created category: {name}")
                return cat_id
            elif response.status_code == 409:
                return self.ensure_category(name)
        except Exception as e:
            logger.warning(f"Error creating category {name}: {e}")

        return None

    def _update_recipe_organizers(
        self,
        recipe_slug: str,
        tags: List[str] = None,
        categories: List[str] = None
    ):
        """Update recipe with tags and categories"""
        if not recipe_slug:
            return

        # Get current recipe
        try:
            response = self.session.get(
                f'{self.base_url}/api/recipes/{recipe_slug}',
                timeout=self.timeout
            )
            if response.status_code != 200:
                return
            recipe = response.json()
        except Exception as e:
            logger.debug(f"Error fetching recipe {recipe_slug}: {e}")
            return

        # Build update payload
        update = {}

        if tags:
            existing_tags = recipe.get('tags', [])
            existing_names = {t.get('name', '').lower() for t in existing_tags}
            new_tags = []
            for tag_name in tags:
                if tag_name.lower() not in existing_names:
                    tag_id = self.ensure_tag(tag_name)
                    if tag_id:
                        new_tags.append({'id': tag_id, 'name': tag_name})
            if new_tags:
                update['tags'] = existing_tags + new_tags

        if categories:
            existing_cats = recipe.get('recipeCategory', [])
            existing_names = {c.get('name', '').lower() for c in existing_cats}
            new_cats = []
            for cat_name in categories:
                if cat_name.lower() not in existing_names:
                    cat_id = self.ensure_category(cat_name)
                    if cat_id:
                        new_cats.append({'id': cat_id, 'name': cat_name})
            if new_cats:
                update['recipeCategory'] = existing_cats + new_cats

        # Apply update
        if update:
            try:
                response = self.session.patch(
                    f'{self.base_url}/api/recipes/{recipe_slug}',
                    json=update,
                    timeout=self.timeout
                )
                if response.status_code == 200:
                    logger.debug(f"Updated organizers for {recipe_slug}")
            except Exception as e:
                logger.debug(f"Error updating recipe {recipe_slug}: {e}")

    def search_recipes(self, query: str = None, org_url: str = None) -> List[Dict]:
        """
        Search for recipes.

        Args:
            query: Search query string
            org_url: Original URL to search for

        Returns:
            List of matching recipes
        """
        try:
            params = {}
            if query:
                params['search'] = query

            response = self.session.get(
                f'{self.base_url}/api/recipes',
                params=params,
                timeout=self.timeout
            )

            if response.status_code == 200:
                data = response.json()
                items = data.get('items', data) if isinstance(data, dict) else data

                # Filter by orgURL if specified
                if org_url and items:
                    items = [r for r in items if r.get('orgURL') == org_url]

                return items

        except Exception as e:
            logger.error(f"Error searching recipes: {e}")

        return []

    def test_scrape_url(self, url: str, use_openai: bool = False) -> Dict[str, Any]:
        """
        Test if a URL can be scraped without importing.

        Args:
            url: URL to test
            use_openai: Whether to use OpenAI for scraping

        Returns:
            Dict with scrape test results
        """
        try:
            response = self.session.post(
                f'{self.base_url}/api/recipes/test-scrape-url',
                json={'url': url, 'useOpenAI': use_openai},
                timeout=self.timeout
            )

            return {
                'success': response.status_code == 200,
                'status_code': response.status_code,
                'data': response.json() if response.status_code == 200 else None
            }

        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }
