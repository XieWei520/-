#!/usr/bin/env python3
"""
WuKongIM Backend Wrapper

This module provides a clean interface to the WuKongIM backend APIs,
wrapping the Flutter app's API structure for reuse in the CLI.
"""

import os
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

try:
    import requests
except ImportError:
    raise ImportError("requests library required. Install with: pip install requests")

from .auth import build_signed_headers


class WuKongIMBackend:
    """
    Backend wrapper for WuKongIM API.
    
    Provides direct access to the REST API endpoints used by the Flutter app.
    """
    
    def __init__(
        self,
        base_url: Optional[str] = None,
        token: Optional[str] = None,
        device_id: Optional[str] = None,
        device_session_id: Optional[str] = None,
        timestamp_ms_factory: Optional[Callable[[], int]] = None,
        nonce_factory: Optional[Callable[[int], str]] = None,
    ):
        """
        Initialize backend client.
        
        Args:
            base_url: API base URL (default: http://42.194.218.158)
            token: Authentication token (optional, can be set later)
        """
        self.base_url = base_url or os.getenv("WK_API_URL", "http://42.194.218.158")
        self.api_endpoint = f"{self.base_url}/v1"
        self.token = token
        self.device_id = device_id
        self.device_session_id = device_session_id
        self._timestamp_ms_factory = timestamp_ms_factory
        self._nonce_factory = nonce_factory
        self.session = requests.Session()
        self.session.headers.update({
            "Content-Type": "application/json",
            "Accept": "application/json",
        })
        if token:
            self.session.headers["token"] = token

    def set_token(self, token: str):
        """Set authentication token."""
        self.token = token
        self.session.headers["token"] = token

    def set_device_identity(
        self,
        device_id: Optional[str] = None,
        device_session_id: Optional[str] = None,
    ):
        """Set device identity values used in signed headers."""
        if device_id is not None:
            self.device_id = device_id
        if device_session_id is not None:
            self.device_session_id = device_session_id

    def clear_token(self):
        """Clear authentication token."""
        self.token = None
        self.session.headers.pop("token", None)

    def _build_headers(
        self,
        data: Optional[Dict] = None,
        include_json_content_type: bool = True,
        include_identity: bool = True,
    ) -> Dict[str, str]:
        """Build signed headers matching the Flutter app."""
        timestamp_ms = self._timestamp_ms_factory() if self._timestamp_ms_factory else None
        nonce = self._nonce_factory(16) if self._nonce_factory else None
        return build_signed_headers(
            data=data,
            token=self.token if include_identity else None,
            device_id=self.device_id if include_identity else None,
            device_session_id=self.device_session_id if include_identity else None,
            include_json_content_type=include_json_content_type,
            timestamp_ms=timestamp_ms,
            nonce=nonce,
        )

    def _request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        params: Optional[Dict] = None,
        require_auth: bool = True,
    ) -> Dict[str, Any]:
        """Make HTTP request to API."""
        url = f"{self.api_endpoint}{endpoint}"
        headers = self._build_headers(
            data=data if method in ["POST", "PUT", "PATCH", "DELETE"] else None,
            include_json_content_type=True,
            include_identity=require_auth,
        )
        
        try:
            response = self.session.request(
                method,
                url,
                json=data if method in ["POST", "PUT", "PATCH"] else None,
                params=params if method == "GET" else None,
                headers=headers,
                timeout=30
            )
            
            try:
                result = response.json() if response.content else {}
            except ValueError:
                if response.status_code >= 400:
                    raise APIError(f"HTTP {response.status_code}", response.status_code)
                raise APIError("Invalid JSON response", 0)

            if isinstance(result, dict):
                code = result.get("code", 0)
                if isinstance(code, str):
                    code = int(code) if code.isdigit() else 0

                if response.status_code >= 400 or (code and code != 0):
                    error_msg = result.get("msg") or result.get("message") or f"HTTP {response.status_code}"
                    raise APIError(error_msg, code)
            elif response.status_code >= 400:
                raise APIError(f"HTTP {response.status_code}", response.status_code)
            
            return result
            
        except requests.exceptions.RequestException as e:
            raise APIError(f"Connection error: {str(e)}", 0)
    
    # Authentication APIs
    def login(self, username: str, password: str, device_info: Optional[Dict] = None) -> Dict[str, Any]:
        """Login with username/password."""
        import uuid
        import hashlib
        
        payload = {
            "username": username,
            "password": password,
            "username_or_phone": username,
        }
        
        # Add device info
        device_id = hashlib.md5(f"{username}-{uuid.getnode()}".encode()).hexdigest()[:16]
        payload.update(device_info or {
            "device_id": device_id,
            "device_name": "CLI",
            "device_model": "CLI-Client",
            "device_install_id": str(uuid.uuid4()),
        })
        
        result = self._request("POST", "/user/usernamelogin", data=payload, require_auth=False)
        return result
    
    def register(self, username: str, password: str, name: Optional[str] = None, 
                 verify_code: Optional[str] = None) -> Dict[str, Any]:
        """Register new user."""
        payload = {
            "username": username,
            "password": password,
            "verify_code": verify_code or "",
            "name": name or username,
        }
        return self._request("POST", "/user/register", data=payload, require_auth=False)
    
    def get_user_info(self, uid: str) -> Dict[str, Any]:
        """Get user info by UID."""
        return self._request("GET", f"/users/{uid}")
    
    def update_user(self, uid: str, **kwargs) -> Dict[str, Any]:
        """Update user profile."""
        return self._request("PUT", f"/user/{uid}", data=kwargs)
    
    def get_qrcode(self) -> Dict[str, Any]:
        """Get QR code for current user."""
        return self._request("GET", "/user/qrcode")
    
    # Conversation APIs
    def get_conversations(self, limit: int = 20, offset: int = 0) -> Dict[str, Any]:
        """List conversations."""
        return self._request("GET", "/conversations", params={"limit": limit, "offset": offset})
    
    # Message APIs
    def send_message(self, channel_id: str, channel_type: int, content: str, 
                     content_type: int = 1) -> Dict[str, Any]:
        """Send a message."""
        payload = {
            "channel_id": channel_id,
            "channel_type": channel_type,
            "content": content,
            "content_type": content_type,
        }
        return self._request("POST", "/message/send", data=payload)
    
    def sync_messages(self, channel_id: str, channel_type: int, limit: int = 20, 
                      start_message_id: Optional[str] = None) -> Dict[str, Any]:
        """Sync messages for a channel."""
        payload = {
            "channel_id": channel_id,
            "channel_type": channel_type,
            "limit": limit,
        }
        if start_message_id:
            payload["start_message_id"] = start_message_id
        return self._request("POST", "/message/sync", data=payload)
    
    def search_messages(self, keyword: str, channel_id: str = "", 
                        channel_type: int = 0, limit: int = 20) -> Dict[str, Any]:
        """Search messages."""
        payload = {
            "keyword": keyword,
            "channel_id": channel_id,
            "channel_type": channel_type,
            "limit": limit,
        }
        return self._request("POST", "/message/search", data=payload)
    
    def revoke_message(self, message_id: str, channel_id: str, channel_type: int) -> Dict[str, Any]:
        """Revoke a message."""
        payload = {
            "message_id": message_id,
            "channel_id": channel_id,
            "channel_type": channel_type,
        }
        return self._request("POST", "/message/revoke", data=payload)
    
    def delete_message(self, message_id: str) -> Dict[str, Any]:
        """Delete a message."""
        return self._request("DELETE", f"/message/{message_id}")
    
    # Friend APIs
    def sync_friends(self) -> Dict[str, Any]:
        """Sync/list friends."""
        return self._request(
            "GET",
            "/friend/sync",
            params={"api_version": 1, "limit": 1000, "version": 0},
        )

    def apply_friend(self, friend_uid: str, remark: str = "") -> Dict[str, Any]:
        """Send friend request."""
        return self._request("POST", "/friend/apply", data={"to_uid": friend_uid, "remark": remark})

    def remove_friend(self, friend_uid: str) -> Dict[str, Any]:
        """Remove a friend."""
        return self._request("DELETE", f"/friend/sync/{friend_uid}")
    
    def respond_to_friend_request(self, friend_uid: str, accept: bool) -> Dict[str, Any]:
        """Accept or refuse friend request."""
        endpoint = "/friend/sure" if accept else "/friend/refuse"
        return self._request("POST", endpoint, data={"friend_uid": friend_uid})
    
    # Group APIs
    def create_group(self, name: str, members: List[str]) -> Dict[str, Any]:
        """Create a group."""
        return self._request("POST", "/group/create", data={"name": name, "members": members})
    
    def get_my_groups(self) -> Dict[str, Any]:
        """List my groups."""
        return self._request("GET", "/group/my")
    
    def get_group_info(self, group_id: str) -> Dict[str, Any]:
        """Get group info."""
        return self._request("GET", f"/groups/{group_id}")

    def get_group_members(self, group_id: str) -> Dict[str, Any]:
        """Get group members."""
        return self._request("GET", f"/groups/{group_id}/members")
    
    # File APIs
    def upload_file(self, file_path: str, on_progress=None) -> Dict[str, Any]:
        """Upload a file."""
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"File not found: {file_path}")
        
        files = {"file": open(path, "rb")}
        url = f"{self.api_endpoint}/file/upload"
        
        try:
            headers = self._build_headers(include_json_content_type=False)
            response = requests.post(
                url,
                files=files,
                headers=headers,
                timeout=60
            )
            result = response.json() if response.content else {}
            
            code = result.get("code", 0)
            if isinstance(code, str):
                code = int(code) if code.isdigit() else 0
            
            if response.status_code >= 400 or (code and code != 0):
                error_msg = result.get("msg") or result.get("message") or f"HTTP {response.status_code}"
                raise APIError(error_msg, code)
            
            return result
        finally:
            files["file"].close()
    
    # Blacklist APIs
    def get_blacklist(self) -> Dict[str, Any]:
        """Get blacklist."""
        return self._request("GET", "/user/blacklists")
    
    def add_to_blacklist(self, uid: str) -> Dict[str, Any]:
        """Add user to blacklist."""
        return self._request("POST", f"/user/blacklist/{uid}")
    
    def remove_from_blacklist(self, uid: str) -> Dict[str, Any]:
        """Remove user from blacklist."""
        return self._request("DELETE", f"/user/blacklist/{uid}")


class APIError(Exception):
    """API error exception."""
    def __init__(self, message: str, code: int = 0):
        self.message = message
        self.code = code
        super().__init__(self.message)
    
    def __str__(self):
        if self.code:
            return f"[{self.code}] {self.message}"
        return self.message
