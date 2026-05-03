from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
compose_text = (ROOT / "docker-compose.yaml").read_text(encoding="utf-8")
nginx_text = (ROOT / "nginx" / "default.conf.template").read_text(encoding="utf-8")
wk_template_text = (ROOT / "config" / "wk.yaml.tpl").read_text(encoding="utf-8")
bootstrap_text = (ROOT / "scripts" / "bootstrap_server.sh").read_text(encoding="utf-8")
readme_text = (ROOT / "README.md").read_text(encoding="utf-8")

assert '${PUBLIC_TCP_PORT}:5100' not in compose_text, "WuKongIM TCP must not be published directly"
assert '${PUBLIC_WS_PORT}:5200' not in compose_text, "WuKongIM WS must not be published directly"
assert '${PUBLIC_WK_API_BIND}:5001' in compose_text, "manager API should remain host-bound for health/admin access"

assert "upstream wukongim_ws" in nginx_text, "nginx must define a WuKongIM WS upstream"
assert "server wukongim:5200;" in nginx_text, "nginx /ws must proxy to the internal WuKongIM WS port"
assert "limit_req_zone $binary_remote_addr zone=ws_limit" in nginx_text, "nginx must rate-limit WS handshakes"
assert "location = /ws {" in nginx_text, "nginx must expose a single /ws public entrypoint"
assert "proxy_pass http://wukongim_ws/;" in nginx_text, "nginx must rewrite /ws to the upstream websocket root"
assert "limit_req zone=ws_limit" in nginx_text, "nginx /ws location must apply the WS rate limit"

assert 'wsAddr: "wss://{{PUBLIC_DOMAIN}}/ws"' in wk_template_text, "route metadata should advertise the TLS /ws edge"
assert 'apiUrl: "{{WK_PUBLIC_API_URL}}"' in wk_template_text, "API metadata should advertise an HTTPS edge URL"
assert "WK_PUBLIC_API_URL=https://wemx.cc" in (ROOT / ".env.example").read_text(encoding="utf-8"), "example env must set HTTPS API metadata"
assert "http://{{EXTERNAL_IP}}:{{PUBLIC_WK_API_PORT}}" not in wk_template_text, "route metadata must not advertise a raw closed HTTP port"
assert "{{PUBLIC_WS_PORT}}" not in wk_template_text, "route metadata must not advertise the raw WS port"
assert "{{PUBLIC_TCP_PORT}}" not in wk_template_text, "route metadata must not advertise the raw TCP port"

assert "PUBLIC_TCP_PORT" not in bootstrap_text, "bootstrap must not open the raw TCP port"
assert "PUBLIC_WS_PORT" not in bootstrap_text, "bootstrap must not open the raw WS port"
assert 'ufw allow "${PUBLIC_HTTPS_PORT}/tcp"' in bootstrap_text, "bootstrap must open the HTTPS edge"
assert "PUBLIC_TCP_PORT" not in readme_text, "README must not instruct operators to expose raw TCP"
assert "PUBLIC_WS_PORT" not in readme_text, "README must not instruct operators to expose raw WS"
