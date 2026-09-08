#!/usr/bin/env python3
"""Local-only, offline-testable fault proxy for the approved P08 device workflow."""

import argparse
from collections import deque
from datetime import datetime, timezone
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import socket
import struct
import threading
import time
from urllib.parse import unquote, urlsplit


ALLOWED_UPSTREAMS = frozenset({"https://msi.olivium.space"})
METHODS = frozenset({"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"})
HOP_HEADERS = frozenset({
    "host", "connection", "keep-alive", "transfer-encoding", "te", "trailer",
    "upgrade", "proxy-authenticate", "proxy-authorization", "content-length",
})
MAX_BODY = 64 * 1024 * 1024
MAX_RULES = 1024 * 1024
PROTECTED_AVAILABILITY_PATHS = frozenset({
    "/gateway/jeebers/me/availability", "/gateway/v1/jeebers/me/availability",
})
SAFE_SEGMENTS = frozenset({
    "gateway", "v1", "users", "me", "auth", "refresh", "deliveries", "requests",
    "jeeb", "jeebers", "earnings", "availability", "feed", "notifications",
    "health", "ready", "offers", "chat", "messages", "profile", "wallet",
})


def validate_upstream(value):
    if value not in ALLOWED_UPSTREAMS:
        raise ValueError("upstream must be an explicitly approved HTTPS origin")
    return value


def safe_path(target):
    path = target.split("?", 1)[0]
    return "/".join(part if part in SAFE_SEGMENTS or not part else "[redacted]"
                    for part in path.split("/"))


def filtered_headers(pairs):
    nominated = set()
    for key, value in pairs:
        if key.lower() == "connection":
            nominated.update(part.strip().lower() for part in value.split(","))
    return [(key, value) for key, value in pairs
            if key.lower() not in HOP_HEADERS | nominated
            and not key.lower().startswith("proxy-")]


def validate_rules(document, directory):
    try:
        return _validate_rules(document, directory)
    except (TypeError, KeyError, AttributeError) as error:
        raise ValueError("invalid rule field type") from error


def _validate_rules(document, directory):
    if not isinstance(document, dict) or not isinstance(document.get("rules"), list):
        raise ValueError("rules must be an object containing a rules array")
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", document.get("scenario", "")):
        raise ValueError("scenario must be a short identifier")
    if len(document["rules"]) > 64:
        raise ValueError("too many rules")
    compiled, ids = [], set()
    for rule in document["rules"]:
        if not isinstance(rule, dict):
            raise ValueError("rule must be an object")
        identifier = rule.get("id", "")
        if not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", identifier) or identifier in ids:
            raise ValueError("rule ids must be unique short identifiers")
        ids.add(identifier)
        match, respond = rule.get("match"), rule.get("respond")
        if not isinstance(match, dict) or not isinstance(respond, dict):
            raise ValueError("match and respond objects are required")
        pattern = match.get("path", "")
        if not isinstance(pattern, str) or not pattern.startswith("^/gateway/") or not pattern.endswith("$"):
            raise ValueError("path regex must be anchored inside /gateway/ at both ends")
        if len(pattern) > 512:
            raise ValueError("path regex is too long")
        try:
            regex = re.compile(pattern)
        except re.error as error:
            raise ValueError("invalid path regex") from error
        method = match.get("method")
        if method is not None and method not in METHODS:
            raise ValueError("unsupported method")
        header = match.get("header")
        header_regex = None
        if header is not None:
            if not isinstance(header, dict) or not re.fullmatch(r"[A-Za-z0-9-]+", header.get("name", "")):
                raise ValueError("invalid header matcher")
            if header["name"].lower() in {"authorization", "cookie", "proxy-authorization"}:
                raise ValueError("credential header matchers are forbidden")
            try:
                header_regex = re.compile(header["regex"])
            except (KeyError, TypeError, re.error) as error:
                raise ValueError("invalid header regex") from error
        times = rule.get("times", 0)
        if type(times) is not int or not 0 <= times <= 10000:
            raise ValueError("times must be a bounded nonnegative integer")
        status = respond.get("status", 200)
        if type(status) is not int or not 200 <= status <= 599:
            raise ValueError("invalid response status")
        if status == 404 and any(regex.fullmatch(path) for path in PROTECTED_AVAILABILITY_PATHS):
            raise ValueError("manufactured availability 404 is forbidden")
        if status in {401, 403} and document["scenario"] not in {"S06", "S07", "S08"}:
            raise ValueError("authentication faults are restricted to S06-S08")
        delay = respond.get("delay_ms", 0)
        if type(delay) is not int or not 0 <= delay <= 60000:
            raise ValueError("delay_ms must be between 0 and 60000")
        if type(respond.get("drop", False)) is not bool:
            raise ValueError("drop must be boolean")
        headers = respond.get("headers", {})
        if not isinstance(headers, dict):
            raise ValueError("response headers must be an object")
        for key, value in headers.items():
            if not re.fullmatch(r"[A-Za-z0-9-]+", key) or not isinstance(value, str) or "\r" in value or "\n" in value:
                raise ValueError("invalid response header")
            try:
                value.encode("latin-1")
            except UnicodeEncodeError as error:
                raise ValueError("response headers must be latin-1") from error
        if "body" in respond and "body_file" in respond:
            raise ValueError("choose body or body_file, not both")
        body = respond.get("body", "")
        if not isinstance(body, str):
            raise ValueError("body must be a string")
        body = body.encode("utf-8")
        if "body_file" in respond:
            name = respond["body_file"]
            if not isinstance(name, str):
                raise ValueError("body_file must be a relative path")
            candidate = (directory / name).resolve()
            if Path(name).is_absolute() or not candidate.is_relative_to(directory.resolve()):
                raise ValueError("body_file must stay inside the rules directory")
            if candidate.stat().st_size > MAX_BODY:
                raise ValueError("body file is too large")
            body = candidate.read_bytes()
        if len(body) > MAX_BODY:
            raise ValueError("body is too large")
        compiled.append({"rule": rule, "regex": regex, "header_regex": header_regex,
                         "body": body, "hits": 0})
    return compiled


