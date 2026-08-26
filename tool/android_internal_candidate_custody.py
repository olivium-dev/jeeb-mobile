#!/usr/bin/env python3
"""Create and extract the fixed Android internal-candidate custody archives."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import sys
import zipfile
from pathlib import Path
from typing import BinaryIO, Final


CHUNK_SIZE: Final = 1024 * 1024
INNER_FILES: Final = {
    "candidate.aab": 512 * 1024 * 1024,
    "output-metadata.json": 1024 * 1024,
    "mapping.txt": 256 * 1024 * 1024,
    "provenance.json": 1024 * 1024,
}
OUTER_FILES: Final = {"candidate.cms": 800 * 1024 * 1024}


class CustodyError(RuntimeError):
    """A fail-closed custody contract violation."""


def _fail(message: str) -> None:
    raise CustodyError(message)


def _exclusive_output(path: Path) -> BinaryIO:
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    descriptor = os.open(path, flags, 0o600)
    return os.fdopen(descriptor, "wb")


def _regular_source(path: Path, maximum: int) -> tuple[BinaryIO, int]:
    flags = os.O_RDONLY
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError as error:
        _fail(f"candidate input is unavailable: {error.strerror}")
    source_stat = os.fstat(descriptor)
    if not stat.S_ISREG(source_stat.st_mode):
        os.close(descriptor)
        _fail("candidate input is not a regular file")
    if source_stat.st_size <= 0 or source_stat.st_size > maximum:
        os.close(descriptor)
        _fail("candidate input size is outside the approved boundary")
    return os.fdopen(descriptor, "rb"), source_stat.st_size


def _inner_info(name: str) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.compress_type = zipfile.ZIP_STORED
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o600) << 16
    return info


def _validate_entries(
    archive: zipfile.ZipFile,
    expected: dict[str, int],
    *,
    require_canonical_inner: bool,
) -> list[zipfile.ZipInfo]:
    entries = archive.infolist()
    names = [entry.filename for entry in entries]
    if len(entries) != len(expected) or set(names) != set(expected):
        _fail("archive must contain the exact approved file set once")
    if len(names) != len(set(names)):
        _fail("archive contains a duplicate entry")
    for entry in entries:
        if entry.is_dir() or entry.flag_bits & 0x1:
            _fail("archive entry type is not allowed")
        if entry.file_size <= 0 or entry.file_size > expected[entry.filename]:
            _fail("archive entry size is outside the approved boundary")
        if entry.compress_size > expected[entry.filename]:
            _fail("archive compressed size is outside the approved boundary")
        mode = (entry.external_attr >> 16) & 0xFFFF
        if stat.S_ISLNK(mode):
            _fail("archive symlinks are forbidden")
        if require_canonical_inner:
            if entry.compress_type != zipfile.ZIP_STORED:
                _fail("inner archive entries must use canonical storage")
            if entry.create_system != 3 or not stat.S_ISREG(mode):
                _fail("inner archive entry metadata is not canonical")
            if entry.compress_size != entry.file_size:
                _fail("inner archive storage length is inconsistent")
        elif entry.compress_type not in {
            zipfile.ZIP_STORED,
            zipfile.ZIP_DEFLATED,
        }:
            _fail("artifact archive compression is not approved")
    return entries


def _open_validated(
    path: Path,
    expected: dict[str, int],
    *,
    require_canonical_inner: bool,
) -> tuple[zipfile.ZipFile, list[zipfile.ZipInfo]]:
    source, _ = _regular_source(path, sum(expected.values()) + 64 * 1024 * 1024)
    source.close()
    try:
        archive = zipfile.ZipFile(path, "r")
        entries = _validate_entries(
            archive,
            expected,
            require_canonical_inner=require_canonical_inner,
        )
        if archive.testzip() is not None:
            _fail("archive entry checksum is invalid")
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        if "archive" in locals():
            archive.close()
        if isinstance(error, CustodyError):
            raise
        _fail(f"archive is invalid: {type(error).__name__}")
    return archive, entries


def _copy_entry(
    archive: zipfile.ZipFile,
    entry: zipfile.ZipInfo,
    destination: Path,
    maximum: int,
) -> None:
    written = 0
    try:
        with archive.open(entry, "r") as source, _exclusive_output(destination) as target:
            while True:
                chunk = source.read(CHUNK_SIZE)
                if not chunk:
                    break
                written += len(chunk)
                if written > maximum:
                    _fail("extracted entry exceeds the approved boundary")
                target.write(chunk)
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        if isinstance(error, CustodyError):
            raise
        _fail(f"archive extraction failed: {type(error).__name__}")
    if written != entry.file_size:
        _fail("extracted entry length does not match its archive record")


def pack_inner(arguments: argparse.Namespace) -> None:
    output = Path(arguments.output)
    if output.exists():
        _fail("inner archive output already exists")
    inputs = {
        "candidate.aab": Path(arguments.aab),
        "output-metadata.json": Path(arguments.metadata),
        "mapping.txt": Path(arguments.mapping),
        "provenance.json": Path(arguments.provenance),
    }
    try:
        with zipfile.ZipFile(
            output,
            mode="x",
            compression=zipfile.ZIP_STORED,
            allowZip64=True,
        ) as archive:
            for name in INNER_FILES:
                source, source_size = _regular_source(inputs[name], INNER_FILES[name])
                info = _inner_info(name)
                info.file_size = source_size
                with source, archive.open(info, "w", force_zip64=True) as target:
                    shutil.copyfileobj(source, target, length=CHUNK_SIZE)
        os.chmod(output, 0o600)
        archive, _ = _open_validated(
            output,
            INNER_FILES,
            require_canonical_inner=True,
        )
        archive.close()
    except Exception:
        output.unlink(missing_ok=True)
        raise


def extract_inner(arguments: argparse.Namespace) -> None:
    destination = Path(arguments.output_dir)
    if destination.exists():
        _fail("private extraction directory already exists")
    destination.mkdir(mode=0o700, parents=False)
    try:
        archive, entries = _open_validated(
            Path(arguments.archive),
            INNER_FILES,
            require_canonical_inner=True,
        )
        with archive:
            by_name = {entry.filename: entry for entry in entries}
            for name, maximum in INNER_FILES.items():
                _copy_entry(archive, by_name[name], destination / name, maximum)
    except Exception:
        shutil.rmtree(destination, ignore_errors=True)
        raise


def extract_artifact(arguments: argparse.Namespace) -> None:
    output = Path(arguments.output)
    if output.exists():
        _fail("ciphertext output already exists")
    archive, entries = _open_validated(
        Path(arguments.archive),
        OUTER_FILES,
        require_canonical_inner=False,
    )
    try:
        with archive:
            _copy_entry(archive, entries[0], output, OUTER_FILES["candidate.cms"])
    except Exception:
        output.unlink(missing_ok=True)
        raise


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(add_help=True)
    commands = parser.add_subparsers(dest="command", required=True)

    pack = commands.add_parser("pack-inner")
    pack.add_argument("--aab", required=True)
    pack.add_argument("--metadata", required=True)
    pack.add_argument("--mapping", required=True)
    pack.add_argument("--provenance", required=True)
    pack.add_argument("--output", required=True)
    pack.set_defaults(handler=pack_inner)

    extract = commands.add_parser("extract-inner")
    extract.add_argument("--archive", required=True)
    extract.add_argument("--output-dir", required=True)
    extract.set_defaults(handler=extract_inner)

    artifact = commands.add_parser("extract-artifact")
    artifact.add_argument("--archive", required=True)
    artifact.add_argument("--output", required=True)
    artifact.set_defaults(handler=extract_artifact)
    return parser


def main() -> int:
    try:
        arguments = _parser().parse_args()
        arguments.handler(arguments)
    except CustodyError as error:
        print(f"Android candidate custody rejected: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
