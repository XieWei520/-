#!/usr/bin/env python3
"""
Unit tests for WuKongIM CLI session management and command contracts.
"""

import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent))

import wukongim_cli as cli


class LoggedInSession:
    def get_uid(self):
        return "user-1"

    def get_token(self):
        return "token-1"

    def get_device_id(self):
        return "device-1"

    def get_device_session_id(self):
        return "session-1"


class RecordingClient:
    def __init__(self, response=None):
        self.response = response if response is not None else {"data": {}}
        self.calls = []

    def get(self, endpoint, params=None, require_auth=True):
        self.calls.append(("get", endpoint, params, require_auth))
        return self.response

    def post(self, endpoint, data=None, require_auth=True):
        self.calls.append(("post", endpoint, data, require_auth))
        return self.response

    def put(self, endpoint, data=None, require_auth=True):
        self.calls.append(("put", endpoint, data, require_auth))
        return self.response

    def delete(self, endpoint, require_auth=True):
        self.calls.append(("delete", endpoint, None, require_auth))
        return self.response


def test_save_session_persists_device_identity(tmp_path, monkeypatch):
    """Session files should keep device identity needed for signed requests."""
    session_dir = tmp_path / ".wukongim"
    session_file = session_dir / "session.json"
    monkeypatch.setattr(cli, "SESSION_DIR", session_dir)
    monkeypatch.setattr(cli, "SESSION_FILE", session_file)

    manager = cli.SessionManager()
    manager.save_session(
        {
            "uid": "user-1",
            "token": "token-1",
            "username": "tester",
            "name": "Tester",
            "device_id": "device-1",
            "device_install_id": "install-1",
            "device_session_id": "session-1",
        }
    )

    saved = json.loads(session_file.read_text(encoding="utf-8"))
    assert saved["device_id"] == "device-1"
    assert saved["device_install_id"] == "install-1"
    assert saved["device_session_id"] == "session-1"


def test_load_session_merges_flutter_shared_preferences(tmp_path, monkeypatch):
    """CLI sessions should fall back to Flutter shared preferences for missing device fields."""
    session_dir = tmp_path / ".wukongim"
    session_dir.mkdir(parents=True, exist_ok=True)
    session_file = session_dir / "session.json"
    session_file.write_text(
        json.dumps(
            {
                "uid": "user-1",
                "token": "token-1",
                "username": "tester",
                "name": "Tester",
            }
        ),
        encoding="utf-8",
    )

    appdata = tmp_path / "AppData" / "Roaming"
    prefs_dir = appdata / "com.im" / "wukong_im_app"
    prefs_dir.mkdir(parents=True, exist_ok=True)
    prefs_file = prefs_dir / "shared_preferences.json"
    prefs_file.write_text(
        json.dumps(
            {
                "flutter.wk_uid": "user-1",
                "flutter.wk_token": "token-1",
                "flutter.wk_name": "Tester",
                "flutter.device_identity_snapshot": json.dumps(
                    {
                        "device_id": "device-1",
                        "device_install_id": "install-1",
                        "device_session_id": "session-1",
                    }
                ),
            }
        ),
        encoding="utf-8",
    )

    monkeypatch.setattr(cli, "SESSION_DIR", session_dir)
    monkeypatch.setattr(cli, "SESSION_FILE", session_file)
    monkeypatch.setenv("APPDATA", str(appdata))

    manager = cli.SessionManager()
    loaded = manager.load_session()

    assert loaded["uid"] == "user-1"
    assert loaded["token"] == "token-1"
    assert loaded["device_id"] == "device-1"
    assert loaded["device_install_id"] == "install-1"
    assert loaded["device_session_id"] == "session-1"


def test_client_auth_headers_follow_flutter_contract(tmp_path, monkeypatch):
    """CLI client should send signed headers instead of Bearer auth."""
    session_dir = tmp_path / ".wukongim"
    session_dir.mkdir(parents=True, exist_ok=True)
    session_file = session_dir / "session.json"
    session_file.write_text(
        json.dumps(
            {
                "uid": "user-1",
                "token": "token-1",
                "device_id": "device-1",
                "device_session_id": "session-1",
            }
        ),
        encoding="utf-8",
    )

    monkeypatch.setattr(cli, "SESSION_DIR", session_dir)
    monkeypatch.setattr(cli, "SESSION_FILE", session_file)

    manager = cli.SessionManager()
    client = cli.WuKongIMClient(manager)
    headers = client._get_auth_headers()

    assert headers["appid"] == "wukongchat"
    assert headers["token"] == "token-1"
    assert headers["X-Device-ID"] == "device-1"
    assert headers["X-Device-Session-ID"] == "session-1"
    assert len(headers["sign"]) == 32
    assert headers["timestamp"].isdigit()
    assert len(headers["noncestr"]) == 16
    assert "Authorization" not in headers


