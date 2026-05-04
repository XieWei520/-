#!/usr/bin/env python3
"""
WuKongIM CLI Harness - Command-line interface for WuKongIM messaging platform

This harness provides CLI access to WuKongIM's REST API and WebSocket messaging.
Supports authentication, user management, conversations, messaging, friends, groups, and file operations.

API Base: http://42.194.218.158/v1
WebSocket: 42.194.218.158:5100
"""

import argparse
import json
import os
import sys
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Optional

try:
    import requests
except ImportError:
    print("Error: 'requests' library required. Install with: pip install requests")
    sys.exit(1)

try:
    from .utils.auth import build_signed_headers
except ImportError:
    from utils.auth import build_signed_headers

# Configuration
API_BASE_URL = os.getenv("WK_API_URL", "http://42.194.218.158")
API_VERSION = "v1"
API_ENDPOINT = f"{API_BASE_URL}/{API_VERSION}"

# Session storage
SESSION_DIR = Path.home() / ".wukongim"
SESSION_FILE = SESSION_DIR / "session.json"


def get_flutter_shared_prefs_file() -> Path:
    """Resolve the Flutter desktop app shared preferences file."""
    appdata = Path(os.getenv("APPDATA", str(Path.home() / "AppData" / "Roaming")))
    return appdata / "com.im" / "wukong_im_app" / "shared_preferences.json"


