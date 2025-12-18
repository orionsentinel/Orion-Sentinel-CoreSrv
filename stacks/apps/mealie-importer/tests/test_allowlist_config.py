"""
Test allowlist.yaml configuration validation
Ensures allowlist.yaml is valid and patterns compile
"""

import re
import sys
import pytest
import yaml
from pathlib import Path

# Add app directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'app'))


def load_allowlist_config():
    """Load allowlist configuration"""
    config_path = Path(__file__).parent.parent / 'config' / 'allowlist.yaml'
    if not config_path.exists():
        pytest.skip(f"Configuration file not found: {config_path}")

    with open(config_path) as f:
        return yaml.safe_load(f)


def test_allowlist_valid_yaml():
    """Test that allowlist.yaml is valid YAML"""
    config = load_allowlist_config()
    assert config is not None, "Configuration is empty"
    assert isinstance(config, dict), "Configuration must be a dictionary"


def test_allowlist_has_required_keys():
    """Test that allowlist has required top-level keys"""
    config = load_allowlist_config()
    assert 'version' in config, "Configuration must have 'version' key"
    assert 'common' in config, "Configuration must have 'common' key"
    assert 'sites' in config, "Configuration must have 'sites' key"


def test_common_deny_regex_valid():
    """Test that common deny regex patterns compile"""
    config = load_allowlist_config()
    common = config.get('common', {})
    patterns = common.get('deny_regex', [])

    for pattern in patterns:
        try:
            re.compile(pattern, re.IGNORECASE)
        except re.error as e:
            pytest.fail(f"Invalid common deny regex '{pattern}': {e}")


def test_common_deny_query_regex_valid():
    """Test that common deny query regex patterns compile"""
    config = load_allowlist_config()
    common = config.get('common', {})
    patterns = common.get('deny_query_regex', [])

    for pattern in patterns:
        try:
            re.compile(pattern, re.IGNORECASE)
        except re.error as e:
            pytest.fail(f"Invalid common deny query regex '{pattern}': {e}")


def test_site_patterns_valid():
    """Test that all site patterns compile"""
    config = load_allowlist_config()
    sites = config.get('sites', {})

    for site_key, rules in sites.items():
        # Test allow patterns
        for pattern in rules.get('allow_regex', []):
            try:
                re.compile(pattern, re.IGNORECASE)
            except re.error as e:
                pytest.fail(f"Invalid allow regex for {site_key} '{pattern}': {e}")

        # Test deny patterns
        for pattern in rules.get('deny_regex', []):
            try:
                re.compile(pattern, re.IGNORECASE)
            except re.error as e:
                pytest.fail(f"Invalid deny regex for {site_key} '{pattern}': {e}")


def test_all_20_sites_have_rules():
    """Test that all 20 sites have allowlist rules"""
    config = load_allowlist_config()
    sites = config.get('sites', {})

    expected_keys = [
        'ottolenghi',
        'guardian_food',
        'meerasodha',
        'thehappyfoodie',
        'akis',
        'recipetineats',
        'greatbritishchefs',
        'bbcgoodfood',
        'themediterraneandish',
        'seriouseats',
        'bonappetit',
        'saveur',
        'feastingathome',
        'olivemagazine',
        'spainonafork',
        'patijinich',
        'rickbayless',
        'hotthaikitchen',
        'rasamalaysia',
        'thewoksoflife',
    ]

    for expected_key in expected_keys:
        assert expected_key in sites, f"Site '{expected_key}' missing from allowlist"
        site_rules = sites[expected_key]
        assert 'allow_regex' in site_rules, f"Site '{expected_key}' missing 'allow_regex'"
        assert len(site_rules['allow_regex']) > 0, f"Site '{expected_key}' has no allow patterns"


def test_ottolenghi_pattern_matches():
    """Test Ottolenghi allow pattern matches expected URLs"""
    config = load_allowlist_config()
    patterns = config['sites']['ottolenghi']['allow_regex']

    # Compile patterns
    compiled = [re.compile(p, re.IGNORECASE) for p in patterns]

    # Test URLs that should match
    should_match = [
        'https://ottolenghi.co.uk/recipes/lamb-shawarma',
        'https://www.ottolenghi.co.uk/recipes/hummus/',
    ]

    for url in should_match:
        matched = any(p.search(url) for p in compiled)
        assert matched, f"URL should match: {url}"


def test_bbcgoodfood_pattern_matches():
    """Test BBC Good Food allow pattern matches expected URLs"""
    config = load_allowlist_config()
    patterns = config['sites']['bbcgoodfood']['allow_regex']

    compiled = [re.compile(p, re.IGNORECASE) for p in patterns]

    should_match = [
        'https://www.bbcgoodfood.com/recipes/chocolate-cake',
        'https://bbcgoodfood.com/recipes/easy-pasta/',
    ]

    for url in should_match:
        matched = any(p.search(url) for p in compiled)
        assert matched, f"URL should match: {url}"


def test_common_deny_blocks_expected():
    """Test that common deny patterns block non-recipe URLs"""
    config = load_allowlist_config()
    deny_patterns = config['common']['deny_regex']

    compiled = [re.compile(p, re.IGNORECASE) for p in deny_patterns]

    should_deny = [
        'https://example.com/wp-admin/',
        'https://example.com/category/desserts/',
        'https://example.com/tag/healthy/',
        'https://example.com/about/',
        'https://example.com/privacy/',
        'https://example.com/shop/',
        'https://example.com/recipe.jpg',
    ]

    for url in should_deny:
        matched = any(p.search(url) for p in compiled)
        assert matched, f"URL should be denied: {url}"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
