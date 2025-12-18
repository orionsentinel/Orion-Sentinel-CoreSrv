#!/usr/bin/env python3
"""
SQLite State Database for Mealie Importer

Maintains idempotency by tracking:
- Discovered URLs with domain and timestamps
- Import status (imported, failed, queued)
- Recipe slugs/IDs returned by Mealie
- HTML hashes for HTML import fallback
- Import run statistics
"""

import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Set
from contextlib import contextmanager

from logger import get_logger

logger = get_logger(__name__)


class StateDB:
    """SQLite state database for import tracking"""

    def __init__(self, db_path: Path):
        """
        Initialize state database.

        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = Path(db_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._init_database()

    @contextmanager
    def _get_connection(self):
        """Context manager for database connections"""
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        try:
            yield conn
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def _init_database(self):
        """Initialize database schema"""
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # URLs table - main tracking table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS urls (
                    url TEXT PRIMARY KEY,
                    domain TEXT NOT NULL,
                    source_key TEXT,
                    discovered_at TEXT NOT NULL,
                    imported_at TEXT,
                    status TEXT DEFAULT 'discovered',
                    last_error TEXT,
                    recipe_slug_or_id TEXT,
                    html_hash TEXT,
                    needs_reimport INTEGER DEFAULT 0
                )
            """)

            # Import runs table - tracks each run
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS runs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    mode TEXT NOT NULL,
                    started_at TEXT NOT NULL,
                    completed_at TEXT,
                    discovered_count INTEGER DEFAULT 0,
                    imported_count INTEGER DEFAULT 0,
                    failed_count INTEGER DEFAULT 0,
                    skipped_count INTEGER DEFAULT 0,
                    error_message TEXT
                )
            """)

            # Create indexes for performance
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_urls_domain
                ON urls(domain)
            """)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_urls_status
                ON urls(status)
            """)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_urls_source
                ON urls(source_key)
            """)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_urls_discovered_at
                ON urls(discovered_at)
            """)

            logger.info(f"Database initialized at {self.db_path}")

    def is_url_imported(self, url: str) -> bool:
        """
        Check if URL has been successfully imported.

        Args:
            url: URL to check

        Returns:
            True if already imported
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT 1 FROM urls
                WHERE url = ?
                AND status IN ('imported', 'imported_html')
                AND needs_reimport = 0
            """, (url,))
            return cursor.fetchone() is not None

    def is_url_seen(self, url: str) -> bool:
        """
        Check if URL has been discovered before.

        Args:
            url: URL to check

        Returns:
            True if URL is in database
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT 1 FROM urls WHERE url = ?", (url,))
            return cursor.fetchone() is not None

    def mark_url_discovered(self, url: str, domain: str, source_key: str):
        """
        Mark URL as discovered.

        Args:
            url: URL discovered
            domain: Domain of the URL
            source_key: Source identifier
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT OR IGNORE INTO urls
                (url, domain, source_key, discovered_at, status)
                VALUES (?, ?, ?, ?, 'discovered')
            """, (url, domain, source_key, datetime.utcnow().isoformat()))

    def record_import(
        self,
        url: str,
        source_key: str,
        status: str,
        recipe_slug: str = None,
        html_hash: str = None,
        last_error: str = None
    ):
        """
        Record import result.

        Args:
            url: URL imported
            source_key: Source identifier
            status: 'imported', 'imported_html', 'failed', 'queued'
            recipe_slug: Mealie recipe slug/ID if successful
            html_hash: Hash of HTML content if HTML import used
            last_error: Error message if failed
        """
        from urllib.parse import urlparse
        domain = urlparse(url).netloc.lower()

        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO urls
                (url, domain, source_key, discovered_at, imported_at, status,
                 recipe_slug_or_id, html_hash, last_error, needs_reimport)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                ON CONFLICT(url) DO UPDATE SET
                    imported_at = excluded.imported_at,
                    status = excluded.status,
                    recipe_slug_or_id = COALESCE(excluded.recipe_slug_or_id, recipe_slug_or_id),
                    html_hash = COALESCE(excluded.html_hash, html_hash),
                    last_error = excluded.last_error,
                    needs_reimport = 0
            """, (
                url,
                domain,
                source_key,
                datetime.utcnow().isoformat(),
                datetime.utcnow().isoformat() if status in ('imported', 'imported_html') else None,
                status,
                recipe_slug,
                html_hash,
                last_error
            ))

    def get_imported_urls(self) -> Set[str]:
        """
        Get set of all successfully imported URLs.

        Returns:
            Set of imported URLs
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT url FROM urls
                WHERE status IN ('imported', 'imported_html')
                AND needs_reimport = 0
            """)
            return {row['url'] for row in cursor.fetchall()}

    def get_urls_for_domain(self, domain: str) -> List[Dict]:
        """
        Get all URLs for a domain.

        Args:
            domain: Domain to query

        Returns:
            List of URL records
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT * FROM urls
                WHERE domain LIKE ?
                ORDER BY discovered_at DESC
            """, (f'%{domain}%',))
            return [dict(row) for row in cursor.fetchall()]

    def mark_domain_for_reimport(self, domain: str) -> int:
        """
        Mark all URLs from a domain for reimport.

        Args:
            domain: Domain to mark

        Returns:
            Number of URLs marked
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE urls
                SET needs_reimport = 1
                WHERE domain LIKE ?
            """, (f'%{domain}%',))
            return cursor.rowcount

    def reset_domain(self, domain: str) -> int:
        """
        Reset/clear all records for a domain.

        Args:
            domain: Domain to reset

        Returns:
            Number of records deleted
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                DELETE FROM urls
                WHERE domain LIKE ?
            """, (f'%{domain}%',))
            count = cursor.rowcount
            logger.info(f"Reset {count} URLs for domain: {domain}")
            return count

    def start_run(self, mode: str) -> int:
        """
        Start a new import run.

        Args:
            mode: 'backfill' or 'monthly'

        Returns:
            Run ID
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO runs (mode, started_at)
                VALUES (?, ?)
            """, (mode, datetime.utcnow().isoformat()))
            return cursor.lastrowid

    def complete_run(
        self,
        run_id: int,
        discovered: int,
        imported: int,
        failed: int,
        skipped: int,
        error_message: str = None
    ):
        """
        Complete an import run with statistics.

        Args:
            run_id: Run ID to complete
            discovered: Number of URLs discovered
            imported: Number of recipes imported
            failed: Number of failures
            skipped: Number skipped (already imported)
            error_message: Error if run failed
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE runs
                SET completed_at = ?,
                    discovered_count = ?,
                    imported_count = ?,
                    failed_count = ?,
                    skipped_count = ?,
                    error_message = ?
                WHERE id = ?
            """, (
                datetime.utcnow().isoformat(),
                discovered,
                imported,
                failed,
                skipped,
                error_message,
                run_id
            ))

    def get_stats(self) -> Dict:
        """
        Get overall import statistics.

        Returns:
            Dict with statistics
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()

            # Total URLs
            cursor.execute("SELECT COUNT(*) as count FROM urls")
            total_urls = cursor.fetchone()['count']

            # Imported
            cursor.execute("""
                SELECT COUNT(*) as count FROM urls
                WHERE status IN ('imported', 'imported_html')
            """)
            total_imported = cursor.fetchone()['count']

            # Failed
            cursor.execute("""
                SELECT COUNT(*) as count FROM urls
                WHERE status = 'failed'
            """)
            total_failed = cursor.fetchone()['count']

            # By domain
            cursor.execute("""
                SELECT domain, COUNT(*) as count
                FROM urls
                WHERE status IN ('imported', 'imported_html')
                GROUP BY domain
                ORDER BY count DESC
                LIMIT 20
            """)
            by_domain = [dict(row) for row in cursor.fetchall()]

            # Last run
            cursor.execute("""
                SELECT * FROM runs
                ORDER BY started_at DESC
                LIMIT 1
            """)
            last_run = cursor.fetchone()

            return {
                'total_urls': total_urls,
                'total_imported': total_imported,
                'total_failed': total_failed,
                'by_domain': by_domain,
                'last_run': dict(last_run) if last_run else None
            }

    def get_recent_failures(self, limit: int = 20) -> List[Dict]:
        """
        Get recent failed imports.

        Args:
            limit: Maximum results

        Returns:
            List of failed URL records
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT url, domain, source_key, last_error, discovered_at
                FROM urls
                WHERE status = 'failed'
                ORDER BY discovered_at DESC
                LIMIT ?
            """, (limit,))
            return [dict(row) for row in cursor.fetchall()]

    def get_queued_urls(self) -> List[str]:
        """
        Get URLs that were queued but not confirmed imported.

        Returns:
            List of queued URLs
        """
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT url FROM urls
                WHERE status = 'queued'
            """)
            return [row['url'] for row in cursor.fetchall()]
