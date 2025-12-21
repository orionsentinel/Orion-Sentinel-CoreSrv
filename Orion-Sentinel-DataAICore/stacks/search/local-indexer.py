#!/usr/bin/env python3
"""
Local Document Indexer for Orion-Sentinel-DataAICore
Watches a directory for documents and indexes them in Meilisearch via Tika extraction.

Supported formats: PDF, TXT, MD, DOCX, ODT, RTF
"""

import os
import sys
import time
import hashlib
import logging
from pathlib import Path
from typing import Dict, List, Optional

import requests
import meilisearch
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileModifiedEvent

# Configuration from environment
MEILISEARCH_URL = os.getenv("MEILISEARCH_URL", "http://meilisearch:7700")
MEILISEARCH_API_KEY = os.getenv("MEILISEARCH_API_KEY", "")
TIKA_URL = os.getenv("TIKA_URL", "http://tika:9998")
WATCH_DIR = os.getenv("WATCH_DIR", "/watch")
INDEX_NAME = os.getenv("INDEX_NAME", "local_documents")
SCAN_INTERVAL = int(os.getenv("SCAN_INTERVAL", "30"))
MAX_CONTENT_SIZE = int(os.getenv("MAX_CONTENT_SIZE", "50000"))
STARTUP_WAIT = int(os.getenv("STARTUP_WAIT", "10"))
FILE_SETTLE_TIME = int(os.getenv("FILE_SETTLE_TIME", "2"))

# Supported file extensions
SUPPORTED_EXTENSIONS = {".pdf", ".txt", ".md", ".docx", ".odt", ".rtf", ".doc"}

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)


class DocumentIndexer:
    """Indexes local documents to Meilisearch using Tika for extraction."""
    
    def __init__(self):
        """Initialize Meilisearch client and index."""
        try:
            self.client = meilisearch.Client(MEILISEARCH_URL, MEILISEARCH_API_KEY)
            
            # Create or get index
            try:
                self.index = self.client.get_index(INDEX_NAME)
                logger.info(f"Connected to existing index: {INDEX_NAME}")
            except meilisearch.errors.MeilisearchApiError:
                self.index = self.client.create_index(INDEX_NAME, {"primaryKey": "id"})
                logger.info(f"Created new index: {INDEX_NAME}")
            
            # Configure searchable attributes
            self.index.update_searchable_attributes(["title", "content", "filename"])
            self.index.update_filterable_attributes(["type", "path"])
            
            logger.info("Meilisearch indexer initialized")
        except Exception as e:
            logger.error(f"Failed to initialize Meilisearch: {e}")
            raise
    
    def extract_text(self, file_path: Path) -> Optional[str]:
        """Extract text from document using Tika."""
        try:
            with open(file_path, "rb") as f:
                response = requests.put(
                    f"{TIKA_URL}/tika",
                    data=f,
                    headers={"Accept": "text/plain"},
                    timeout=60
                )
            
            if response.status_code == 200:
                return response.text.strip()
            else:
                logger.warning(f"Tika extraction failed for {file_path}: {response.status_code}")
                return None
        except Exception as e:
            logger.error(f"Error extracting text from {file_path}: {e}")
            return None
    
    def get_file_hash(self, file_path: Path) -> str:
        """Calculate MD5 hash of file for change detection."""
        md5 = hashlib.md5()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                md5.update(chunk)
        return md5.hexdigest()
    
    def index_document(self, file_path: Path) -> bool:
        """Index a single document."""
        try:
            # Extract text
            logger.info(f"Indexing: {file_path.name}")
            content = self.extract_text(file_path)
            
            if not content:
                logger.warning(f"No content extracted from {file_path.name}")
                return False
            
            # Create document
            file_hash = self.get_file_hash(file_path)
            doc_id = hashlib.md5(str(file_path).encode()).hexdigest()
            
            document = {
                "id": doc_id,
                "title": file_path.stem,
                "filename": file_path.name,
                "content": content[:MAX_CONTENT_SIZE],  # Limit content size (configurable)
                "type": file_path.suffix[1:],  # Remove leading dot
                "path": str(file_path),
                "hash": file_hash,
                "indexed_at": int(time.time())
            }
            
            # Add to index
            self.index.add_documents([document])
            logger.info(f"✓ Indexed: {file_path.name} ({len(content)} chars)")
            return True
            
        except Exception as e:
            logger.error(f"Failed to index {file_path}: {e}")
            return False
    
    def scan_directory(self, directory: Path) -> int:
        """Scan directory and index all supported documents."""
        indexed = 0
        
        for file_path in directory.rglob("*"):
            if not file_path.is_file():
                continue
            
            if file_path.suffix.lower() not in SUPPORTED_EXTENSIONS:
                continue
            
            # Skip hidden files
            if file_path.name.startswith("."):
                continue
            
            if self.index_document(file_path):
                indexed += 1
        
        return indexed


