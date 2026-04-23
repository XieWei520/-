#!/usr/bin/env python3
"""
Unit tests for WuKongIM backend wrapper.

Run with: pytest tests/test_backend.py -v
"""

import hashlib
import json
import os
import sys
from pathlib import Path

import pytest

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from utils.backend import APIError, WuKongIMBackend


class DummyResponse:
    def __init__(self, payload=None, status_code=200):
        self._payload = payload if payload is not None else {"code": 0, "data": {}}
        self.status_code = status_code
        self.content = json.dumps(self._payload).encode("utf-8")

    def json(self):
        return self._payload


class DummyListResponse(DummyResponse):
    def __init__(self, payload=None, status_code=200):
        self._payload = payload if payload is not None else []
        self.status_code = status_code
        self.content = json.dumps(self._payload).encode("utf-8")


class DummyInvalidJsonResponse:
    def __init__(self, status_code=404, body=b"not-json"):
        self.status_code = status_code
        self.content = body

    def json(self):
        raise ValueError("invalid json")


class TestWuKongIMBackend:
    """Test cases for WuKongIMBackend class."""

    @pytest.fixture
    def backend(self):
        """Create backend instance for testing."""
        return WuKongIMBackend()

    def test_init_default_url(self, backend):
        """Test backend initializes with default URL."""
        assert backend.base_url == "http://42.194.218.158"
        assert backend.api_endpoint == "http://42.194.218.158/v1"

    def test_init_custom_url(self):
        """Test backend initializes with custom URL."""
        backend = WuKongIMBackend(base_url="http://test.example.com")
        assert backend.base_url == "http://test.example.com"
        assert backend.api_endpoint == "http://test.example.com/v1"

    def test_init_from_env(self, monkeypatch):
        """Test backend reads URL from environment."""
        monkeypatch.setenv("WK_API_URL", "http://env.example.com")
        backend = WuKongIMBackend()
        assert backend.base_url == "http://env.example.com"

    def test_set_token_uses_wukong_header(self, backend):
        """Test setting authentication token uses the backend's token header."""
        backend.set_token("test_token")
        assert backend.token == "test_token"
        assert backend.session.headers["token"] == "test_token"
        assert "Authorization" not in backend.session.headers

    def test_clear_token_removes_wukong_header(self, backend):
        """Test clearing authentication token removes token header."""
        backend.set_token("test_token")
        backend.clear_token()
        assert backend.token is None
        assert "token" not in backend.session.headers

    def test_build_signed_headers_matches_flutter_contract(self):
        """Test signing logic matches the Flutter app's header contract."""
        from utils.auth import build_signed_headers

        body = {"to_uid": "friend-1", "remark": "hello"}
        headers = build_signed_headers(
            data=body,
            token="test_token",
            device_id="device-1",
            device_session_id="session-1",
            timestamp_ms=1700000000123,
            nonce="ABCDEF1234567890",
        )

        encoded_body = json.dumps(body, ensure_ascii=False, separators=(",", ":"))
        expected_sign = hashlib.md5(
            f"{encoded_body}ABCDEF1234567890170000000012325b002c6be2d539f264c".encode("utf-8")
        ).hexdigest()

        assert headers["appid"] == "wukongchat"
        assert headers["timestamp"] == "1700000000123"
        assert headers["noncestr"] == "ABCDEF1234567890"
        assert headers["sign"] == expected_sign
        assert headers["token"] == "test_token"
        assert headers["X-Device-ID"] == "device-1"
        assert headers["X-Device-Session-ID"] == "session-1"
        assert headers["Content-Type"] == "application/json"
        assert "Authorization" not in headers

    def test_request_includes_signed_headers(self, monkeypatch):
        """Test backend requests send signed auth headers instead of Bearer auth."""
        backend = WuKongIMBackend(
            token="test_token",
            device_id="device-1",
            device_session_id="session-1",
            timestamp_ms_factory=lambda: 1700000000123,
            nonce_factory=lambda length: "ABCDEF1234567890",
        )
        captured = {}

        def fake_request(method, url, json=None, params=None, timeout=None, headers=None):
            captured["method"] = method
            captured["url"] = url
            captured["json"] = json
            captured["params"] = params
            captured["headers"] = headers or {}
            return DummyResponse()

        monkeypatch.setattr(backend.session, "request", fake_request)

        backend._request("GET", "/group/my")

        assert captured["method"] == "GET"
        assert captured["url"] == "http://42.194.218.158/v1/group/my"
        assert captured["headers"]["appid"] == "wukongchat"
        assert captured["headers"]["token"] == "test_token"
        assert captured["headers"]["X-Device-ID"] == "device-1"
        assert captured["headers"]["X-Device-Session-ID"] == "session-1"
        assert "Authorization" not in captured["headers"]

    def test_request_accepts_list_response(self, monkeypatch):
        """Test backend request handling supports endpoints that return raw lists."""
        backend = WuKongIMBackend(token="test_token")

        def fake_request(method, url, json=None, params=None, timeout=None, headers=None):
            return DummyListResponse([{"uid": "friend-1"}])

        monkeypatch.setattr(backend.session, "request", fake_request)

        result = backend._request("GET", "/friend/sync")

        assert result == [{"uid": "friend-1"}]

    def test_request_accepts_list_responses(self, monkeypatch):
        """Test backend requests accept endpoints that return a raw list body."""
        backend = WuKongIMBackend()

        def fake_request(method, url, json=None, params=None, timeout=None, headers=None):
            return DummyResponse(payload=[{"uid": "friend-1"}])

        monkeypatch.setattr(backend.session, "request", fake_request)

        result = backend._request("GET", "/friend/sync")

        assert result == [{"uid": "friend-1"}]

    def test_request_surfaces_http_status_for_non_json_error(self, monkeypatch):
        """Test backend reports HTTP status when an error response is not JSON."""
        backend = WuKongIMBackend()

        monkeypatch.setattr(
            backend.session,
            "request",
            lambda *args, **kwargs: DummyInvalidJsonResponse(status_code=404),
        )

        with pytest.raises(APIError, match="HTTP 404"):
            backend._request("GET", "/conversations")

    def test_sync_friends_uses_server_sync_contract(self, backend, monkeypatch):
        """Test friends sync uses the backend's required query contract."""
        captured = {}

        def fake_request(method, endpoint, data=None, params=None, require_auth=True):
            captured["method"] = method
            captured["endpoint"] = endpoint
            captured["data"] = data
            captured["params"] = params
            captured["require_auth"] = require_auth
            return {"code": 0, "data": []}

        monkeypatch.setattr(backend, "_request", fake_request)

        backend.sync_friends()

        assert captured == {
            "method": "GET",
            "endpoint": "/friend/sync",
            "data": None,
            "params": {"api_version": 1, "limit": 1000, "version": 0},
            "require_auth": True,
        }

    def test_apply_friend_uses_to_uid_payload(self, backend, monkeypatch):
        """Test friend requests use the server's to_uid field."""
        captured = {}

        def fake_request(method, endpoint, data=None, params=None, require_auth=True):
            captured["method"] = method
            captured["endpoint"] = endpoint
            captured["data"] = data
            return {"code": 0, "data": {}}

        monkeypatch.setattr(backend, "_request", fake_request)

        backend.apply_friend("friend-1", remark="hello")

        assert captured["method"] == "POST"
        assert captured["endpoint"] == "/friend/apply"
        assert captured["data"] == {"to_uid": "friend-1", "remark": "hello"}

    def test_remove_friend_uses_sync_delete_endpoint(self, backend, monkeypatch):
        """Test friend deletion uses the sync endpoint contract."""
        captured = {}

        def fake_request(method, endpoint, data=None, params=None, require_auth=True):
            captured["method"] = method
            captured["endpoint"] = endpoint
            return {"code": 0, "data": {}}

        monkeypatch.setattr(backend, "_request", fake_request)

        backend.remove_friend("friend-1")

        assert captured["method"] == "DELETE"
        assert captured["endpoint"] == "/friend/sync/friend-1"

    def test_get_group_info_uses_groups_collection(self, backend, monkeypatch):
        """Test group info uses the server's /groups/{group_no} endpoint."""
        captured = {}

        def fake_request(method, endpoint, data=None, params=None, require_auth=True):
            captured["method"] = method
            captured["endpoint"] = endpoint
            return {"code": 0, "data": {}}

        monkeypatch.setattr(backend, "_request", fake_request)

        backend.get_group_info("group-1")

        assert captured["method"] == "GET"
        assert captured["endpoint"] == "/groups/group-1"

    def test_api_error_with_code(self):
        """Test APIError with error code."""
        error = APIError("Test error", 404)
        assert str(error) == "[404] Test error"
        assert error.code == 404
        assert error.message == "Test error"

    def test_api_error_without_code(self):
        """Test APIError without error code."""
        error = APIError("Test error")
        assert str(error) == "Test error"
        assert error.code == 0
        assert error.message == "Test error"


class TestBackendEndpoints:
    """Integration tests for backend endpoints (requires valid credentials)."""

    @pytest.fixture
    def authenticated_backend(self):
        """Create authenticated backend instance."""
        username = os.getenv("WK_TEST_USERNAME")
        password = os.getenv("WK_TEST_PASSWORD")

        if not username or not password:
            pytest.skip("WK_TEST_USERNAME and WK_TEST_PASSWORD required")

        backend = WuKongIMBackend()
        result = backend.login(username, password)
        token = result.get("data", {}).get("token")
        if token:
            backend.set_token(token)
        return backend

    @pytest.mark.skip(reason="Requires valid test credentials")
    def test_get_user_info(self, authenticated_backend):
        """Test getting user info."""
        pass

    @pytest.mark.skip(reason="Requires valid test credentials")
    def test_get_conversations(self, authenticated_backend):
        """Test listing conversations."""
        result = authenticated_backend.get_conversations(limit=5)
        assert "data" in result or isinstance(result, list)

    @pytest.mark.skip(reason="Requires valid test credentials")
    def test_sync_friends(self, authenticated_backend):
        """Test syncing friends."""
        result = authenticated_backend.sync_friends()
        assert "data" in result or isinstance(result, list)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
