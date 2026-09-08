import concurrent.futures
import gzip
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest

from fault_proxy import EventLog, FaultServer, RuleStore, validate_rules, validate_upstream


ROOT = Path(__file__).resolve().parent
PROFILE = "^/gateway/(v1/)?users/me(\\?.*)?$"


def rules(status=503, times=0, **response):
    return {"scenario": "test", "rules": [{
        "id": "profile", "match": {"path": PROFILE, "method": "GET"},
        "times": times, "respond": {"status": status, "body": "fault", **response},
    }]}


class Stub(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, format, *args):
        pass

    def handle_request(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with self.server.lock:
            self.server.seen.append((self.command, self.path, dict(self.headers), body))
        if self.path == "/gateway/drop-upstream":
            self.close_connection = True
            return
        payload = gzip.compress(b"upstream bytes") if self.path.endswith("/gzip") else body or b"upstream bytes"
        self.send_response(207)
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Content-Type", "application/octet-stream")
        self.send_header("Connection", "close, X-Upstream-Hop")
        self.send_header("X-Upstream-Hop", "must-not-leak")
        self.send_header("X-Upstream", "retained")
        self.send_header("Set-Cookie", "one=1")
        self.send_header("Set-Cookie", "two=2")
        if self.path.endswith("/gzip"):
            self.send_header("Content-Encoding", "gzip")
        self.end_headers()
        self.close_connection = True
        if self.command != "HEAD":
            self.wfile.write(payload)

    do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = do_OPTIONS = handle_request


class ProxyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.upstream = ThreadingHTTPServer(("127.0.0.1", 0), Stub)
        cls.upstream.seen, cls.upstream.lock = [], threading.Lock()
        cls.upstream_thread = threading.Thread(target=cls.upstream.serve_forever, kwargs={"poll_interval": 0.01})
        cls.upstream_thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.upstream.shutdown()
        cls.upstream.server_close()
        cls.upstream_thread.join()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.directory = Path(self.temporary.name)
        self.path = self.directory / "rules.json"
        self.path.write_text(json.dumps({"scenario": "S00", "rules": []}))
        self.log = EventLog(self.directory / "proxy.log", quiet=True)
        self.proxy = FaultServer(("127.0.0.1", 0), "https://msi.olivium.space", self.path, self.log,
                                 connection_factory=lambda: http.client.HTTPConnection("127.0.0.1", self.upstream.server_port, timeout=2))
        self.thread = threading.Thread(target=self.proxy.serve_forever, kwargs={"poll_interval": 0.01})
        self.thread.start()

    def tearDown(self):
        self.proxy.shutdown()
        self.proxy.server_close()
        self.thread.join()
        self.temporary.cleanup()

    def request(self, method="GET", path="/gateway/v1/users/me", body=None, headers=None):
        connection = http.client.HTTPConnection("127.0.0.1", self.proxy.server_port, timeout=3)
        try:
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            return response.status, response.getheaders(), response.read()
        finally:
            connection.close()

    def activate(self, document):
        status, _, _ = self.request("PUT", "/__fault/rules", json.dumps(document))
        self.assertEqual(status, 200)

    def test_passthrough_all_methods_body_headers_and_status(self):
        for method in ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]:
            with self.subTest(method=method):
                status, response_headers, body = self.request(method, body=b"exact\x00bytes", headers={
                    "Authorization": "Bearer never-log-this", "Connection": "X-Request-Hop",
                    "X-Request-Hop": "stripped", "X-Keep": "kept", "Proxy-Secret": "stripped"})
                self.assertEqual(status, 207)
                self.assertEqual(body, b"" if method == "HEAD" else b"exact\x00bytes")
                self.assertEqual(dict(response_headers)["Content-Length"], "11")
                self.assertNotIn("X-Upstream-Hop", dict(response_headers))
                self.assertEqual([v for k, v in response_headers if k == "Set-Cookie"], ["one=1", "two=2"])
                with self.upstream.lock:
                    seen = self.upstream.seen[-1]
                self.assertEqual(seen[2]["Host"], "msi.olivium.space")
                self.assertEqual(seen[2]["Authorization"], "Bearer never-log-this")
                self.assertEqual(seen[2]["X-Keep"], "kept")
                self.assertNotIn("X-Request-Hop", seen[2])
                self.assertNotIn("Proxy-Secret", seen[2])

    def test_compressed_response_bytes_remain_compressed(self):
        status, headers, body = self.request(path="/gateway/gzip")
        self.assertEqual(status, 207)
        self.assertEqual(dict(headers)["Content-Encoding"], "gzip")
        self.assertEqual(gzip.decompress(body), b"upstream bytes")

    def test_rule_count_and_both_versioned_paths(self):
        self.activate(rules(times=2))
        self.assertEqual(self.request(path="/gateway/users/me?secret=value")[0], 503)
        self.assertEqual(self.request()[0], 503)
        self.assertEqual(self.request()[0], 207)
        self.activate(rules())
        for _ in range(4):
            self.assertEqual(self.request()[0], 503)

    def test_count_is_atomic_for_concurrent_requests(self):
        self.activate(rules(times=3))
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            statuses = list(executor.map(lambda _: self.request()[0], range(12)))
        self.assertEqual(statuses.count(503), 3)
        self.assertEqual(statuses.count(207), 9)

    def test_path_and_method_scope(self):
        self.activate(rules())
        for target in ["/gateway/v1/users/me/child", "/gateway/v1/users/medical", "/gateway/v1/deliveries", "/gateway/jeebers/me/availability"]:
            self.assertEqual(self.request(path=target)[0], 207)
        self.assertEqual(self.request("POST")[0], 207)

    def test_availability_404_is_rejected_by_control_and_runtime(self):
        document = rules(status=404)
        document["rules"][0]["match"]["path"] = "^/gateway/jeebers/me/availability$"
        status, _, _ = self.request("PUT", "/__fault/rules", json.dumps(document))
        self.assertEqual(status, 400)
        # A query-only regex evades static sample checks, not the runtime guard.
        document["rules"][0]["match"]["path"] = r"^/gateway/jeebers/me/availability\?check=1$"
        self.activate(document)
        with self.upstream.lock:
            before = len(self.upstream.seen)
        status, _, body = self.request(path="/gateway/jeebers/me/availability?check=1")
        self.assertEqual(status, 503)
        self.assertIn(b"no upstream request sent", body)
        with self.upstream.lock:
            self.assertEqual(len(self.upstream.seen), before)

    def test_optional_header_matcher(self):
        document = rules()
        document["rules"][0]["match"]["header"] = {"name": "X-Scenario", "regex": "^yes$"}
        self.activate(document)
        self.assertEqual(self.request()[0], 207)
        self.assertEqual(self.request(headers={"X-Scenario": "yes"})[0], 503)

    def test_body_file_and_retry_after(self):
        (self.directory / "bodies").mkdir()
        (self.directory / "bodies" / "bad.html").write_bytes(b"<html>exact</html>")
        document = rules(headers={"Retry-After": "20", "Content-Type": "text/html"})
        response = document["rules"][0]["respond"]
        del response["body"]
        response["body_file"] = "bodies/bad.html"
        self.activate(document)
        status, headers, body = self.request()
        self.assertEqual((status, body), (503, b"<html>exact</html>"))
        self.assertEqual(dict(headers)["Retry-After"], "20")
        self.assertEqual(dict(headers)["X-Fault-Proxy"], "profile")

    def test_delay_and_drop(self):
        self.activate(rules(delay_ms=30))
        started = time.monotonic()
        self.assertEqual(self.request()[0], 503)
        self.assertGreaterEqual(time.monotonic() - started, 0.025)
        self.activate(rules(drop=True))
        with self.assertRaises((http.client.RemoteDisconnected, ConnectionResetError)):
            self.request()
        self.assertIn("DROP(profile #1)", self.log.tail(1)[0])

    def test_controls_never_reach_upstream_and_delete_clears(self):
        self.activate(rules())
        self.assertEqual(json.loads(self.request(path="/__fault/health")[2])["upstream"], "https://msi.olivium.space")
        self.assertEqual(json.loads(self.request(path="/__fault/rules")[2])["scenario"], "test")
        self.assertEqual(self.request(path="/__fault/unknown")[0], 404)
        self.assertEqual(self.request("DELETE", "/__fault/rules")[0], 200)
        self.assertEqual(self.request()[0], 207)
        self.assertIsInstance(json.loads(self.request(path="/__fault/log?n=1")[2]), list)
        self.assertEqual(self.request(path="/__fault/log?n=bad")[0], 400)

    def test_file_reload_resets_count_and_invalid_reload_fails_closed(self):
        self.path.write_text(json.dumps(rules(times=1)))
        self.assertEqual(self.request()[0], 503)
        self.assertEqual(self.request()[0], 207)
        self.path.write_text(json.dumps(rules(times=2)))
        self.assertEqual(self.request()[0], 503)
        self.path.write_text("{")
        self.assertEqual(self.request()[0], 503)
        self.assertIn(b"no upstream request sent", self.request()[2])
        self.path.write_text(json.dumps({"scenario": "S00", "rules": []}))
        self.assertEqual(self.request()[0], 207)

    def test_invalid_control_preserves_existing_rules(self):
        self.activate(rules())
        self.assertEqual(self.request("PUT", "/__fault/rules", "{")[0], 400)
        for document in [None, {"scenario": None, "rules": []}, {"scenario": "test", "rules": [None]}]:
            self.assertEqual(self.request("PUT", "/__fault/rules", json.dumps(document))[0], 400)
        self.assertEqual(self.request()[0], 503)

    def test_upstream_failure_is_bounded_problem_without_exception(self):
        status, headers, body = self.request(path="/gateway/drop-upstream")
        self.assertEqual(status, 502)
        self.assertEqual(dict(headers)["Content-Type"], "application/problem+json")
        self.assertEqual(json.loads(body), {"type": "about:blank", "title": "fault-proxy upstream failure", "status": 502})

    def test_log_excludes_secrets_in_headers_query_body_and_path(self):
        sentinel = "token-SUPERSECRETvalue"
        self.request("POST", "/gateway/users/" + sentinel + "?token=" + sentinel,
                     body=sentinel, headers={"Authorization": "Bearer " + sentinel, "Cookie": sentinel})
        self.request(path="/__fault/health")
        recorded = (self.directory / "proxy.log").read_text()
        self.assertNotIn(sentinel, recorded)
        self.assertNotIn("?", recorded)
        self.assertIn("/gateway/users/[redacted]", recorded)
        self.assertNotIn(sentinel, self.request(path="/__fault/log")[2].decode())

    def test_browser_cross_origin_and_rebinding_refused(self):
        self.assertEqual(self.request(headers={"Origin": "https://example.com"})[0], 403)
        self.assertEqual(self.request(headers={"Host": "example.com"})[0], 403)

    def test_absolute_external_and_traversal_targets_refused(self):
        for target in ["https://example.com/gateway/x", "//example.com/gateway/x", "/other", "/gateway/../admin", "/gateway/%2e%2e/admin", "/gateway/x%5c..%5cadmin"]:
            with self.subTest(target=target):
                self.assertIn(self.request(path=target)[0], {400, 403})

    def test_transfer_encoding_and_ambiguous_length_refused(self):
        with socket.create_connection(("127.0.0.1", self.proxy.server_port), timeout=2) as client:
            client.sendall(f"POST /gateway/v1/users/me HTTP/1.1\r\nHost: 127.0.0.1:{self.proxy.server_port}\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n".encode())
            self.assertIn(b"400", client.recv(1024).split(b"\r\n")[0])


