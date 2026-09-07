#!/usr/bin/env python3
"""Bind retained R8 mapping to the actual AAPT2 resource in the signed AAB.

Wire fields follow AOSP tools/aapt2/Resources.proto. No external dependencies.
Upload is a separate, explicit distribution operation using pinned buildtools.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile

RESOURCE = b"com.google.firebase.crashlytics.mapping_file_id"
PACKAGE = b"com.olivium.jeeb"
BUILDTOOLS_SHA256 = "e43456d8829181317869e010d27b8dce3e37524a9b411b5fd870b62dda1f856b"


def fields(data):
    """Decode bounded protobuf fields; reject malformed lengths and wire types."""
    offset = 0

    def varint():
        nonlocal offset
        value = 0
        for shift in range(0, 70, 7):
            if offset >= len(data):
                raise ValueError("truncated protobuf varint")
            byte = data[offset]
            offset += 1
            value |= (byte & 127) << shift
            if byte < 128:
                return value
        raise ValueError("oversized protobuf varint")

    result = {}
    while offset < len(data):
        tag = varint()
        number, wire = tag >> 3, tag & 7
        if number == 0:
            raise ValueError("invalid protobuf field")
        if wire == 0:
            value = varint()
        else:
            if wire not in (1, 2, 5):
                raise ValueError("unsupported protobuf wire type")
            size = varint() if wire == 2 else (8 if wire == 1 else 4)
            if size > len(data) - offset:
                raise ValueError("truncated protobuf field")
            value = data[offset:offset + size]
            offset += size
        result.setdefault(number, []).append(value)
    return result


def one(message, number):
    values = message.get(number, [])
    if len(values) != 1 or not isinstance(values[0], bytes):
        raise ValueError("missing or ambiguous resource field")
    return values[0]


def string_resource(data, name):
    values = []
    for package in fields(data).get(2, []):
        package = fields(package)
        if one(package, 2) != PACKAGE:
            continue
        for kind in package.get(3, []):
            kind = fields(kind)
            if one(kind, 2) != b"string":
                continue
            for entry in kind.get(3, []):
                entry = fields(entry)
                if one(entry, 2) != name:
                    continue
                # A single unlocalized string is required. Ambiguous/overlay
                # values must not choose the upload identity accidentally.
                config = fields(one(entry, 6))
                if config.get(1, [b""]) != [b""]:
                    raise ValueError("identity resource is configuration-specific")
                value = fields(one(config, 2))
                item = fields(one(value, 4))
                if any(key in item for key in (1, 3, 4, 5, 6, 7)):
                    raise ValueError("identity resource is not a literal string")
                values.append(one(fields(one(item, 2)), 1).decode("utf-8"))
    if len(values) != 1:
        raise ValueError("missing or ambiguous identity resource")
    return values[0]


def identity(aab):
    with zipfile.ZipFile(aab) as archive:
        matches = [entry for entry in archive.infolist()
                   if entry.filename == "base/resources.pb"]
        if len(matches) != 1 or matches[0].file_size > 32 * 1024 * 1024:
            raise ValueError("invalid AAB resources")
        data = archive.read(matches[0])
    mapping_id = string_resource(data, RESOURCE)
    if not re.fullmatch(r"[0-9a-fA-F]{32}", mapping_id) or int(mapping_id, 16) == 0:
        raise ValueError("missing unique Crashlytics mapping ID")
    app_id = string_resource(data, b"google_app_id")
    if not re.fullmatch(r"1:[0-9]+:android:[0-9a-f]+", app_id):
        raise ValueError("invalid Firebase app ID")
    return {"crashlytics_mapping_id": mapping_id, "firebase_app_id": app_id}


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate(aab, mapping, provenance):
    record = json.loads(Path(provenance).read_text())
    actual = identity(aab)
    if any(record.get(key) != value for key, value in actual.items()):
        raise ValueError("Crashlytics identity differs from retained provenance")
    if record.get("artifact_sha256") != sha256(aab):
        raise ValueError("AAB differs from retained provenance")
    if record.get("mapping_sha256") != sha256(mapping):
        raise ValueError("mapping differs from retained provenance")
    if Path(mapping).stat().st_size == 0:
        raise ValueError("mapping is empty")
    return actual


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("inspect", "verify", "upload"))
    parser.add_argument("--aab", required=True)
    parser.add_argument("--mapping")
    parser.add_argument("--provenance")
    parser.add_argument("--buildtools")
    args = parser.parse_args()
    if args.command == "inspect":
        print(json.dumps(identity(args.aab), sort_keys=True))
        return
    if not args.mapping or not args.provenance:
        parser.error("mapping and provenance are required")
    actual = validate(args.aab, args.mapping, args.provenance)
    if args.command == "upload":
        if not args.buildtools or sha256(args.buildtools) != BUILDTOOLS_SHA256:
            raise ValueError("Crashlytics buildtools hash mismatch")
        subprocess.run([
            "java", "-jar", args.buildtools, "-uploadMappingFile", args.mapping,
            "-mappingFileId", actual["crashlytics_mapping_id"],
            "-googleAppId", actual["firebase_app_id"], "-quiet",
        ], check=True)
        print("Verified Android Crashlytics mapping uploaded")
    else:
        print("Verified Android Crashlytics mapping identity")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.SubprocessError) as error:
        # Avoid traceback/command/path disclosure in shared workflow logs.
        print(f"Android Crashlytics mapping operation failed ({type(error).__name__})", file=sys.stderr)
        sys.exit(1)
