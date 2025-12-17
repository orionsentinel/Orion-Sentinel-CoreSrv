#!/usr/bin/env python3
"""
Structured logging configuration for Mealie Recipe Sync
Outputs JSON-formatted logs for easy parsing by Loki/Promtail
"""

import sys
import logging
import json
from datetime import datetime
from typing import Any, Dict


class StructuredFormatter(logging.Formatter):
    """JSON formatter for structured logging"""
    
    def format(self, record: logging.LogRecord) -> str:
        """Format log record as JSON"""
        log_data: Dict[str, Any] = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
        }
        
        # Add extra fields
        if hasattr(record, 'url'):
            log_data['url'] = record.url
        if hasattr(record, 'source'):
            log_data['source'] = record.source
        if hasattr(record, 'recipe_name'):
            log_data['recipe_name'] = record.recipe_name
        
        # Add exception info if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_data)


def setup_logging(use_json: bool = False) -> logging.Logger:
    """
    Configure logging for the application
    
    Args:
        use_json: If True, output JSON-formatted logs. If False, use human-readable format.
    
    Returns:
        Root logger configured for the application
    """
    root_logger = logging.getLogger()
    root_logger.setLevel(logging.INFO)
    
    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)
    
    # Create console handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(logging.INFO)
    
    # Set formatter based on preference
    if use_json:
        formatter = StructuredFormatter()
    else:
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
    
    handler.setFormatter(formatter)
    root_logger.addHandler(handler)
    
    return root_logger


def get_logger(name: str) -> logging.Logger:
    """Get a logger instance for a module"""
    return logging.getLogger(name)
