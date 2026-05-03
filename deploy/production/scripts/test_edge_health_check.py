#!/usr/bin/env python3
from __future__ import annotations

import unittest

from edge_health_check import (
    PortCheck,
    build_websocket_handshake,
    default_base_url,
    default_ws_url,
    evaluate_port_check,
    parse_http_status,
)


class EdgeHealthCheckTests(unittest.TestCase):
    def test_default_urls_use_public_domain_and_tls_edge(self) -> None:
        env = {
            "PUBLIC_DOMAIN": "infoequity.qingyunshe.top",
            "PUBLIC_HTTPS_PORT": "443",
        }

        base_url = default_base_url(env)

        self.assertEqual(base_url, "https://infoequity.qingyunshe.top")
        self.assertEqual(
            default_ws_url(env, base_url),
            "wss://infoequity.qingyunshe.top/ws",
        )

    def test_default_base_url_keeps_nonstandard_https_port(self) -> None:
        env = {
            "PUBLIC_DOMAIN": "example.com",
            "PUBLIC_HTTPS_PORT": "8443",
        }

        self.assertEqual(default_base_url(env), "https://example.com:8443")

    def test_evaluate_port_check_requires_open_or_closed_ports(self) -> None:
        raw_ws = PortCheck(name="raw websocket", port=5200, expected_open=False)
        https = PortCheck(name="https edge", port=443, expected_open=True)

        self.assertTrue(evaluate_port_check(raw_ws, is_open=False).ok)
        self.assertFalse(evaluate_port_check(raw_ws, is_open=True).ok)
        self.assertTrue(evaluate_port_check(https, is_open=True).ok)
        self.assertFalse(evaluate_port_check(https, is_open=False).ok)

    def test_parse_http_status_reads_upgrade_status_line(self) -> None:
        response = b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n\r\n"

        self.assertEqual(parse_http_status(response), 101)

    def test_build_websocket_handshake_contains_upgrade_headers(self) -> None:
        request = build_websocket_handshake(
            host="infoequity.qingyunshe.top",
            path="/ws",
            secure=True,
        )
        text = request.decode("ascii")

        self.assertTrue(text.startswith("GET /ws HTTP/1.1\r\n"))
        self.assertIn("Host: infoequity.qingyunshe.top\r\n", text)
        self.assertIn("Upgrade: websocket\r\n", text)
        self.assertIn("Connection: Upgrade\r\n", text)
        self.assertIn("Sec-WebSocket-Version: 13\r\n", text)


if __name__ == "__main__":
    unittest.main()
