"""
WuKongIM CLI Harness - Command-line interface for WuKongIM messaging platform.

This package provides CLI access to WuKongIM's REST API and WebSocket messaging.
"""

__version__ = "1.0.0"

from .wukongim_cli import main, WuKongIMClient, SessionManager

__all__ = ["main", "WuKongIMClient", "SessionManager"]
