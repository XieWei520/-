#!/usr/bin/env python3
"""
WuKongIM CLI smoke tests.

Supports either:
1. username/password login flow, or
2. an already-seeded local session token.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Optional, Tuple

# CLI script path
CLI_SCRIPT = Path(__file__).parent / "wukongim_cli.py"

# Test configuration
TEST_USERNAME = os.getenv("WK_TEST_USERNAME")
TEST_PASSWORD = os.getenv("WK_TEST_PASSWORD")


def _normalize_args(args: Tuple[str, ...]) -> list[str]:
    """Move global flags like --json before the subcommand."""
    json_flags = [arg for arg in args if arg == "--json"]
    other_args = [arg for arg in args if arg != "--json"]
    return [*json_flags, *other_args]


def run_cli(*args, check: bool = True) -> subprocess.CompletedProcess[str]:
    """Run the CLI command and return the completed process."""
    cmd = [sys.executable, str(CLI_SCRIPT), *_normalize_args(tuple(args))]
    return subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )


def command_output(result: subprocess.CompletedProcess[str]) -> str:
    """Collapse stdout/stderr into a single message."""
    stdout = (result.stdout or "").strip()
    stderr = (result.stderr or "").strip()
    if stdout and stderr:
        return f"{stdout}\n{stderr}"
    return stdout or stderr


def has_existing_session() -> bool:
    """Check whether the CLI can already authenticate with local session data."""
    result = run_cli("auth", "me", check=False)
    return result.returncode == 0


def test_login(username: str, password: str) -> bool:
    print("\n=== Test: Login ===")
    result = run_cli("auth", "login", "-u", username, "-p", password)
    output = command_output(result)
    if result.returncode == 0 and ("Logged in" in output or "Login successful" in output):
        print("[PASS] Login successful")
        return True
    print("[FAIL] Login failed")
    if output:
        print(f"  Output: {output}")
    return False


def test_me() -> bool:
    print("\n=== Test: Get Current User ===")
    result = run_cli("auth", "me")
    output = command_output(result)
    if result.returncode == 0 and "UID:" in output:
        print("[PASS] Got user info")
        print(f"  {output.splitlines()[0]}")
        return True
    print("[FAIL] Failed to get user info")
    if output:
        print(f"  Output: {output}")
    return False


def test_me_json() -> bool:
    print("\n=== Test: Get Current User (JSON) ===")
    result = run_cli("--json", "auth", "me")
    output = command_output(result)
    try:
        data = json.loads(output)
    except (json.JSONDecodeError, TypeError):
        print("[FAIL] Invalid JSON response")
        if output:
            print(f"  Output: {output[:200]}")
        return False
    print("[PASS] Got JSON response")
    print(f"  UID: {data.get('uid', 'N/A')}")
    return True


def test_conversations() -> Optional[bool]:
    print("\n=== Test: List Conversations ===")
    result = run_cli("conversations", "--limit", "5", check=False)
    output = command_output(result)
    if result.returncode == 0 and output:
        print("[PASS] Got conversations list")
        lines = output.splitlines()
        print(f"  Found {len([line for line in lines if line.strip()])} items")
        return True
    if "HTTP 404" in output:
        print("[SKIP] Conversations endpoint is not available on this backend")
        return None
    print("[FAIL] Failed to list conversations")
    if output:
        print(f"  Output: {output}")
    return False


def test_friends() -> bool:
    print("\n=== Test: List Friends ===")
    result = run_cli("friend", "list")
    output = command_output(result)
    if result.returncode == 0:
        print("[PASS] Got friends list")
        try:
            items = json.loads(output) if output.startswith("[") else []
        except json.JSONDecodeError:
            items = []
        if items:
            print(f"  Found {len(items)} friends")
        elif output.strip():
            print(f"  Output: {output.splitlines()[0]}")
        else:
            print("  (no friends)")
        return True
    print("[FAIL] Failed to list friends")
    if output:
        print(f"  Output: {output}")
    return False


def test_groups() -> bool:
    print("\n=== Test: List Groups ===")
    result = run_cli("group", "list")
    output = command_output(result)
    if result.returncode == 0:
        print("[PASS] Got groups list")
        try:
            items = json.loads(output) if output.startswith("[") else []
        except json.JSONDecodeError:
            items = []
        if items:
            print(f"  Found {len(items)} groups")
        elif output.strip():
            print(f"  Output: {output.splitlines()[0]}")
        else:
            print("  (no groups)")
        return True
    print("[FAIL] Failed to list groups")
    if output:
        print(f"  Output: {output}")
    return False


def test_logout() -> bool:
    print("\n=== Test: Logout ===")
    result = run_cli("auth", "logout")
    output = command_output(result)
    if result.returncode == 0 and "Logged out" in output:
        print("[PASS] Logout successful")
        return True
    print("[FAIL] Logout failed")
    if output:
        print(f"  Output: {output}")
    return False


def test_not_logged_in() -> bool:
    print("\n=== Test: Commands Fail When Not Logged In ===")
    result = run_cli("auth", "me", check=False)
    output = command_output(result)
    if result.returncode != 0 and ("Not logged in" in output or "Error" in output):
        print("[PASS] Correctly requires authentication")
        return True
    print("[FAIL] Should require authentication")
    if output:
        print(f"  Output: {output}")
    return False


def run_all_tests(username: Optional[str], password: Optional[str]) -> bool:
    print("=" * 60)
    print("WuKongIM CLI Harness - Test Suite")
    print("=" * 60)

    results: list[tuple[str, Optional[bool]]] = []
    using_existing_session = has_existing_session()

    if username and password:
        results.append(("Login", test_login(username, password)))
        results.append(("Get user info", test_me()))
        results.append(("Get user info (JSON)", test_me_json()))
        results.append(("List conversations", test_conversations()))
        results.append(("List friends", test_friends()))
        results.append(("List groups", test_groups()))
        results.append(("Logout", test_logout()))
    elif using_existing_session:
        print("\n- Reusing existing local session for authenticated smoke tests")
        results.append(("Get user info", test_me()))
        results.append(("Get user info (JSON)", test_me_json()))
        results.append(("List conversations", test_conversations()))
        results.append(("List friends", test_friends()))
        results.append(("List groups", test_groups()))
    else:
        results.append(("Not logged in check", test_not_logged_in()))
        print("\n- Skipping authenticated tests (no credentials or reusable session found)")
        print("  Set WK_TEST_USERNAME and WK_TEST_PASSWORD or seed ~/.wukongim/session.json")

    print("\n" + "=" * 60)
    print("Test Summary")
    print("=" * 60)

    passed = sum(1 for _, result in results if result is True)
    failed = sum(1 for _, result in results if result is False)
    skipped = sum(1 for _, result in results if result is None)

    for name, result in results:
        status = "[PASS]" if result is True else "[SKIP]" if result is None else "[FAIL]"
        label = "SKIP" if result is None else "PASS" if result else "FAIL"
        print(f"{status} {label} {name}")

    print(f"\nPassed: {passed}")
    print(f"Failed: {failed}")
    print(f"Skipped: {skipped}")

    return failed == 0


def main():
    parser = argparse.ArgumentParser(description="WuKongIM CLI Smoke Test Script")
    parser.add_argument("--username", help="Test username", default=TEST_USERNAME)
    parser.add_argument("--password", help="Test password", default=TEST_PASSWORD)
    args = parser.parse_args()

    success = run_all_tests(args.username, args.password)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