class SessionManager:
    """Manages user session state and authentication tokens."""
    
    def __init__(self):
        self.session_dir = SESSION_DIR
        self.session_file = SESSION_FILE
        self._ensure_session_dir()
    
    def _ensure_session_dir(self):
        """Create session directory if it doesn't exist."""
        self.session_dir.mkdir(parents=True, exist_ok=True)
    
    def save_session(self, user_data: Dict[str, Any]):
        """Save session data to disk."""
        existing_session = self.load_session() or {}
        session_data = {
            "uid": user_data.get("uid"),
            "token": user_data.get("token"),
            "username": user_data.get("username"),
            "name": user_data.get("name"),
            "avatar": user_data.get("avatar"),
            "device_id": user_data.get("device_id") or existing_session.get("device_id"),
            "device_install_id": user_data.get("device_install_id") or existing_session.get("device_install_id"),
            "device_session_id": user_data.get("device_session_id") or existing_session.get("device_session_id"),
            "logged_in_at": datetime.now().isoformat(),
        }
        with open(self.session_file, "w", encoding="utf-8") as f:
            json.dump(session_data, f, indent=2, ensure_ascii=False)

    def _read_json_file(self, path: Path) -> Optional[Dict[str, Any]]:
        """Load JSON content from a file if it exists."""
        if not path.exists():
            return None
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (json.JSONDecodeError, IOError):
            return None
        return data if isinstance(data, dict) else None

    def _load_flutter_preferences(self) -> Dict[str, Any]:
        """Read auth/device data from the Flutter desktop app preferences."""
        prefs = self._read_json_file(get_flutter_shared_prefs_file()) or {}
        snapshot_raw = prefs.get("flutter.device_identity_snapshot")
        snapshot = {}
        if isinstance(snapshot_raw, str) and snapshot_raw.strip():
            try:
                decoded = json.loads(snapshot_raw)
                if isinstance(decoded, dict):
                    snapshot = decoded
            except json.JSONDecodeError:
                snapshot = {}

        return {
            "uid": prefs.get("flutter.wk_uid") or prefs.get("flutter.uid"),
            "token": prefs.get("flutter.wk_token") or prefs.get("flutter.token"),
            "username": prefs.get("flutter.wk_name"),
            "name": prefs.get("flutter.wk_name"),
            "device_id": snapshot.get("device_id") or prefs.get("flutter.device_id"),
            "device_install_id": snapshot.get("device_install_id"),
            "device_session_id": snapshot.get("device_session_id"),
        }

    @staticmethod
    def _merge_session_data(primary: Optional[Dict[str, Any]], fallback: Optional[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
        """Merge two session payloads, preferring primary values when present."""
        merged: Dict[str, Any] = {}
        for source in [fallback or {}, primary or {}]:
            for key, value in source.items():
                if value not in (None, ""):
                    merged[key] = value
        return merged or None

    def load_session(self) -> Optional[Dict[str, Any]]:
        """Load session data from disk."""
        saved_session = self._read_json_file(self.session_file)
        flutter_session = self._load_flutter_preferences()
        return self._merge_session_data(saved_session, flutter_session)
    
    def clear_session(self):
        """Clear saved session."""
        if self.session_file.exists():
            self.session_file.unlink()
    
    def get_token(self) -> Optional[str]:
        """Get current session token."""
        session = self.load_session()
        return session.get("token") if session else None
    
    def get_uid(self) -> Optional[str]:
        """Get current user ID."""
        session = self.load_session()
        return session.get("uid") if session else None

    def get_device_id(self) -> Optional[str]:
        """Get current device ID."""
        session = self.load_session()
        return session.get("device_id") if session else None

    def get_device_install_id(self) -> Optional[str]:
        """Get current device install ID."""
        session = self.load_session()
        return session.get("device_install_id") if session else None

    def get_device_session_id(self) -> Optional[str]:
        """Get current device session ID."""
        session = self.load_session()
        return session.get("device_session_id") if session else None


class WuKongIMClient:
    """HTTP client for WuKongIM API."""
    
    def __init__(self, session_manager: SessionManager):
        self.session = requests.Session()
        self.session_manager = session_manager
        self.session.headers.update({
            "Content-Type": "application/json",
            "Accept": "application/json",
        })
    
    def _get_auth_headers(
        self,
        data: Optional[Dict] = None,
        include_json_content_type: bool = True,
        require_auth: bool = True,
    ) -> Dict[str, str]:
        """Get signed request headers compatible with the Flutter app."""
        headers = build_signed_headers(
            data=data,
            token=self.session_manager.get_token() if require_auth else None,
            device_id=self.session_manager.get_device_id() if require_auth else None,
            device_session_id=self.session_manager.get_device_session_id() if require_auth else None,
            include_json_content_type=include_json_content_type,
        )
        return headers

    def _request(
        self,
        method: str,
        endpoint: str,
        data: Optional[Dict] = None,
        params: Optional[Dict] = None,
        require_auth: bool = True,
    ) -> Dict[str, Any]:
        """Make HTTP request to API."""
        url = f"{API_ENDPOINT}{endpoint}"
        headers = self._get_auth_headers(
            data=data if method in ["POST", "PUT", "PATCH", "DELETE"] else None,
            include_json_content_type=True,
            require_auth=require_auth,
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
    
    def get(self, endpoint: str, params: Optional[Dict] = None, require_auth: bool = True) -> Dict[str, Any]:
        return self._request("GET", endpoint, params=params, require_auth=require_auth)
    
    def post(self, endpoint: str, data: Optional[Dict] = None, require_auth: bool = True) -> Dict[str, Any]:
        return self._request("POST", endpoint, data=data, require_auth=require_auth)
    
    def put(self, endpoint: str, data: Optional[Dict] = None, require_auth: bool = True) -> Dict[str, Any]:
        return self._request("PUT", endpoint, data=data, require_auth=require_auth)
    
    def delete(self, endpoint: str, require_auth: bool = True) -> Dict[str, Any]:
        return self._request("DELETE", endpoint, require_auth=require_auth)


class APIError(Exception):
    """API error exception."""
    def __init__(self, message: str, code: int = 0):
        self.message = message
        self.code = code
        super().__init__(self.message)


def format_output(data: Any, as_json: bool = False) -> str:
    """Format output for display."""
    if as_json:
        return json.dumps(data, indent=2, ensure_ascii=False)
    
    if isinstance(data, dict):
        lines = []
        for key, value in data.items():
            if isinstance(value, (dict, list)):
                lines.append(f"{key}: {json.dumps(value, ensure_ascii=False)}")
            else:
                lines.append(f"{key}: {value}")
        return "\n".join(lines)
    elif isinstance(data, list):
        return "\n".join(json.dumps(item, ensure_ascii=False) for item in data)
    else:
        return str(data)


def extract_response_data(result: Any) -> Any:
    """Normalize API responses that may return either a body or a raw list."""
    if isinstance(result, dict):
        return result.get("data", result)
    return result


# ============================================================================
# AUTH COMMANDS
# ============================================================================

def cmd_login(args, client: WuKongIMClient, session: SessionManager):
    """Login with username and password."""
    payload = {
        "username": args.username,
        "password": args.password,
        "username_or_phone": args.username,
    }
    
    # Add device info
    import uuid
    device_id = hashlib.md5(f"{args.username}-{uuid.getnode()}".encode()).hexdigest()[:16]
    payload["device_id"] = device_id
    payload["device_name"] = args.device_name or "CLI"
    payload["device_model"] = args.device_model or "CLI-Client"
    payload["device_install_id"] = str(uuid.uuid4())
    
    result = client.post("/user/usernamelogin", data=payload, require_auth=False)
    
    # Extract user data
    user_data = extract_response_data(result)
    if isinstance(user_data, dict) and "token" in user_data:
        session_payload = dict(user_data)
        session_payload.setdefault("device_id", payload["device_id"])
        session_payload.setdefault("device_install_id", payload["device_install_id"])
        session.save_session(session_payload)
        print(f"✓ Logged in as {user_data.get('name', args.username)} (UID: {user_data.get('uid')})")
        if args.json:
            print(format_output(user_data, as_json=True))
    else:
        print(f"✓ Login successful")
        if args.json:
            print(format_output(result, as_json=True))


def cmd_logout(args, client: WuKongIMClient, session: SessionManager):
    """Logout and clear session."""
    session.clear_session()
    print("✓ Logged out")


def cmd_register(args, client: WuKongIMClient, session: SessionManager):
    """Register a new user account."""
    payload = {
        "username": args.username,
        "password": args.password,
        "verify_code": args.verify_code or "",
        "name": args.name or args.username,
    }
    
    result = client.post("/user/register", data=payload, require_auth=False)
    print(f"✓ Registration successful")
    if args.json:
        print(format_output(result, as_json=True))


def cmd_me(args, client: WuKongIMClient, session: SessionManager):
    """Get current user info."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in. Use 'login' command first.")
        return
    
    result = client.get(f"/users/{uid}")
    user_data = result.get("data", result)
    
    if args.json:
        print(format_output(user_data, as_json=True))
    else:
        print(f"UID: {user_data.get('uid')}")
        print(f"Name: {user_data.get('name')}")
        print(f"Username: {user_data.get('username')}")
        print(f"Avatar: {user_data.get('avatar', 'Not set')}")
        print(f"Gender: {'Male' if user_data.get('sex') == 1 else 'Female' if user_data.get('sex') == 2 else 'Not set'}")
        print(f"Phone: {user_data.get('phone', 'Not set')}")


def cmd_update_profile(args, client: WuKongIMClient, session: SessionManager):
    """Update current user profile."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    payload = {}
    if args.name:
        payload["name"] = args.name
    if args.avatar:
        payload["avatar"] = args.avatar
    if args.gender is not None:
        payload["sex"] = args.gender
    if args.phone:
        payload["phone"] = args.phone
    
    if not payload:
        print("Error: No fields to update. Specify --name, --avatar, --gender, or --phone.")
        return
    
    result = client.put(f"/user/{uid}", data=payload)
    print(f"✓ Profile updated")
    if args.json:
        print(format_output(result, as_json=True))


# ============================================================================
# CONVERSATION COMMANDS
# ============================================================================

def cmd_conversations(args, client: WuKongIMClient, session: SessionManager):
    """List conversations."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    params = {}
    if args.limit:
        params["limit"] = args.limit
    if args.offset:
        params["offset"] = args.offset
    
    result = client.get("/conversations", params=params)
    conversations = extract_response_data(result)
    
    if args.json:
        print(format_output(conversations, as_json=True))
    else:
        if isinstance(conversations, list):
            for conv in conversations:
                cid = conv.get("channel_id", conv.get("id", "N/A"))
                ctype = conv.get("channel_type", 1)
                name = conv.get("name", conv.get("label", "Unknown"))
                last_msg = conv.get("last_msg", "")
                unread = conv.get("unread", 0)
                print(f"[{ctype}] {name} ({cid}) - Unread: {unread}")
                if last_msg:
                    print(f"    Last: {last_msg}")
        else:
            print(format_output(conversations))


# ============================================================================
# MESSAGE COMMANDS
# ============================================================================

def cmd_send_message(args, client: WuKongIMClient, session: SessionManager):
    """Send a message."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    # Channel type: 1 = personal, 2 = group
    channel_type = 2 if args.group else 1
    channel_id = args.target
    
    payload = {
        "channel_id": channel_id,
        "channel_type": channel_type,
        "content": args.content,
        "content_type": 1,  # 1 = text
    }
    
    result = client.post("/message/send", data=payload)
    msg_id = result.get("data", {}).get("message_id", "N/A")
    print(f"✓ Message sent (ID: {msg_id})")
    if args.json:
        print(format_output(result, as_json=True))


def cmd_sync_messages(args, client: WuKongIMClient, session: SessionManager):
    """Sync messages for a conversation."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    channel_type = 2 if args.group else 1
    
    payload = {
        "channel_id": args.channel_id,
        "channel_type": channel_type,
        "limit": args.limit or 20,
    }
    
    if args.start_message_id:
        payload["start_message_id"] = args.start_message_id
    
    result = client.post("/message/sync", data=payload)
    messages = extract_response_data(result)
    
    if args.json:
        print(format_output(messages, as_json=True))
    else:
        if isinstance(messages, list):
            for msg in messages:
                msg_id = msg.get("message_id", "N/A")
                from_uid = msg.get("from_uid", "N/A")
                content = msg.get("content", "")
                created = msg.get("created_at", 0)
                timestamp = datetime.fromtimestamp(created).strftime("%Y-%m-%d %H:%M:%S") if created else "N/A"
                print(f"[{timestamp}] {from_uid}: {content}")
        else:
            print(format_output(messages))


def cmd_search_messages(args, client: WuKongIMClient, session: SessionManager):
    """Search messages."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    payload = {
        "keyword": args.keyword,
        "channel_id": args.channel_id or "",
        "channel_type": 2 if args.group else 1 if args.channel_id else 0,
        "limit": args.limit or 20,
    }
    
    result = client.post("/message/search", data=payload)
    messages = extract_response_data(result)
    
    if args.json:
        print(format_output(messages, as_json=True))
    else:
        if isinstance(messages, list):
            for msg in messages:
                msg_id = msg.get("message_id", "N/A")
                content = msg.get("content", "")
                created = msg.get("created_at", 0)
                timestamp = datetime.fromtimestamp(created).strftime("%Y-%m-%d %H:%M:%S") if created else "N/A"
                print(f"[{timestamp}] {content}")
        else:
            print(format_output(messages))


def cmd_revoke_message(args, client: WuKongIMClient, session: SessionManager):
    """Revoke (delete) a message."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    payload = {
        "message_id": args.message_id,
        "channel_id": args.channel_id,
        "channel_type": 2 if args.group else 1,
    }
    
    result = client.post("/message/revoke", data=payload)
    print(f"✓ Message revoked")
    if args.json:
        print(format_output(result, as_json=True))


# ============================================================================
# FRIEND COMMANDS
# ============================================================================

def cmd_friends(args, client: WuKongIMClient, session: SessionManager):
    """List friends."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    result = client.get(
        "/friend/sync",
        params={"api_version": 1, "limit": 1000, "version": 0},
    )
    friends = extract_response_data(result)
    
    if args.json:
        print(format_output(friends, as_json=True))
    else:
        if isinstance(friends, list):
            for friend in friends:
                fuid = friend.get("uid", friend.get("friend_uid", "N/A"))
                name = friend.get("name", friend.get("remark", "Unknown"))
                avatar = friend.get("avatar", "")
                print(f"{fuid}: {name}")
        else:
            print(format_output(friends))


def cmd_add_friend(args, client: WuKongIMClient, session: SessionManager):
    """Add a friend."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    payload = {
        "to_uid": args.friend_uid,
        "remark": args.remark or "",
    }
    
    result = client.post("/friend/apply", data=payload)
    print(f"✓ Friend request sent to {args.friend_uid}")
    if args.json:
        print(format_output(result, as_json=True))


def cmd_remove_friend(args, client: WuKongIMClient, session: SessionManager):
    """Remove a friend."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    result = client.delete(f"/friend/sync/{args.friend_uid}")
    print(f"✓ Friend removed")
    if args.json:
        print(format_output(result, as_json=True))


# ============================================================================
# GROUP COMMANDS
# ============================================================================

def cmd_groups(args, client: WuKongIMClient, session: SessionManager):
    """List my groups."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    result = client.get("/group/my")
    groups = extract_response_data(result)
    
    if args.json:
        print(format_output(groups, as_json=True))
    else:
        if isinstance(groups, list):
            for group in groups:
                gid = group.get("group_no", group.get("group_id", group.get("id", "N/A")))
                name = group.get("name", group.get("group_name", "Unknown"))
                member_count = group.get("member_count", 0)
                print(f"{gid}: {name} ({member_count} members)")
        else:
            print(format_output(groups))


def cmd_create_group(args, client: WuKongIMClient, session: SessionManager):
    """Create a new group."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    # Parse member UIDs
    members = [m.strip() for m in args.members.split(",") if m.strip()]
    if not members:
        print("Error: At least one member UID required.")
        return
    
    payload = {
        "name": args.name,
        "members": members,
    }
    
    result = client.post("/group/create", data=payload)
    group_id = result.get("data", {}).get("group_id", "N/A")
    print(f"✓ Group created (ID: {group_id})")
    if args.json:
        print(format_output(result, as_json=True))


def cmd_group_info(args, client: WuKongIMClient, session: SessionManager):
    """Get group info."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    result = client.get(f"/groups/{args.group_id}")
    group_info = extract_response_data(result)
    
    if args.json:
        print(format_output(group_info, as_json=True))
    else:
        print(f"Group ID: {group_info.get('group_no', group_info.get('group_id', args.group_id))}")
        print(f"Name: {group_info.get('name', group_info.get('group_name', 'N/A'))}")
        print(f"Members: {group_info.get('member_count', 0)}")
        print(f"Creator: {group_info.get('creator', 'N/A')}")


# ============================================================================
# FILE COMMANDS
# ============================================================================

def cmd_upload_file(args, client: WuKongIMClient, session: SessionManager):
    """Upload a file."""
    uid = session.get_uid()
    if not uid:
        print("Error: Not logged in.")
        return
    
    file_path = Path(args.file)
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        return
    
    files = {"file": open(file_path, "rb")}
    url = f"{API_ENDPOINT}/file/upload"
    headers = client._get_auth_headers(include_json_content_type=False)
    
    try:
        response = requests.post(url, files=files, headers=headers, timeout=60)
        result = response.json() if response.content else {}
        
        code = result.get("code", 0)
        if isinstance(code, str):
            code = int(code) if code.isdigit() else 0
        
        if response.status_code >= 400 or (code and code != 0):
            error_msg = result.get("msg") or result.get("message") or f"HTTP {response.status_code}"
            raise APIError(error_msg, code)
        
        file_url = result.get("data", {}).get("url", "N/A")
        print(f"✓ File uploaded: {file_url}")
        if args.json:
            print(format_output(result, as_json=True))
    finally:
        files["file"].close()


# ============================================================================
# MAIN CLI
# ============================================================================

def create_parser() -> argparse.ArgumentParser:
    """Create argument parser with all commands."""
    parser = argparse.ArgumentParser(
        prog="wukongim",
        description="WuKongIM CLI - Command-line interface for WuKongIM messaging platform",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s login -u myuser -p mypassword
  %(prog)s me
  %(prog)s conversations
  %(prog)s send -t friend_uid "Hello!"
  %(prog)s send -g group_id "Group message"
  %(prog)s friends
  %(prog)s groups
  %(prog)s upload /path/to/file.pdf
        """
    )
    
    parser.add_argument("--json", action="store_true", help="Output in JSON format")
    
    subparsers = parser.add_subparsers(dest="command", help="Available commands")
    
    # Auth commands
    auth_parser = subparsers.add_parser("auth", help="Authentication commands")
    auth_subparsers = auth_parser.add_subparsers(dest="auth_command")
    
    # login
    login_p = auth_subparsers.add_parser("login", help="Login with username/password")
    login_p.add_argument("-u", "--username", required=True, help="Username or phone")
    login_p.add_argument("-p", "--password", required=True, help="Password")
    login_p.add_argument("--device-name", help="Device name (default: CLI)")
    login_p.add_argument("--device-model", help="Device model (default: CLI-Client)")
    login_p.set_defaults(func=cmd_login)
    
    # logout
    logout_p = auth_subparsers.add_parser("logout", help="Logout")
    logout_p.set_defaults(func=cmd_logout)
    
    # register
    register_p = auth_subparsers.add_parser("register", help="Register new account")
    register_p.add_argument("-u", "--username", required=True, help="Username")
    register_p.add_argument("-p", "--password", required=True, help="Password")
    register_p.add_argument("-n", "--name", help="Display name")
    register_p.add_argument("--verify-code", help="Verification code")
    register_p.set_defaults(func=cmd_register)
    
    # me
    me_p = auth_subparsers.add_parser("me", help="Get current user info")
    me_p.set_defaults(func=cmd_me)
    
    # update-profile
    profile_p = auth_subparsers.add_parser("update-profile", help="Update profile")
    profile_p.add_argument("--name", help="New name")
    profile_p.add_argument("--avatar", help="Avatar URL")
    profile_p.add_argument("--gender", type=int, choices=[1, 2], help="Gender (1=Male, 2=Female)")
    profile_p.add_argument("--phone", help="Phone number")
    profile_p.set_defaults(func=cmd_update_profile)
    
    # Conversations
    conv_p = subparsers.add_parser("conversations", help="List conversations")
    conv_p.add_argument("--limit", type=int, default=20, help="Number of conversations")
    conv_p.add_argument("--offset", type=int, default=0, help="Offset")
    conv_p.set_defaults(func=cmd_conversations)
    
    # Messages
    msg_parser = subparsers.add_parser("message", help="Message commands")
    msg_subparsers = msg_parser.add_subparsers(dest="message_command")
    
    # send
    send_p = msg_subparsers.add_parser("send", help="Send a message")
    send_p.add_argument("-t", "--target", required=True, help="Target UID or group ID")
    send_p.add_argument("-c", "--content", required=True, help="Message content")
    send_p.add_argument("-g", "--group", action="store_true", help="Send to group")
    send_p.set_defaults(func=cmd_send_message)
    
    # sync
    sync_p = msg_subparsers.add_parser("sync", help="Sync messages")
    sync_p.add_argument("--channel-id", required=True, help="Channel ID")
    sync_p.add_argument("--group", action="store_true", help="Group channel")
    sync_p.add_argument("--limit", type=int, default=20, help="Message limit")
    sync_p.add_argument("--start-message-id", help="Start from message ID")
    sync_p.set_defaults(func=cmd_sync_messages)
    
    # search
    search_p = msg_subparsers.add_parser("search", help="Search messages")
    search_p.add_argument("-k", "--keyword", required=True, help="Search keyword")
    search_p.add_argument("--channel-id", help="Limit to channel")
    search_p.add_argument("--group", action="store_true", help="Search in group")
    search_p.add_argument("--limit", type=int, default=20, help="Result limit")
    search_p.set_defaults(func=cmd_search_messages)
    
    # revoke
    revoke_p = msg_subparsers.add_parser("revoke", help="Revoke a message")
    revoke_p.add_argument("--message-id", required=True, help="Message ID")
    revoke_p.add_argument("--channel-id", required=True, help="Channel ID")
    revoke_p.add_argument("--group", action="store_true", help="Group channel")
    revoke_p.set_defaults(func=cmd_revoke_message)
    
    # Friends
    friend_parser = subparsers.add_parser("friend", help="Friend commands")
    friend_subparsers = friend_parser.add_subparsers(dest="friend_command")
    
    # list
    friends_p = friend_subparsers.add_parser("list", help="List friends")
    friends_p.set_defaults(func=cmd_friends)
    
    # add
    add_p = friend_subparsers.add_parser("add", help="Add a friend")
    add_p.add_argument("--friend-uid", required=True, help="Friend's UID")
    add_p.add_argument("--remark", help="Remark/note")
    add_p.set_defaults(func=cmd_add_friend)
    
    # remove
    remove_p = friend_subparsers.add_parser("remove", help="Remove a friend")
    remove_p.add_argument("--friend-uid", required=True, help="Friend's UID")
    remove_p.set_defaults(func=cmd_remove_friend)
    
    # Groups
    group_parser = subparsers.add_parser("group", help="Group commands")
    group_subparsers = group_parser.add_subparsers(dest="group_command")
    
    # list
    groups_p = group_subparsers.add_parser("list", help="List my groups")
    groups_p.set_defaults(func=cmd_groups)
    
    # create
    create_p = group_subparsers.add_parser("create", help="Create a group")
    create_p.add_argument("-n", "--name", required=True, help="Group name")
    create_p.add_argument("-m", "--members", required=True, help="Member UIDs (comma-separated)")
    create_p.set_defaults(func=cmd_create_group)
    
    # info
    info_p = group_subparsers.add_parser("info", help="Get group info")
    info_p.add_argument("--group-id", required=True, help="Group ID")
    info_p.set_defaults(func=cmd_group_info)
    
    # File upload
    upload_p = subparsers.add_parser("upload", help="Upload a file")
    upload_p.add_argument("file", help="File path to upload")
    upload_p.set_defaults(func=cmd_upload_file)
    
    return parser


def main():
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    # Handle nested subcommands
    if args.command == "auth" and not getattr(args, "auth_command", None):
        parser.parse_args(["auth", "--help"])
        return
    
    if args.command == "message" and not getattr(args, "message_command", None):
        parser.parse_args(["message", "--help"])
        return
    
    if args.command == "friend" and not getattr(args, "friend_command", None):
        parser.parse_args(["friend", "--help"])
        return
    
    if args.command == "group" and not getattr(args, "group_command", None):
        parser.parse_args(["group", "--help"])
        return
    
    # Initialize session and client
    session_manager = SessionManager()
    client = WuKongIMClient(session_manager)
    
    # Attach json flag to all commands
    if not hasattr(args, 'json'):
        args.json = parser.parse_args().json
    
    try:
        args.func(args, client, session_manager)
    except APIError as e:
        print(f"Error: {e.message}")
        if args.json:
            print(json.dumps({"error": e.message, "code": e.code}, indent=2))
        sys.exit(1)
    except Exception as e:
        print(f"Error: {str(e)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