def test_client_request_accepts_list_response(monkeypatch):
    """Client requests should accept endpoints that return a raw list body."""
    client = cli.WuKongIMClient(LoggedInSession())

    class DummyResponse:
        status_code = 200
        content = b'[{"uid":"friend-1"}]'

        @staticmethod
        def json():
            return [{"uid": "friend-1"}]

    monkeypatch.setattr(client.session, "request", lambda *args, **kwargs: DummyResponse())

    result = client.get("/friend/sync", params={"api_version": 1, "limit": 1000, "version": 0})

    assert result == [{"uid": "friend-1"}]


def test_client_request_surfaces_http_status_for_non_json_error(monkeypatch):
    """Client requests should expose HTTP status for non-JSON error responses."""
    client = cli.WuKongIMClient(LoggedInSession())

    class DummyResponse:
        status_code = 404
        content = b"not-json"

        @staticmethod
        def json():
            raise ValueError("invalid json")

    monkeypatch.setattr(client.session, "request", lambda *args, **kwargs: DummyResponse())

    with pytest.raises(cli.APIError, match="HTTP 404"):
        client.get("/conversations", params={"limit": 5, "offset": 0})


def test_cmd_friends_uses_sync_query_contract(capsys):
    """Friend listing should use the production sync query contract."""
    client = RecordingClient(response={"data": [{"uid": "friend-1", "name": "Buddy"}]})

    cli.cmd_friends(SimpleNamespace(json=False), client, LoggedInSession())

    assert client.calls == [
        (
            "get",
            "/friend/sync",
            {"api_version": 1, "limit": 1000, "version": 0},
            True,
        )
    ]
    assert "friend-1: Buddy" in capsys.readouterr().out


def test_cmd_friends_json_accepts_list_payload(capsys):
    """Friend listing JSON output should handle list responses from the backend."""
    client = RecordingClient(response=[{"uid": "friend-1", "name": "Buddy"}])

    cli.cmd_friends(SimpleNamespace(json=True), client, LoggedInSession())

    output = capsys.readouterr().out
    assert '"uid": "friend-1"' in output


def test_cmd_add_friend_uses_to_uid_payload():
    """Friend requests should use the backend's to_uid payload."""
    client = RecordingClient()

    cli.cmd_add_friend(
        SimpleNamespace(friend_uid="friend-1", remark="hello", json=False),
        client,
        LoggedInSession(),
    )

    assert client.calls == [
        ("post", "/friend/apply", {"to_uid": "friend-1", "remark": "hello"}, True)
    ]


def test_cmd_remove_friend_uses_sync_endpoint():
    """Friend deletion should target the sync endpoint used by the app."""
    client = RecordingClient()

    cli.cmd_remove_friend(
        SimpleNamespace(friend_uid="friend-1", json=False),
        client,
        LoggedInSession(),
    )

    assert client.calls == [("delete", "/friend/sync/friend-1", None, True)]


def test_cmd_groups_displays_group_no(capsys):
    """Group list output should use the backend's group_no field."""
    client = RecordingClient(
        response={"data": [{"group_no": "group-1", "name": "Team Alpha", "member_count": 2}]}
    )

    cli.cmd_groups(SimpleNamespace(json=False), client, LoggedInSession())

    assert client.calls == [("get", "/group/my", None, True)]
    assert "group-1: Team Alpha (2 members)" in capsys.readouterr().out


def test_cmd_groups_json_accepts_list_payload(capsys):
    """Group listing JSON output should handle list responses from the backend."""
    client = RecordingClient(response=[{"group_no": "group-1", "name": "Team Alpha"}])

    cli.cmd_groups(SimpleNamespace(json=True), client, LoggedInSession())

    output = capsys.readouterr().out
    assert '"group_no": "group-1"' in output


def test_cmd_group_info_uses_groups_endpoint_and_fields(capsys):
    """Group info should use /groups/{group_no} and display production field names."""
    client = RecordingClient(
        response={
            "data": {
                "group_no": "group-1",
                "name": "Team Alpha",
                "member_count": 2,
                "creator": "owner-1",
            }
        }
    )

    cli.cmd_group_info(
        SimpleNamespace(group_id="group-1", json=False),
        client,
        LoggedInSession(),
    )

    assert client.calls == [("get", "/groups/group-1", None, True)]
    output = capsys.readouterr().out
    assert "Group ID: group-1" in output
    assert "Name: Team Alpha" in output
    assert "Members: 2" in output
    assert "Creator: owner-1" in output
