"""
Test sources.yaml configuration validation
Ensures sources.yaml is valid and all 20 sources are present
"""

import sys
import pytest
import yaml
from pathlib import Path

# Add app directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'app'))


def load_sources_config():
    """Load sources configuration"""
    config_path = Path(__file__).parent.parent / 'config' / 'sources.yaml'
    if not config_path.exists():
        pytest.skip(f"Configuration file not found: {config_path}")

    with open(config_path) as f:
        return yaml.safe_load(f)


def test_sources_config_valid_yaml():
    """Test that sources.yaml is valid YAML"""
    config = load_sources_config()
    assert config is not None, "Configuration is empty"
    assert isinstance(config, dict), "Configuration must be a dictionary"


def test_sources_config_has_required_keys():
    """Test that configuration has required top-level keys"""
    config = load_sources_config()
    assert 'version' in config, "Configuration must have 'version' key"
    assert 'defaults' in config, "Configuration must have 'defaults' key"
    assert 'sites' in config, "Configuration must have 'sites' key"


def test_sources_config_has_20_sites():
    """Test that exactly 20 sites are configured"""
    config = load_sources_config()
    sites = config.get('sites', [])
    assert len(sites) == 20, f"Expected 20 sites, got {len(sites)}"


def test_sites_have_required_fields():
    """Test that each site has required fields"""
    config = load_sources_config()
    sites = config.get('sites', [])

    for i, site in enumerate(sites):
        assert 'key' in site, f"Site {i} missing 'key' field"
        assert 'name' in site, f"Site {i} missing 'name' field"
        assert 'base' in site, f"Site {i} ({site.get('key', 'unknown')}) missing 'base' field"
        assert 'discovery' in site, f"Site {i} ({site.get('key', 'unknown')}) missing 'discovery' field"


def test_site_keys_unique():
    """Test that all site keys are unique"""
    config = load_sources_config()
    sites = config.get('sites', [])

    keys = [site.get('key') for site in sites]
    assert len(keys) == len(set(keys)), "Site keys must be unique"


def test_specific_20_sites_present():
    """Test that all 20 required sites are present"""
    config = load_sources_config()
    sites = config.get('sites', [])

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

    actual_keys = [site.get('key') for site in sites]

    for expected_key in expected_keys:
        assert expected_key in actual_keys, f"Required site '{expected_key}' not found"


def test_defaults_have_required_sections():
    """Test that defaults have required sections"""
    config = load_sources_config()
    defaults = config.get('defaults', {})

    assert 'mealie' in defaults, "Defaults must have 'mealie' section"
    assert 'limits' in defaults, "Defaults must have 'limits' section"
    assert 'crawling' in defaults, "Defaults must have 'crawling' section"
    assert 'filtering' in defaults, "Defaults must have 'filtering' section"


def test_limits_have_required_values():
    """Test that limits have all required values"""
    config = load_sources_config()
    limits = config.get('defaults', {}).get('limits', {})

    assert 'backfill_per_site' in limits, "Limits must have 'backfill_per_site'"
    assert 'monthly_max_new_per_site' in limits, "Limits must have 'monthly_max_new_per_site'"
    assert 'backfill_total_cap' in limits, "Limits must have 'backfill_total_cap'"
    assert 'monthly_total_cap' in limits, "Limits must have 'monthly_total_cap'"

    # Check values match requirements
    assert limits['backfill_per_site'] == 75, "backfill_per_site should be 75"
    assert limits['monthly_max_new_per_site'] == 40, "monthly_max_new_per_site should be 40"
    assert limits['backfill_total_cap'] == 1500, "backfill_total_cap should be 1500"
    assert limits['monthly_total_cap'] == 800, "monthly_total_cap should be 800"


def test_sites_have_tags():
    """Test that sites have tags configured"""
    config = load_sources_config()
    sites = config.get('sites', [])

    for site in sites:
        tags = site.get('tags', [])
        assert len(tags) > 0, f"Site '{site.get('key')}' should have at least one tag"

        # Each site should have a source tag
        source_tags = [t for t in tags if t.startswith('source:')]
        assert len(source_tags) >= 1, f"Site '{site.get('key')}' should have a source: tag"


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
