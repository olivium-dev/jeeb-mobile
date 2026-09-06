"""Explicit, scoped device helpers; never run by the offline test suite."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener
import xml.etree.ElementTree as ET


LOCAL = "http://127.0.0.1:8089"
UPSTREAM = "https://msi.olivium.space"
WIRE_LEDGER = re.compile(r"\[http(?:\u2192|\u2190|\u2717)\]")
CREDENTIAL = re.compile(r"bearer\s+\S+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|(?:access|refresh)[_-]?token\s*[:=]\s*\S+", re.I)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        return None


def open_url(request, timeout):
    return build_opener(ProxyHandler({}), NoRedirect()).open(request, timeout=timeout)


def adb(serial, *arguments):
    result = subprocess.run(["adb", "-s", serial, *arguments], capture_output=True, timeout=45)
    if result.returncode:
        raise ValueError("adb failed; check the selected device without exporting raw diagnostics")
    return result.stdout


def control(path, method="GET"):
    with open_url(Request(LOCAL + path, method=method), timeout=5) as response:
        if response.status != 200:
            raise ValueError("local proxy control failed")
        return json.load(response)


def preflight(serial):
    if control("/__fault/health").get("upstream") != UPSTREAM:
        raise ValueError("unexpected upstream")
    document = control("/__fault/rules")
    if document.get("scenario") != "S00" or document.get("rules"):
        raise ValueError("preflight requires S00 pass-through")
    with open_url(UPSTREAM + "/gateway/health/ready", timeout=20) as response:
        if response.status != 200 or response.url != UPSTREAM + "/gateway/health/ready":
            raise ValueError("readiness check failed or redirected")
    if adb(serial, "get-state").strip() != b"device":
        raise ValueError("device is not ready")
    existing = adb(serial, "reverse", "--list").decode().splitlines()
    for line in existing:
        parts = line.split()
        if "tcp:8089" in parts and parts[-2:] != ["tcp:8089", "tcp:8089"]:
            raise ValueError("port 8089 has a different existing mapping; leave it intact")
    adb(serial, "reverse", "tcp:8089", "tcp:8089")
    print("S00 proxy and MSI readiness checked; selected device port 8089 mapped.")
    print("Manually set Dev Tool URL to http://127.0.0.1:8089/gateway and Apply & Restart.")


def teardown(serial, restored):
    if not restored:
        raise ValueError("first restore the app's recorded URL/session/locale/radios and confirm --app-restored")
    control("/__fault/rules", "DELETE")
    adb(serial, "reverse", "--remove", "tcp:8089")
    print("Faults cleared; only selected device's tcp:8089 reverse removed.")
    print("Stop the proxy in its own foreground terminal with Ctrl-C; verify real-data recovery.")


def safe_hierarchy(raw):
    start = raw.find(b"<?xml")
    end = raw.rfind(b"</hierarchy>")
    if start < 0 or end < 0:
        raise ValueError("uiautomator did not return an XML hierarchy")
    raw = raw[start:end + len(b"</hierarchy>")]
    root = ET.fromstring(raw)
    sensitive = re.compile(r"bearer\s+\S+|eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+|(?:access|refresh)[_-]?token\s*[:=]", re.I)
    for node in root.iter("node"):
        identifier = node.get("resource-id", "")
        if node.get("password") == "true" or re.search(r"token|password|authorization|secret", identifier, re.I) or any(
                sensitive.search(value) for value in node.attrib.values()):
            raise ValueError("sensitive UI detected; no evidence was saved")
    return raw, root


def dump(serial, prefix, confirmed):
    if not confirmed or not prefix.is_absolute():
        raise ValueError("use an absolute output prefix and --screen-confirmed-safe on a non-sensitive screen")
    targets = [Path(str(prefix) + suffix) for suffix in [".xml", ".png"]]
    if not prefix.parent.is_dir() or any(path.exists() for path in targets):
        raise ValueError("existing evidence is never overwritten; parent directory must exist")
    raw, root = safe_hierarchy(adb(serial, "exec-out", "uiautomator", "dump", "/dev/tty"))
    screenshot = adb(serial, "exec-out", "screencap", "-p")
    if not screenshot.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ValueError("screencap did not return PNG data")
    for path, data in zip(targets, [raw, screenshot]):
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
    for node in root.iter("node"):
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
        if bounds:
            x1, y1, x2, y2 = map(int, bounds.groups())
            print(f"({(x1+x2)//2},{(y1+y2)//2}) {node.get('resource-id', '')}|{node.get('content-desc', '')}|{node.get('text', '')}")


def wire_ledger(raw):
    lines = [line for line in raw.decode("utf-8", "replace").splitlines() if WIRE_LEDGER.search(line)]
    if not lines:
        raise ValueError("no app wire-ledger lines in the buffer; clear it and reproduce the load")
    if any(CREDENTIAL.search(line) for line in lines):
        raise ValueError("credential-shaped text in the wire ledger; no evidence was saved")
    return lines


def logcat(serial, prefix):
    if not prefix.is_absolute():
        raise ValueError("use an absolute output prefix inside the run's evidence directory")
    target = Path(str(prefix) + ".txt")
    if not prefix.parent.is_dir() or target.exists():
        raise ValueError("existing evidence is never overwritten; parent directory must exist")
    lines = wire_ledger(adb(serial, "logcat", "-d", "-s", "flutter"))
    descriptor = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        stream.write("\n".join(lines) + "\n")
    print(f"{len(lines)} wire-ledger lines, {sum('[http\u2717]' in line for line in lines)} failed reads")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["dump", "logcat", "preflight", "teardown"])
    parser.add_argument("--serial", required=True)
    parser.add_argument("--output-prefix", type=Path)
    parser.add_argument("--screen-confirmed-safe", action="store_true")
    parser.add_argument("--app-restored", action="store_true")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9._:-]+", args.serial):
        parser.error("invalid device serial")
    try:
        if args.action == "preflight":
            preflight(args.serial)
        elif args.action == "teardown":
            teardown(args.serial, args.app_restored)
        elif args.output_prefix is None:
            parser.error(args.action + " requires --output-prefix")
        elif args.action == "logcat":
            logcat(args.serial, args.output_prefix)
        else:
            dump(args.serial, args.output_prefix, args.screen_confirmed_safe)
    except Exception as error:
        print(f"Helper stopped safely ({type(error).__name__}); no raw device/network diagnostics exported.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
