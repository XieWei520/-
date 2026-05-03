from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
compose_text = (ROOT / "docker-compose.yaml").read_text(encoding="utf-8")

assert "\n  callgateway:\n" in compose_text, "callgateway service missing"
assert "\n  livekit:\n" in compose_text, "livekit service missing"
assert "\n  coturn:\n" in compose_text, "coturn service missing"
assert (ROOT / "config" / "livekit.yaml.tpl").exists(), "livekit config template missing"
assert (ROOT / "config" / "turnserver.conf.tpl").exists(), "turnserver config template missing"
