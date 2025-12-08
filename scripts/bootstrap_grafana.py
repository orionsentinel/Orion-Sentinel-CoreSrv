#!/usr/bin/env python3
"""
Grafana Bootstrap Script
=========================
Automates Grafana provisioning by reloading datasources and dashboards via API.

This script:
1. Polls Grafana health endpoint until ready
2. Authenticates with admin credentials
3. Reloads datasource and dashboard provisioning
4. Displays configured datasources and dashboards

Requirements:
- Grafana running and accessible
- Admin credentials via environment variables
- Only uses Python standard library (no external dependencies)

Usage:
    export GRAFANA_URL="http://127.0.0.1:3000"
    export GRAFANA_ADMIN_USER="admin"
    export GRAFANA_ADMIN_PASSWORD="your-password"
    python3 scripts/bootstrap_grafana.py
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error
import base64
from pathlib import Path
from typing import Optional, Dict, Any, List


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

GRAFANA_URL = os.environ.get("GRAFANA_URL", "http://127.0.0.1:3000")
GRAFANA_ADMIN_USER = os.environ.get("GRAFANA_ADMIN_USER", "admin")
GRAFANA_ADMIN_PASSWORD = os.environ.get("GRAFANA_ADMIN_PASSWORD", "")

HEALTH_CHECK_RETRIES = 30
HEALTH_CHECK_INTERVAL = 2  # seconds

REPO_ROOT = Path(__file__).resolve().parents[1]


# -----------------------------------------------------------------------------
# Logging Helpers
# -----------------------------------------------------------------------------

def info(msg: str) -> None:
    """Print info message."""
    print(f"[INFO] {msg}")


def warn(msg: str) -> None:
    """Print warning message."""
    print(f"[WARN] {msg}")


def error(msg: str) -> None:
    """Print error message."""
    print(f"[ERR] {msg}")


def success(msg: str) -> None:
    """Print success message."""
    print(f"[OK] {msg}")


# -----------------------------------------------------------------------------
# HTTP Helpers
# -----------------------------------------------------------------------------

def make_request(
    url: str,
    method: str = "GET",
    auth: Optional[str] = None,
    data: Optional[bytes] = None,
) -> Optional[Dict[str, Any]]:
    """
    Make HTTP request and return JSON response.
    
    Args:
        url: Full URL to request
        method: HTTP method (GET, POST, etc.)
        auth: Basic auth string (user:pass)
        data: Request body (for POST)
    
    Returns:
        Parsed JSON response or None on error
    """
    req = urllib.request.Request(url, method=method, data=data)
    
    if auth:
        auth_bytes = base64.b64encode(auth.encode("utf-8"))
        req.add_header("Authorization", f"Basic {auth_bytes.decode('ascii')}")
    
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            if response.status >= 200 and response.status < 300:
                body = response.read().decode("utf-8")
                if body:
                    return json.loads(body)
                return {}
            else:
                error(f"HTTP {response.status}: {response.reason}")
                return None
    except urllib.error.HTTPError as e:
        error(f"HTTP error {e.code}: {e.reason}")
        return None
    except urllib.error.URLError as e:
        error(f"URL error: {e.reason}")
        return None
    except Exception as e:
        error(f"Request failed: {e}")
        return None


# -----------------------------------------------------------------------------
# Grafana API Functions
# -----------------------------------------------------------------------------

def check_health(base_url: str) -> bool:
    """Check if Grafana is healthy."""
    url = f"{base_url.rstrip('/')}/api/health"
    result = make_request(url)
    return result is not None


def wait_for_grafana(base_url: str, max_retries: int, interval: int) -> bool:
    """
    Poll Grafana health endpoint until ready.
    
    Args:
        base_url: Grafana base URL
        max_retries: Maximum number of retries
        interval: Seconds between retries
    
    Returns:
        True if Grafana became healthy, False otherwise
    """
    info(f"Waiting for Grafana to be ready at {base_url}...")
    
    for attempt in range(1, max_retries + 1):
        if check_health(base_url):
            success(f"Grafana is healthy (attempt {attempt}/{max_retries})")
            return True
        
        if attempt < max_retries:
            time.sleep(interval)
    
    error(f"Grafana did not become healthy after {max_retries} attempts")
    return False


def reload_datasources(base_url: str, auth: str) -> bool:
    """Reload datasource provisioning."""
    url = f"{base_url.rstrip('/')}/api/admin/provisioning/datasources/reload"
    info("Reloading datasource provisioning...")
    
    result = make_request(url, method="POST", auth=auth)
    if result is not None:
        success("Datasource provisioning reloaded")
        return True
    else:
        warn("Failed to reload datasources (endpoint may not be available)")
        return False


def reload_dashboards(base_url: str, auth: str) -> bool:
    """Reload dashboard provisioning."""
    url = f"{base_url.rstrip('/')}/api/admin/provisioning/dashboards/reload"
    info("Reloading dashboard provisioning...")
    
    result = make_request(url, method="POST", auth=auth)
    if result is not None:
        success("Dashboard provisioning reloaded")
        return True
    else:
        warn("Failed to reload dashboards (endpoint may not be available)")
        return False


def list_datasources(base_url: str, auth: str) -> None:
    """List all configured datasources."""
    url = f"{base_url.rstrip('/')}/api/datasources"
    info("Fetching datasources...")
    
    result = make_request(url, auth=auth)
    if result is None:
        error("Failed to fetch datasources")
        return
    
    if not result:
        warn("No datasources configured")
        return
    
    info(f"Found {len(result)} datasource(s):")
    for ds in result:
        name = ds.get("name", "Unknown")
        ds_type = ds.get("type", "unknown")
        is_default = ds.get("isDefault", False)
        default_marker = " (default)" if is_default else ""
        print(f"  - {name} [{ds_type}]{default_marker}")


def list_dashboards(base_url: str, auth: str) -> None:
    """List all dashboards."""
    url = f"{base_url.rstrip('/')}/api/search?type=dash-db"
    info("Fetching dashboards...")
    
    result = make_request(url, auth=auth)
    if result is None:
        error("Failed to fetch dashboards")
        return
    
    if not result:
        warn("No dashboards found")
        return
    
    info(f"Found {len(result)} dashboard(s):")
    for dash in result:
        title = dash.get("title", "Unknown")
        uid = dash.get("uid", "N/A")
        folder = dash.get("folderTitle", "General")
        print(f"  - {title} (uid: {uid}, folder: {folder})")


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main() -> int:
    """Main entry point."""
    info("=== Grafana Bootstrap Script ===")
    info(f"Repo root: {REPO_ROOT}")
    info(f"Grafana URL: {GRAFANA_URL}")
    info(f"Admin user: {GRAFANA_ADMIN_USER}")
    
    # Validate credentials
    if not GRAFANA_ADMIN_PASSWORD:
        error("GRAFANA_ADMIN_PASSWORD environment variable is required")
        error("Please set it before running this script:")
        error("  export GRAFANA_ADMIN_PASSWORD='your-password'")
        return 1
    
    # Build auth string
    auth = f"{GRAFANA_ADMIN_USER}:{GRAFANA_ADMIN_PASSWORD}"
    
    # Wait for Grafana to be ready
    if not wait_for_grafana(GRAFANA_URL, HEALTH_CHECK_RETRIES, HEALTH_CHECK_INTERVAL):
        error("Grafana is not accessible, aborting")
        return 1
    
    print()
    
    # Reload provisioning
    reload_datasources(GRAFANA_URL, auth)
    reload_dashboards(GRAFANA_URL, auth)
    
    print()
    
    # List datasources and dashboards
    list_datasources(GRAFANA_URL, auth)
    print()
    list_dashboards(GRAFANA_URL, auth)
    
    print()
    success("Grafana bootstrap complete!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