class DocumentEventHandler(FileSystemEventHandler):
    """Watchdog handler for document changes."""
    
    def __init__(self, indexer: DocumentIndexer):
        self.indexer = indexer
    
    def on_created(self, event):
        """Handle new file creation."""
        if event.is_directory:
            return
        
        file_path = Path(event.src_path)
        
        if file_path.suffix.lower() in SUPPORTED_EXTENSIONS:
            logger.info(f"New file detected: {file_path.name}")
            # Wait for file to be fully written - check size stability
            self._wait_for_file_stable(file_path)
            self.indexer.index_document(file_path)
    
    def _wait_for_file_stable(self, file_path: Path, max_wait: int = 10) -> bool:
        """Wait for file size to stabilize before processing."""
        last_size = -1
        stable_count = 0
        wait_time = 0
        
        while wait_time < max_wait:
            try:
                current_size = file_path.stat().st_size
                if current_size == last_size:
                    stable_count += 1
                    if stable_count >= 2:  # File size stable for 2 checks
                        return True
                else:
                    stable_count = 0
                last_size = current_size
                time.sleep(FILE_SETTLE_TIME)
                wait_time += FILE_SETTLE_TIME
            except (FileNotFoundError, OSError):
                time.sleep(FILE_SETTLE_TIME)
                wait_time += FILE_SETTLE_TIME
        
        return False
    
    def on_modified(self, event):
        """Handle file modification."""
        if event.is_directory:
            return
        
        file_path = Path(event.src_path)
        
        if file_path.suffix.lower() in SUPPORTED_EXTENSIONS:
            logger.info(f"File modified: {file_path.name}")
            # Wait for file to be fully written - check size stability
            self._wait_for_file_stable(file_path)
            self.indexer.index_document(file_path)


def main():
    """Main entry point."""
    logger.info("=" * 60)
    logger.info("Local Document Indexer Starting")
    logger.info("=" * 60)
    logger.info(f"Meilisearch URL: {MEILISEARCH_URL}")
    logger.info(f"Tika URL: {TIKA_URL}")
    logger.info(f"Watch directory: {WATCH_DIR}")
    logger.info(f"Index name: {INDEX_NAME}")
    logger.info(f"Supported formats: {', '.join(sorted(SUPPORTED_EXTENSIONS))}")
    logger.info("=" * 60)
    
    # Wait for services to be ready
    logger.info(f"Waiting {STARTUP_WAIT} seconds for Meilisearch and Tika to be ready...")
    time.sleep(STARTUP_WAIT)
    
    # Initialize indexer
    try:
        indexer = DocumentIndexer()
    except Exception as e:
        logger.error(f"Failed to initialize indexer: {e}")
        sys.exit(1)
    
    # Initial scan
    watch_path = Path(WATCH_DIR)
    if watch_path.exists():
        logger.info(f"Performing initial scan of {WATCH_DIR}...")
        indexed = indexer.scan_directory(watch_path)
        logger.info(f"Initial scan complete: {indexed} documents indexed")
    else:
        logger.warning(f"Watch directory {WATCH_DIR} does not exist")
        watch_path.mkdir(parents=True, exist_ok=True)
        logger.info(f"Created watch directory: {WATCH_DIR}")
    
    # Start file watcher
    logger.info("Starting file watcher...")
    event_handler = DocumentEventHandler(indexer)
    observer = Observer()
    observer.schedule(event_handler, str(watch_path), recursive=True)
    observer.start()
    
    logger.info("✓ Indexer is running")
    logger.info(f"Watching for changes every {SCAN_INTERVAL} seconds...")
    logger.info("Drop files into the watch directory to index them")
    
    try:
        while True:
            time.sleep(SCAN_INTERVAL)
    except KeyboardInterrupt:
        logger.info("Stopping indexer...")
        observer.stop()
    
    observer.join()
    logger.info("Indexer stopped")


if __name__ == "__main__":
    main()
