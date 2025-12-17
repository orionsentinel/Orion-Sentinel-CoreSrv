#!/usr/bin/env python3
"""
State management using SQLite database
Tracks imported recipes, attempts, and failures
"""

import sqlite3
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Dict, Set
from contextlib import contextmanager

from logger import get_logger

logger = get_logger(__name__)


class StateManager:
    """Manages persistent state using SQLite"""
    
    def __init__(self, db_path: Path):
        """
        Initialize state manager
        
        Args:
            db_path: Path to SQLite database file
        """
        self.db_path = db_path
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
            
            # Table for seen URLs
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS seen_urls (
                    url TEXT PRIMARY KEY,
                    first_seen_at TEXT NOT NULL,
                    domain TEXT NOT NULL
                )
            """)
            
            # Table for import attempts
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS attempts (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    url TEXT NOT NULL,
                    attempted_at TEXT NOT NULL,
                    success INTEGER NOT NULL,
                    error_message TEXT,
                    FOREIGN KEY (url) REFERENCES seen_urls(url)
                )
            """)
            
            # Table for successful imports
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS imports (
                    url TEXT PRIMARY KEY,
                    imported_at TEXT NOT NULL,
                    recipe_name TEXT,
                    source_name TEXT,
                    FOREIGN KEY (url) REFERENCES seen_urls(url)
                )
            """)
            
            # Table for sync runs
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sync_runs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    started_at TEXT NOT NULL,
                    completed_at TEXT,
                    urls_discovered INTEGER DEFAULT 0,
                    urls_imported INTEGER DEFAULT 0,
                    urls_failed INTEGER DEFAULT 0,
                    error_message TEXT
                )
            """)
            
            # Create indexes for performance
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_attempts_url 
                ON attempts(url)
            """)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_imports_imported_at 
                ON imports(imported_at)
            """)
            
            logger.info(f"Database initialized at {self.db_path}")
    
    def is_url_imported(self, url: str) -> bool:
        """Check if URL has been successfully imported"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(
                "SELECT 1 FROM imports WHERE url = ?",
                (url,)
            )
            return cursor.fetchone() is not None
    
    def mark_url_seen(self, url: str, domain: str):
        """Mark URL as seen"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT OR IGNORE INTO seen_urls (url, first_seen_at, domain)
                VALUES (?, ?, ?)
            """, (url, datetime.utcnow().isoformat(), domain))
    
    def record_attempt(self, url: str, success: bool, error_message: Optional[str] = None):
        """Record an import attempt"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO attempts (url, attempted_at, success, error_message)
                VALUES (?, ?, ?, ?)
            """, (url, datetime.utcnow().isoformat(), 1 if success else 0, error_message))
    
    def record_import(self, url: str, recipe_name: Optional[str] = None, 
                     source_name: Optional[str] = None):
        """Record a successful import"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT OR REPLACE INTO imports (url, imported_at, recipe_name, source_name)
                VALUES (?, ?, ?, ?)
            """, (url, datetime.utcnow().isoformat(), recipe_name, source_name))
    
    def get_imported_urls(self) -> Set[str]:
        """Get set of all imported URLs"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("SELECT url FROM imports")
            return {row['url'] for row in cursor.fetchall()}
    
    def start_sync_run(self) -> int:
        """Start a new sync run and return its ID"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                INSERT INTO sync_runs (started_at)
                VALUES (?)
            """, (datetime.utcnow().isoformat(),))
            return cursor.lastrowid
    
    def complete_sync_run(self, run_id: int, urls_discovered: int, 
                         urls_imported: int, urls_failed: int,
                         error_message: Optional[str] = None):
        """Complete a sync run with stats"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            if error_message:
                cursor.execute("""
                    UPDATE sync_runs 
                    SET completed_at = ?,
                        urls_discovered = ?,
                        urls_imported = ?,
                        urls_failed = ?,
                        error_message = ?
                    WHERE id = ?
                """, (datetime.utcnow().isoformat(), urls_discovered, urls_imported, 
                      urls_failed, error_message, run_id))
            else:
                cursor.execute("""
                    UPDATE sync_runs 
                    SET completed_at = ?,
                        urls_discovered = ?,
                        urls_imported = ?,
                        urls_failed = ?
                    WHERE id = ?
                """, (datetime.utcnow().isoformat(), urls_discovered, urls_imported, 
                      urls_failed, run_id))
    
    def get_stats(self) -> Dict:
        """Get overall statistics"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            
            # Total imports
            cursor.execute("SELECT COUNT(*) as count FROM imports")
            total_imports = cursor.fetchone()['count']
            
            # Total attempts
            cursor.execute("SELECT COUNT(*) as count FROM attempts")
            total_attempts = cursor.fetchone()['count']
            
            # Failed attempts
            cursor.execute("SELECT COUNT(*) as count FROM attempts WHERE success = 0")
            failed_attempts = cursor.fetchone()['count']
            
            # Last sync run
            cursor.execute("""
                SELECT * FROM sync_runs 
                ORDER BY started_at DESC 
                LIMIT 1
            """)
            last_run = cursor.fetchone()
            
            return {
                'total_imports': total_imports,
                'total_attempts': total_attempts,
                'failed_attempts': failed_attempts,
                'last_run': dict(last_run) if last_run else None
            }
    
    def get_recent_failures(self, limit: int = 10) -> List[Dict]:
        """Get recent failed import attempts"""
        with self._get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
                SELECT url, attempted_at, error_message
                FROM attempts
                WHERE success = 0
                ORDER BY attempted_at DESC
                LIMIT ?
            """, (limit,))
            return [dict(row) for row in cursor.fetchall()]
