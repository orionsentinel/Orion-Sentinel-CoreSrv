"""
Test URL normalization and domain filtering
Ensures URLs are properly normalized and filtered
"""

import sys
import pytest
from pathlib import Path

# Add app directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent / 'app'))

from crawler import URLNormalizer


class TestURLNormalization:
    """Test URL normalization functionality"""
    
    def test_removes_utm_parameters(self):
        """Test that UTM tracking parameters are removed"""
        url = "https://example.com/recipe?utm_source=facebook&utm_medium=social"
        normalized = URLNormalizer.normalize(url)
        assert 'utm_source' not in normalized
        assert 'utm_medium' not in normalized
        assert 'example.com/recipe' in normalized
    
    def test_removes_fbclid(self):
        """Test that Facebook click ID is removed"""
        url = "https://example.com/recipe?fbclid=abc123"
        normalized = URLNormalizer.normalize(url)
        assert 'fbclid' not in normalized
    
    def test_removes_gclid(self):
        """Test that Google click ID is removed"""
        url = "https://example.com/recipe?gclid=xyz789"
        normalized = URLNormalizer.normalize(url)
        assert 'gclid' not in normalized
    
    def test_removes_fragment(self):
        """Test that URL fragments are removed"""
        url = "https://example.com/recipe#comments"
        normalized = URLNormalizer.normalize(url)
        assert '#comments' not in normalized
        assert normalized.endswith('/recipe')
    
    def test_preserves_valid_parameters(self):
        """Test that non-tracking parameters are preserved"""
        url = "https://example.com/recipe?id=123&category=dessert"
        normalized = URLNormalizer.normalize(url)
        assert 'id=123' in normalized or 'id=123' in normalized.replace('%', '')
        assert 'category=dessert' in normalized or 'category=dessert' in normalized.replace('%', '')
    
    def test_handles_url_without_parameters(self):
        """Test normalization of URL without parameters"""
        url = "https://example.com/recipe"
        normalized = URLNormalizer.normalize(url)
        assert 'example.com/recipe' in normalized
    
    def test_handles_multiple_tracking_parameters(self):
        """Test removal of multiple tracking parameters"""
        url = "https://example.com/recipe?utm_source=email&utm_campaign=newsletter&fbclid=abc&gclid=xyz&ref=homepage"
        normalized = URLNormalizer.normalize(url)
        assert 'utm_source' not in normalized
        assert 'utm_campaign' not in normalized
        assert 'fbclid' not in normalized
        assert 'gclid' not in normalized
        assert 'ref' not in normalized


class TestDomainExtraction:
    """Test domain extraction functionality"""
    
    def test_extracts_domain_from_url(self):
        """Test basic domain extraction"""
        url = "https://example.com/recipe/chocolate-cake"
        domain = URLNormalizer.extract_domain(url)
        assert domain == "example.com"
    
    def test_extracts_domain_with_www(self):
        """Test domain extraction with www"""
        url = "https://www.example.com/recipe"
        domain = URLNormalizer.extract_domain(url)
        assert domain == "www.example.com"
    
    def test_extracts_subdomain(self):
        """Test subdomain extraction"""
        url = "https://blog.example.com/post"
        domain = URLNormalizer.extract_domain(url)
        assert domain == "blog.example.com"
    
    def test_domain_lowercase(self):
        """Test that domain is returned in lowercase"""
        url = "https://Example.COM/recipe"
        domain = URLNormalizer.extract_domain(url)
        assert domain == "example.com"


class TestDomainMatching:
    """Test domain matching and filtering"""
    
    def test_exact_domain_match(self):
        """Test exact domain matching"""
        url = "https://example.com/recipe"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_subdomain_match(self):
        """Test subdomain matching"""
        url = "https://www.example.com/recipe"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_deep_subdomain_match(self):
        """Test deep subdomain matching"""
        url = "https://blog.recipes.example.com/post"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_wildcard_subdomain_match(self):
        """Test wildcard subdomain pattern"""
        url = "https://www.example.com/recipe"
        allowed = [".example.com"]  # Matches any subdomain
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_wildcard_matches_root_domain(self):
        """Test that wildcard also matches root domain"""
        url = "https://example.com/recipe"
        allowed = [".example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_domain_not_in_allowed_list(self):
        """Test rejection of domain not in allowed list"""
        url = "https://different.com/recipe"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is False
    
    def test_multiple_allowed_domains(self):
        """Test matching against multiple allowed domains"""
        url = "https://example.com/recipe"
        allowed = ["different.com", "example.com", "another.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_case_insensitive_matching(self):
        """Test that domain matching is case-insensitive"""
        url = "https://Example.COM/recipe"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_similar_domain_no_match(self):
        """Test that similar but different domains don't match"""
        url = "https://example.org/recipe"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is False
    
    def test_partial_domain_no_match(self):
        """Test that partial domain strings don't match"""
        url = "https://notexample.com/recipe"
        allowed = ["example.com"]
        assert URLNormalizer.matches_domain(url, allowed) is False


class TestRealWorldScenarios:
    """Test real-world URL scenarios"""
    
    def test_guardian_url_normalization(self):
        """Test normalization of Guardian URL"""
        url = "https://www.theguardian.com/food/2023/oct/15/recipe?utm_source=twitter#comments"
        normalized = URLNormalizer.normalize(url)
        assert 'utm_source' not in normalized
        assert '#comments' not in normalized
        assert 'theguardian.com' in normalized
    
    def test_guardian_domain_matching(self):
        """Test Guardian domain matching"""
        url = "https://www.theguardian.com/food/series/yotam-ottolenghi-recipes"
        allowed = ["theguardian.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_ottolenghi_url(self):
        """Test Ottolenghi URL handling"""
        url = "https://ottolenghi.co.uk/recipes/some-recipe?ref=homepage"
        normalized = URLNormalizer.normalize(url)
        allowed = ["ottolenghi.co.uk"]
        assert URLNormalizer.matches_domain(normalized, allowed) is True
        assert 'ref=' not in normalized
    
    def test_bbc_goodfood_url(self):
        """Test BBC Good Food URL"""
        url = "https://www.bbcgoodfood.com/recipes/collection/middle-eastern-recipes"
        allowed = ["bbcgoodfood.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True
    
    def test_serious_eats_url(self):
        """Test Serious Eats URL"""
        url = "https://www.seriouseats.com/middle-eastern-recipes-5117255"
        allowed = ["seriouseats.com"]
        assert URLNormalizer.matches_domain(url, allowed) is True


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
