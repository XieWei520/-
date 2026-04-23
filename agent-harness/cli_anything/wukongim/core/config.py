#!/usr/bin/env python3
"""
Configuration management for WuKongIM CLI.
"""

import os
import json
from pathlib import Path
from typing import Optional, Dict, Any


class Config:
    """Configuration manager for WuKongIM CLI."""
    
    # Default configuration
    DEFAULT_API_URL = "http://42.194.218.158"
    DEFAULT_APP_ID = "wukongchat"
    DEFAULT_APP_KEY = "25b002c6be2d539f264c"
    
    def __init__(self):
        self._config_dir = Path.home() / ".wukongim"
        self._config_file = self._config_dir / "config.json"
        self._ensure_config_dir()
        self._config = self._load_config()
    
    def _ensure_config_dir(self):
        """Create config directory if it doesn't exist."""
        self._config_dir.mkdir(parents=True, exist_ok=True)
    
    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from file."""
        if self._config_file.exists():
            try:
                with open(self._config_file, "r", encoding="utf-8") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError):
                pass
        return {}
    
    def _save_config(self):
        """Save configuration to file."""
        with open(self._config_file, "w", encoding="utf-8") as f:
            json.dump(self._config, f, indent=2, ensure_ascii=False)
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value."""
        # Check environment variables first
        env_key = f"WK_{key.upper()}"
        if env_key in os.environ:
            return os.environ[env_key]
        
        # Then check config file
        return self._config.get(key, default)
    
    def set(self, key: str, value: Any):
        """Set configuration value."""
        self._config[key] = value
        self._save_config()
    
    @property
    def api_url(self) -> str:
        """Get API base URL."""
        return self.get("api_url", self.DEFAULT_API_URL)
    
    @property
    def app_id(self) -> str:
        """Get App ID."""
        return self.get("app_id", self.DEFAULT_APP_ID)
    
    @property
    def app_key(self) -> str:
        """Get App Key."""
        return self.get("app_key", self.DEFAULT_APP_KEY)
    
    def update(self, **kwargs):
        """Update multiple configuration values."""
        for key, value in kwargs.items():
            self._config[key] = value
        self._save_config()
    
    def reset(self):
        """Reset configuration to defaults."""
        self._config = {}
        if self._config_file.exists():
            self._config_file.unlink()


# Global config instance
_config: Optional[Config] = None


def get_config() -> Config:
    """Get global configuration instance."""
    global _config
    if _config is None:
        _config = Config()
    return _config
