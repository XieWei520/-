import json
import math
import os
import random
import time
import uuid

import orjson
from locust import User, between, events, task
from websocket import WebSocketConnectionClosedException, create_connection

def _env_float(name, default, min_value=None):
    raw = os.getenv(name, str(default))
    try:
        value = float(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be a float, got {raw!r}") from exc

    if not math.isfinite(value):
        raise ValueError(f"{name} must be finite, got {value!r}")

    if min_value is not None and value < min_value:
        raise ValueError(f"{name} must be >= {min_value}, got {value}")
    return value


def _env_int(name, default, min_value=None):
    raw = os.getenv(name, str(default))
    try:
        value = int(raw)
    except ValueError as exc:
        raise ValueError(f"{name} must be an int, got {raw!r}") from exc

    if min_value is not None and value < min_value:
        raise ValueError(f"{name} must be >= {min_value}, got {value}")
    return value


def _env_bool(name, default):
    raw = os.getenv(name, str(default)).strip().lower()
    true_values = {"1", "true", "yes", "on"}
    false_values = {"0", "false", "no", "off"}
    if raw in true_values:
        return True
    if raw in false_values:
        return False
    valid_values = sorted(true_values | false_values)
    raise ValueError(f"{name} must be one of {valid_values}, got {raw!r}")


TARGET_WS_URL = os.getenv("TARGET_WS_URL", "ws://127.0.0.1:5200")
HEARTBEAT_INTERVAL_S = _env_float("HEARTBEAT_INTERVAL_S", "25", min_value=0.0)
MESSAGE_RATE_PER_USER = _env_float("MESSAGE_RATE_PER_USER", "0.05", min_value=0.0)
AUTH_TOKEN = os.getenv("AUTH_TOKEN", "replace-me")
CHANNEL_ID = os.getenv("CHANNEL_ID", "stress-room-01")
WS_CONNECT_TIMEOUT_S = _env_float("WS_CONNECT_TIMEOUT_S", "10", min_value=0.001)
WS_RECV_TIMEOUT_S = _env_float("WS_RECV_TIMEOUT_S", "1.5", min_value=0.001)
WS_SEND_RETRY_MAX = _env_int("WS_SEND_RETRY_MAX", "1", min_value=0)
WS_SEND_RETRY_BACKOFF_S = _env_float("WS_SEND_RETRY_BACKOFF_S", "0.2", min_value=0.0)


CONNECT_HELLO_EXPECT_RESPONSE = _env_bool("CONNECT_HELLO_EXPECT_RESPONSE", "1")
HEARTBEAT_EXPECT_RESPONSE = _env_bool("HEARTBEAT_EXPECT_RESPONSE", "1")
BUSINESS_EXPECT_RESPONSE = _env_bool("BUSINESS_EXPECT_RESPONSE", "0")
CONNECT_EXPECTED_TYPE = os.getenv("CONNECT_EXPECTED_TYPE", "").strip() or None
HEARTBEAT_EXPECTED_TYPE = os.getenv("HEARTBEAT_EXPECTED_TYPE", "").strip() or None
BUSINESS_EXPECTED_TYPE = os.getenv("BUSINESS_EXPECTED_TYPE", "").strip() or None


class IMWebSocketUser(User):
    wait_time = between(0.5, 1.5)

    def on_start(self):
        self.session_id = str(uuid.uuid4())
        self.last_heartbeat_at = 0.0
        self.ws = None
        if MESSAGE_RATE_PER_USER > 0:
            self.business_message_interval_s = 1.0 / MESSAGE_RATE_PER_USER
            self.next_business_message_at = time.time() + random.uniform(
                0.0, self.business_message_interval_s
            )
        else:
            self.business_message_interval_s = None
            self.next_business_message_at = float("inf")
        self._connect()

    def on_stop(self):
        self._reset_socket()

    def _fire_metric(self, metric_name, start_time, response_length=0, exception=None):
        events.request.fire(
            request_type="WS",
            name=metric_name,
            response_time=(time.perf_counter() - start_time) * 1000,
            response_length=response_length,
            exception=exception,
        )

    def _encode_json(self, payload):
        return orjson.dumps(payload).decode("utf-8")

    def _reset_socket(self):
        if self.ws is not None:
            try:
                self.ws.close()
            except Exception:
                pass
            finally:
                self.ws = None

    def _response_json(self, response):
        if isinstance(response, bytes):
            try:
                response_text = response.decode("utf-8")
            except UnicodeDecodeError:
                return None
        elif isinstance(response, str):
            response_text = response
        else:
            return None

        try:
            parsed = json.loads(response_text)
        except json.JSONDecodeError:
            return None

        if isinstance(parsed, dict):
            return parsed
        return None

    def _validate_response(self, response, expected_type):
        parsed = self._response_json(response)
        if parsed is not None:
            error_value = parsed.get("error")
            if error_value not in (None, "", False):
                return False, f"response error field present: {error_value!r}"

            code_value = parsed.get("code")
            if isinstance(code_value, (int, float)) and not isinstance(code_value, bool) and code_value != 0:
                return False, f"non-zero response code: {code_value!r}"

            status_value = parsed.get("status")
            if isinstance(status_value, str) and status_value.strip().lower() in {"error", "fail", "failed"}:
                return False, f"error response status: {status_value!r}"

            if expected_type is not None:
                actual_type = parsed.get("type")
                if str(actual_type) != expected_type:
                    return False, f"unexpected response type: got {actual_type!r}, want {expected_type!r}"
            return True, None

        if expected_type is not None:
            return False, "response is not a JSON object while expected type validation is enabled"

        return True, None

    def _connect(self):
        start_time = time.perf_counter()
        response = None
        try:
            headers = [
                f"Authorization: Bearer {AUTH_TOKEN}",
                f"X-Session-ID: {self.session_id}",
            ]
            self._reset_socket()
            self.ws = create_connection(TARGET_WS_URL, header=headers, timeout=WS_CONNECT_TIMEOUT_S)
            hello_payload = {
                "type": "hello",
                "session_id": self.session_id,
                "ts": int(time.time()),
            }
            self.ws.send(self._encode_json(hello_payload))
            if CONNECT_HELLO_EXPECT_RESPONSE:
                self.ws.settimeout(WS_RECV_TIMEOUT_S)
                response = self.ws.recv()
                is_valid, validation_error = self._validate_response(response, CONNECT_EXPECTED_TYPE)
                if not is_valid:
                    raise ValueError(f"invalid connect response: {validation_error}")
        except Exception as exc:
            self._reset_socket()
            self._fire_metric("connect", start_time, exception=exc)
            raise
        else:
            response_length = len(response) if isinstance(response, (str, bytes)) else 0
            self._fire_metric("connect", start_time, response_length=response_length)

    def _send_json(self, payload, metric_name, expect_response, expected_type=None):
        start_time = time.perf_counter()
        encoded_payload = self._encode_json(payload)
        last_exception = None

        for attempt in range(WS_SEND_RETRY_MAX + 1):
            attempt_start_time = time.perf_counter()
            try:
                if self.ws is None:
                    self._connect()
                self.ws.send(encoded_payload)
                response_length = 0
                if expect_response:
                    self.ws.settimeout(WS_RECV_TIMEOUT_S)
                    response = self.ws.recv()
                    is_valid, validation_error = self._validate_response(response, expected_type)
                    if not is_valid:
                        raise ValueError(f"invalid {metric_name} response: {validation_error}")
                    response_length = len(response) if isinstance(response, (str, bytes)) else 0
                self._fire_metric(metric_name, start_time, response_length=response_length)
                return True
            except WebSocketConnectionClosedException as exc:
                last_exception = exc
                self._reset_socket()
            except Exception as exc:
                last_exception = exc
                self._reset_socket()

            if attempt < WS_SEND_RETRY_MAX:
                self._fire_metric(
                    f"{metric_name}.attempt_failure",
                    attempt_start_time,
                    exception=last_exception,
                )
                time.sleep(WS_SEND_RETRY_BACKOFF_S)
                continue

        self._fire_metric(metric_name, start_time, exception=last_exception)
        return False

    @task(10)
    def heartbeat(self):
        now = time.time()
        if now - self.last_heartbeat_at < HEARTBEAT_INTERVAL_S:
            return

        payload = {
            "type": "heartbeat",
            "session_id": self.session_id,
            "ts": int(now),
        }
        if self._send_json(
            payload,
            "heartbeat",
            expect_response=HEARTBEAT_EXPECT_RESPONSE,
            expected_type=HEARTBEAT_EXPECTED_TYPE,
        ):
            self.last_heartbeat_at = now

    @task(1)
    def business_message(self):
        if self.business_message_interval_s is None:
            return

        payload = {
            "type": "chat.message",
            "channel_id": CHANNEL_ID,
            "message_id": str(uuid.uuid4()),
            "session_id": self.session_id,
            "content": {"text": "locust-stress-ping"},
            "ts": int(time.time()),
        }
        now = time.time()
        if now < self.next_business_message_at:
            return

        due_messages = 0
        while now >= self.next_business_message_at:
            due_messages += 1
            self.next_business_message_at += self.business_message_interval_s

        for _ in range(due_messages):
            payload["message_id"] = str(uuid.uuid4())
            payload["ts"] = int(time.time())
            self._send_json(
                payload,
                "chat.message",
                expect_response=BUSINESS_EXPECT_RESPONSE,
                expected_type=BUSINESS_EXPECTED_TYPE,
            )
