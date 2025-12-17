"""
Test configuration validation for recipe sources
Ensures recipe_sources.yaml is valid and all sources have required fields
"""

import os
import sys
import pytest
import yaml
from pathlib import Path

# Add app directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'app'))


def load_config():
    """Load recipe sources configuration"""
    config_path = Path(__file__).parent.parent / 'config' / 'recipe_sources.yaml'
    if not config_path.exists():
        pytest.skip(f"Configuration file not found: {config_path}")
    
    with open(config_path) as f:
        return yaml.safe_load(f)


def test_config_file_valid_yaml():
    """Test that recipe_sources.yaml is valid YAML"""
    config = load_config()
    assert config is not None, "Configuration is empty"
    assert isinstance(config, dict), "Configuration must be a dictionary"


def test_config_has_sources_key():
    """Test that configuration has 'sources' key"""
    config = load_config()
    assert 'sources' in config, "Configuration must have 'sources' key"
    assert isinstance(config['sources'], list), "'sources' must be a list"


def test_sources_not_empty():
    """Test that sources list is not empty"""
    config = load_config()
    assert len(config['sources']) > 0, "Sources list must not be empty"


def test_source_names_unique():
    """Test that all source names are unique"""
    config = load_config()
    names = [source.get('name') for source in config['sources']]
    assert len(names) == len(set(names)), "Source names must be unique"


def test_sources_have_required_fields():
    """Test that each source has required fields"""
    config = load_config()
    
    for i, source in enumerate(config['sources']):
        # All sources must have name and type
        assert 'name' in source, f"Source {i} missing 'name' field"
        assert 'type' in source, f"Source {i} ({source.get('name', 'unknown')}) missing 'type' field"
        assert isinstance(source['name'], str), f"Source {i} 'name' must be a string"
        assert isinstance(source['type'], str), f"Source {i} 'type' must be a string"


def test_source_types_valid():
    """Test that all source types are valid"""
    config = load_config()
    valid_types = {'rss', 'rss_suffix', 'crawl_index', 'rss_or_crawl', 'url_list', 'sitemap'}
    
    for source in config['sources']:
        source_type = source.get('type')
        assert source_type in valid_types, \
            f"Source '{source.get('name')}' has invalid type: {source_type}. " \
            f"Must be one of {valid_types}"


def test_rss_sources_have_required_fields():
    """Test that RSS sources have required fields"""
    config = load_config()
    
    for source in config['sources']:
        if source.get('type') == 'rss':
            assert 'rss_url' in source, \
                f"RSS source '{source.get('name')}' must have 'rss_url' field"


def test_rss_suffix_sources_have_required_fields():
    """Test that rss_suffix sources have required fields"""
    config = load_config()
    
    for source in config['sources']:
        if source.get('type') == 'rss_suffix':
            assert 'index_url' in source, \
                f"rss_suffix source '{source.get('name')}' must have 'index_url' field"
            assert 'rss_suffix' in source, \
                f"rss_suffix source '{source.get('name')}' must have 'rss_suffix' field"


def test_crawl_index_sources_have_required_fields():
    """Test that crawl_index sources have required fields"""
    config = load_config()
    
    for source in config['sources']:
        if source.get('type') == 'crawl_index':
            assert 'index_url' in source, \
                f"crawl_index source '{source.get('name')}' must have 'index_url' field"
            assert 'allow_domains' in source, \
                f"crawl_index source '{source.get('name')}' must have 'allow_domains' field"
            assert isinstance(source['allow_domains'], list), \
                f"crawl_index source '{source.get('name')}' 'allow_domains' must be a list"


def test_rss_or_crawl_sources_have_required_fields():
    """Test that rss_or_crawl sources have required fields"""
    config = load_config()
    
    for source in config['sources']:
        if source.get('type') == 'rss_or_crawl':
            # Must have either rss_url_candidates or crawl_fallback_url (or both)
            has_rss = 'rss_url_candidates' in source
            has_crawl = 'crawl_fallback_url' in source
            
            assert has_rss or has_crawl, \
                f"rss_or_crawl source '{source.get('name')}' must have " \
                f"'rss_url_candidates' or 'crawl_fallback_url' (or both)"
            
            if has_rss:
                assert isinstance(source['rss_url_candidates'], list), \
                    f"rss_or_crawl source '{source.get('name')}' " \
                    f"'rss_url_candidates' must be a list"


def test_url_list_sources_have_required_fields():
    """Test that url_list sources have required fields"""
    config = load_config()
    
    for source in config['sources']:
        if source.get('type') == 'url_list':
            assert 'urls' in source, \
                f"url_list source '{source.get('name')}' must have 'urls' field"
            assert isinstance(source['urls'], list), \
                f"url_list source '{source.get('name')}' 'urls' must be a list"


def test_enabled_field_is_boolean():
    """Test that 'enabled' field (if present) is boolean"""
    config = load_config()
    
    for source in config['sources']:
        if 'enabled' in source:
            assert isinstance(source['enabled'], bool), \
                f"Source '{source.get('name')}' 'enabled' field must be boolean (true/false)"


def test_at_least_one_source_enabled():
    """Test that at least one source is enabled"""
    config = load_config()
    
    enabled_sources = [
        source for source in config['sources']
        if source.get('enabled', True)  # Default to True if not specified
    ]
    
    assert len(enabled_sources) > 0, \
        "At least one source must be enabled (enabled: true or no 'enabled' field)"


def test_specific_10_sources_present():
    """Test that the 10 specific sources from requirements are present"""
    config = load_config()
    
    expected_sources = [
        "Ottolenghi — Official recipes",
        "The Guardian — Ottolenghi recipes (RSS)",
        "The Happy Foodie — Recipes archive",
        "Meera Sodha — The Guardian The New Vegan (RSS)",
        "Akis Petretzikis — Recipe categories",
        "RecipeTin Eats — Main feed then fallback crawl",
        "Great British Chefs — Middle Eastern collection",
        "BBC Good Food — Middle Eastern collection",
        "The Mediterranean Dish — Recipes index",
        "Serious Eats — Middle Eastern recipes",
    ]
    
    actual_names = [source.get('name') for source in config['sources']]
    
    for expected_name in expected_sources:
        assert expected_name in actual_names, \
            f"Required source '{expected_name}' not found in configuration"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