class ValidationTests(unittest.TestCase):
    def test_upstream_and_listener_envelope(self):
        self.assertEqual(validate_upstream("https://msi.olivium.space"), "https://msi.olivium.space")
        for url in ["https://jeeb.fds-1.com", "http://msi.olivium.space", "https://msi.olivium.space.evil", "https://msi.olivium.space:443", "https://user@msi.olivium.space", "http://127.0.0.1:1"]:
            with self.assertRaises(ValueError):
                validate_upstream(url)
        with self.assertRaises(ValueError):
            FaultServer(("0.0.0.0", 8089), "https://msi.olivium.space", ROOT / "missing")
        result = subprocess.run([sys.executable, str(ROOT / "fault_proxy.py"), "--listen", "0.0.0.0:8089", "--rules", "missing", "--log", "missing"], capture_output=True)
        self.assertEqual(result.returncode, 2)

    def test_invalid_rules_rejected_before_serving(self):
        mutations = [
            lambda d: d["rules"][0]["match"].update(path=".*"),
            lambda d: d["rules"][0]["match"].update(path="^/gateway/.*"),
            lambda d: d["rules"][0].update(times=-1),
            lambda d: d["rules"][0]["respond"].update(delay_ms=60001),
            lambda d: d["rules"][0]["respond"].update(status=401),
            lambda d: d["rules"][0]["respond"].update(headers={"X-Bad": "x\r\nInjected: bad"}),
            lambda d: d["rules"][0]["respond"].update(body_file="../outside"),
            lambda d: d["rules"][0]["match"].update(header={"name": "Authorization", "regex": ".*"}),
        ]
        for mutate in mutations:
            document = rules()
            mutate(document)
            with self.assertRaises(ValueError):
                validate_rules(document, ROOT)

    def test_availability_404_cannot_be_injected_by_custom_rules(self):
        for path in ["^/gateway/jeebers/me/availability$", "^/gateway/(v1/)?jeebers/me/availability$", "^/gateway/.*$"]:
            document = rules(status=404)
            document["rules"][0]["match"]["path"] = path
            with self.assertRaisesRegex(ValueError, "availability 404"):
                validate_rules(document, ROOT)

    def test_body_files_cannot_escape_through_parent_absolute_or_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            (base / "rules").mkdir()
            (base / "outside").write_text("not a fixture")
            (base / "rules" / "linked").symlink_to(base / "outside")
            for name in ["../outside", str(base / "outside"), "linked"]:
                document = rules()
                response = document["rules"][0]["respond"]
                del response["body"]
                response["body_file"] = name
                with self.assertRaises(ValueError):
                    validate_rules(document, base / "rules")

    def test_all_catalogue_rules_compile_and_do_not_match_neighbor_routes(self):
        paths = sorted((ROOT / "scenarios").glob("*.json"))
        self.assertEqual([json.loads(p.read_text())["scenario"] for p in paths], [f"S{i:02d}" for i in range(17)])
        for path in paths:
            document = json.loads(path.read_text())
            store = RuleStore(path)
            self.assertEqual(store.snapshot()["scenario"], document["scenario"])
            for item in store.compiled:
                self.assertFalse(item["regex"].fullmatch("/gateway/jeebers/me/availability"))
                self.assertFalse(item["regex"].fullmatch("/gateway/v1/users/me/other"))
            for variant in document.get("variants", []):
                document["rules"][0]["respond"] = variant["respond"]
                validate_rules(document, path.parent)


if __name__ == "__main__":
    unittest.main()