class RuleStore:
    def __init__(self, path):
        self.path = Path(path)
        self.lock = threading.RLock()
        self.document = None
        self.compiled = []
        self.signature = None
        self.reload()

    def reload(self):
        with self.lock:
            stat = self.path.stat()
            signature = (stat.st_mtime_ns, stat.st_size, stat.st_ino)
            if signature == self.signature:
                return
            if stat.st_size > MAX_RULES:
                raise ValueError("rules file too large")
            document = json.loads(self.path.read_text(encoding="utf-8"))
            compiled = validate_rules(document, self.path.parent)
            self.document, self.compiled, self.signature = document, compiled, signature

    def replace(self, document):
        with self.lock:
            compiled = validate_rules(document, self.path.parent)
            self.document, self.compiled = document, compiled

    def snapshot(self):
        with self.lock:
            self.reload()
            return json.loads(json.dumps(self.document))

    def match(self, method, target, headers):
        with self.lock:
            self.reload()
            for item in self.compiled:
                rule = item["rule"]
                match = rule["match"]
                if match.get("method", method) != method or not item["regex"].fullmatch(target):
                    continue
                header = match.get("header")
                if header and not item["header_regex"].search(headers.get(header["name"], "")):
                    continue
                if rule.get("times", 0) and item["hits"] >= rule["times"]:
                    continue
                # Regexes can select only a particular query or encoded spelling;
                # enforce on the actual target too, before consuming a rule hit.
                path = unquote(target.split("?", 1)[0]).rstrip("/").lower()
                if rule["respond"].get("status", 200) == 404 and path in PROTECTED_AVAILABILITY_PATHS:
                    raise ValueError("manufactured availability 404 is forbidden")
                item["hits"] += 1
                return rule, item["body"], item["hits"]
        return None


class EventLog:
    def __init__(self, path=None, quiet=False):
        self.path, self.quiet = Path(path) if path else None, quiet
        self.lock, self.events = threading.Lock(), deque(maxlen=2000)
        if self.path:
            import os
            descriptor = os.open(self.path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o600)
            os.close(descriptor)

    def add(self, event, status, method, target, elapsed):
        timestamp = datetime.now(timezone.utc).isoformat(timespec="milliseconds")
        line = f"{timestamp} {event} {status} {method} {safe_path(target)} {elapsed}ms"
        with self.lock:
            self.events.append(line)
            if self.path:
                with self.path.open("a", encoding="utf-8") as stream:
                    stream.write(line + "\n")
            if not self.quiet:
                print(line, flush=True)

    def tail(self, count):
        with self.lock:
            return list(self.events)[-count:]


class FaultServer(ThreadingHTTPServer):
    # Non-daemon handlers so server_close() joins them and no thread writes the log after teardown.
    daemon_threads = False
    request_queue_size = 64

    def __init__(self, address, upstream, rules, log=None, *, connection_factory=None):
        if address[0] != "127.0.0.1":
            raise ValueError("only IPv4 loopback binding is permitted")
        self.upstream = validate_upstream(upstream)
        self.rules = RuleStore(rules)
        self.events = log or EventLog()
        self.connection_factory = connection_factory or (
            lambda: http.client.HTTPSConnection(urlsplit(upstream).hostname, timeout=60))
        super().__init__(address, FaultHandler)

    def handle_error(self, request, client_address):
        pass


class FaultHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def setup(self):
        super().setup()
        self.connection.settimeout(65)

    def log_message(self, format, *args):
        pass

    def _reply(self, status, body=b"", headers=()):
        length = len(body) if status not in {204, 304} else 0
        if self.command == "HEAD":
            advertised = next((v for k, v in headers if k.lower() == "content-length"), None)
            if advertised is not None and advertised.isdigit():
                length = int(advertised)
        self.send_response(status)
        for key, value in filtered_headers(list(headers)):
            self.send_header(key, value)
        self.send_header("Content-Length", str(length))
        self.send_header("Connection", "close")
        self.end_headers()
        self.close_connection = True
        if self.command != "HEAD" and status not in {204, 304}:
            self.wfile.write(body)

    def _json(self, status, value):
        self._reply(status, json.dumps(value).encode(), [("Content-Type", "application/json")])

    def _handle(self):
        started = time.monotonic()
        if self.headers.get("Origin") or self.headers.get("Host") not in {
                "127.0.0.1", f"127.0.0.1:{self.server.server_port}"}:
            self._json(403, {"error": "loopback non-browser clients only"})
            return
        if not self.path.startswith("/") or self.path.startswith("//") or "#" in self.path:
            self._json(400, {"error": "origin-form target required"})
            return
        lengths = self.headers.get_all("Content-Length", [])
        if self.headers.get("Transfer-Encoding") or len(lengths) > 1:
            self._json(400, {"error": "unambiguous Content-Length required"})
            return
        limit = MAX_RULES if self.path.startswith("/__fault/") else MAX_BODY
        try:
            length = int(lengths[0]) if lengths else 0
            if length < 0 or length > limit:
                raise ValueError()
            body = self.rfile.read(length)
            if len(body) != length:
                raise ValueError()
        except (ValueError, TimeoutError):
            self._json(400, {"error": "invalid or incomplete body"})
            return
        if self.path.startswith("/__fault/"):
            self._control(body)
            return
        decoded = unquote(self.path.split("?", 1)[0])
        if not decoded.startswith("/gateway/") or any(part in {".", ".."} for part in decoded.split("/")) or "\\" in decoded:
            self._json(400, {"error": "gateway path required"})
            return
        try:
            fault = self.server.rules.match(self.command, self.path, self.headers)
        except (OSError, ValueError):
            self._json(503, {"error": "rules unavailable or invalid; no upstream request sent"})
            return
        if fault:
            rule, payload, hit = fault
            response = rule["respond"]
            time.sleep(response.get("delay_ms", 0) / 1000)
            status = response.get("status", 200)
            if response.get("drop", False):
                self.server.events.add(f"DROP({rule['id']} #{hit})", 0, self.command, self.path, 0)
                self.connection.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0))
                self.close_connection = True
                self.connection.close()
                return
            self._reply(status, payload, list(response.get("headers", {}).items()) + [("X-Fault-Proxy", rule["id"])])
            event = f"FAULT({rule['id']} #{hit})"
        else:
            connection = None
            try:
                connection = self.server.connection_factory()
                headers = dict(filtered_headers(list(self.headers.items())))
                headers["Host"] = urlsplit(self.server.upstream).hostname
                headers["Content-Length"] = str(len(body))
                connection.request(self.command, self.path, body=body, headers=headers)
                response = connection.getresponse()
                payload = response.read(MAX_BODY + 1)
                if len(payload) > MAX_BODY:
                    raise ValueError("upstream body limit")
                status = response.status
                self._reply(status, payload, response.getheaders())
                event = "PASS"
            except (OSError, http.client.HTTPException, ValueError):
                status = 502
                self._reply(status, b'{"type":"about:blank","title":"fault-proxy upstream failure","status":502}',
                            [("Content-Type", "application/problem+json")])
                event = "UPSTREAM-ERROR"
            finally:
                if connection is not None:
                    connection.close()
        self.server.events.add(event, status, self.command, self.path, int((time.monotonic() - started) * 1000))

    def _control(self, body):
        path = self.path.split("?", 1)[0]
        try:
            if path == "/__fault/health" and self.command == "GET":
                self._json(200, {"ok": True, "upstream": self.server.upstream})
            elif path == "/__fault/rules" and self.command == "GET":
                self._json(200, self.server.rules.snapshot())
            elif path == "/__fault/rules" and self.command in {"PUT", "DELETE"}:
                document = json.loads(body) if self.command == "PUT" else {"scenario": "S00", "rules": []}
                self.server.rules.reload()
                self.server.rules.replace(document)
                self._json(200, {"ok": True, "scenario": document["scenario"]})
            elif path == "/__fault/log" and self.command == "GET":
                from urllib.parse import parse_qs
                count = int(parse_qs(urlsplit(self.path).query).get("n", ["200"])[0])
                self._json(200, self.server.events.tail(max(1, min(count, 2000))))
            else:
                self._json(404, {"error": "unknown control endpoint or method"})
        except (OSError, ValueError, TypeError):
            self._json(400, {"error": "invalid rules or control request"})

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = do_OPTIONS = _handle


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--listen", default="127.0.0.1:8089", choices=["127.0.0.1:8089"])
    parser.add_argument("--upstream", default="https://msi.olivium.space", choices=sorted(ALLOWED_UPSTREAMS))
    parser.add_argument("--rules", required=True, type=Path)
    parser.add_argument("--log", required=True, type=Path)
    args = parser.parse_args()
    try:
        server = FaultServer(("127.0.0.1", 8089), args.upstream, args.rules, EventLog(args.log))
    except (OSError, ValueError) as error:
        parser.exit(2, f"fault-proxy startup refused ({type(error).__name__}); check paths, rules and port\n")
    print("fault-proxy/1 loopback-only; request credentials, query values and bodies are never logged", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
