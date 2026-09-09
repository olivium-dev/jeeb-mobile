#!/usr/bin/env python3
"""Create and verify deterministic file-level Flutter test shards."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path, PurePosixPath
from typing import Any, Iterable


ROOT = Path(__file__).resolve().parents[1]
PLAN_SCHEMA = 1
METADATA_SCHEMA = 1
ALGORITHM = "duration-lpt-v1"
DEFAULT_WEIGHTS = ROOT / "tool" / "test_shard_weights.json"
CAPTURE_ONLY_LIST = PurePosixPath(
    ".github/test-lists/flutter-capture-only.txt"
)
SHA_RE = re.compile(r"[0-9a-f]{40}")


class PlanError(ValueError):
    """Raised when a shard plan or artifact fails closed validation."""


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical_json(value: Any) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def _load_json_without_duplicates(path: Path) -> Any:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        result: dict[str, Any] = {}
        for key, value in pairs:
            if key in result:
                raise PlanError(f"{path}: duplicate JSON key {key!r}")
            result[key] = value
        return result

    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=reject_duplicates,
        )
    except (OSError, json.JSONDecodeError) as error:
        raise PlanError(f"cannot read {path}: {error}") from error


def _run_git(root: Path, *arguments: str) -> bytes:
    process = subprocess.run(
        ["git", *arguments],
        cwd=root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if process.returncode != 0:
        detail = process.stderr.decode(errors="replace").strip()
        raise PlanError(f"git {' '.join(arguments)} failed: {detail}")
    return process.stdout


def _validate_test_path(path: str) -> None:
    parsed = PurePosixPath(path)
    if (
        not path.startswith("test/")
        or not path.endswith("_test.dart")
        or parsed.is_absolute()
        or ".." in parsed.parts
        or "\n" in path
        or "\r" in path
    ):
        raise PlanError(f"invalid Flutter test path: {path!r}")


def tracked_tests(root: Path = ROOT) -> list[str]:
    raw_paths = _run_git(root, "ls-files", "-z", "--", "test")
    decoded = [
        value.decode("utf-8") for value in raw_paths.split(b"\0") if value
    ]
    paths = [value for value in decoded if value.endswith("_test.dart")]
    if not paths:
        raise PlanError("no tracked Flutter tests were discovered")
    if len(paths) != len(set(paths)):
        raise PlanError("git returned duplicate Flutter test paths")
    for path in paths:
        _validate_test_path(path)
        if not (root / path).is_file():
            raise PlanError(f"tracked Flutter test is absent from checkout: {path}")
    return sorted(paths)


def runnable_tests(root: Path = ROOT) -> tuple[list[str], list[str]]:
    all_tests = tracked_tests(root)
    source = root / CAPTURE_ONLY_LIST
    tracked_list = _run_git(
        root,
        "ls-files",
        "-z",
        "--",
        CAPTURE_ONLY_LIST.as_posix(),
    ).split(b"\0")
    if tracked_list != [CAPTURE_ONLY_LIST.as_posix().encode(), b""]:
        raise PlanError(
            f"capture-only list must be tracked: {CAPTURE_ONLY_LIST.as_posix()}"
        )
    try:
        listed = [
            line.strip()
            for line in source.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
    except OSError as error:
        raise PlanError(f"cannot read capture-only list {source}: {error}") from error
    duplicates = sorted(
        path for path, count in Counter(listed).items() if count > 1
    )
    if duplicates:
        raise PlanError(
            f"{source}: duplicate tests: {', '.join(duplicates)}"
        )
    tracked = set(all_tests)
    for path in listed:
        _validate_test_path(path)
        if path not in tracked:
            raise PlanError(f"{source}: test is not tracked: {path}")
    capture_only = sorted(listed)
    runnable = sorted(set(all_tests).difference(capture_only))
    if not runnable:
        raise PlanError("no non-capture Flutter tests were discovered")
    return runnable, capture_only


def load_weights(path: Path, tests: Iterable[str]) -> tuple[dict[str, int], str]:
    raw = path.read_bytes()
    value = _load_json_without_duplicates(path)
    if not isinstance(value, dict) or value.get("schema") != 1:
        raise PlanError(f"{path}: unsupported weight schema")
    durations = value.get("durations_ms")
    if not isinstance(durations, dict):
        raise PlanError(f"{path}: durations_ms must be an object")

    tracked = set(tests)
    result: dict[str, int] = {}
    for test_path, duration in durations.items():
        if not isinstance(test_path, str):
            raise PlanError(f"{path}: duration key is not a string")
        _validate_test_path(test_path)
        if test_path not in tracked:
            raise PlanError(f"{path}: weighted test is not tracked: {test_path}")
        if isinstance(duration, bool) or not isinstance(duration, (int, float)):
            raise PlanError(f"{path}: duration for {test_path} must be numeric")
        if duration <= 0:
            raise PlanError(f"{path}: duration for {test_path} must be positive")
        rounded = round(duration)
        if rounded < 1:
            raise PlanError(
                f"{path}: duration for {test_path} rounds below one millisecond"
            )
        result[test_path] = rounded
    return result, _sha256(raw)


def _manifest_bytes(paths: Iterable[str]) -> bytes:
    return "".join(f"{path}\n" for path in paths).encode()


def build_plan(
    root: Path = ROOT,
    shard_count: int = 4,
    weights_path: Path = DEFAULT_WEIGHTS,
) -> tuple[dict[str, Any], list[list[str]]]:
    if shard_count < 1:
        raise PlanError("shard count must be positive")
    tests, capture_only = runnable_tests(root)
    historical, weights_digest = load_weights(weights_path, tests)

    effective: dict[str, int] = {}
    for path in tests:
        nonblank_lines = sum(
            1
            for line in (root / path).read_text(encoding="utf-8").splitlines()
            if line.strip()
        )
        effective[path] = 1000 + max(historical.get(path, 0), 4 * nonblank_lines)

    shards: list[list[str]] = [[] for _ in range(shard_count)]
    loads = [0] * shard_count
    for path in sorted(tests, key=lambda item: (-effective[item], item)):
        index = min(
            range(shard_count),
            key=lambda item: (loads[item], len(shards[item]), item),
        )
        shards[index].append(path)
        loads[index] += effective[path]
    for shard in shards:
        shard.sort()

    flattened = [path for shard in shards for path in shard]
    if len(flattened) != len(set(flattened)) or set(flattened) != set(tests):
        raise PlanError("generated shards are not an exact partition")

    commit = _run_git(root, "rev-parse", "HEAD").decode().strip()
    if not SHA_RE.fullmatch(commit):
        raise PlanError("checkout HEAD is not a full lowercase Git SHA")
    plan: dict[str, Any] = {
        "algorithm": ALGORITHM,
        "excluded_capture_count": len(capture_only),
        "excluded_capture_sha256": _sha256(_manifest_bytes(capture_only)),
        "commit": commit,
        "schema": PLAN_SCHEMA,
        "shard_count": shard_count,
        "test_count": len(tests),
        "tests_sha256": _sha256(_manifest_bytes(tests)),
        "weights_sha256": weights_digest,
        "shards": [
            {
                "file_count": len(shards[index]),
                "index": index,
                "manifest": f"shard-{index}.txt",
                "manifest_sha256": _sha256(_manifest_bytes(shards[index])),
                "predicted_ms": loads[index],
            }
            for index in range(shard_count)
        ],
    }
    return plan, shards


def write_plan(output_dir: Path, plan: dict[str, Any], shards: list[list[str]]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / "plan.json").write_bytes(_canonical_json(plan))
    for index, paths in enumerate(shards):
        (output_dir / f"shard-{index}.txt").write_bytes(_manifest_bytes(paths))


def validate_list(root: Path, source: Path, output: Path) -> list[str]:
    runnable, _ = runnable_tests(root)
    tracked = set(runnable)
    paths = [
        line.strip()
        for line in source.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    ]
    if not paths:
        raise PlanError(f"{source}: test list is empty")
    duplicates = sorted(path for path, count in Counter(paths).items() if count > 1)
    if duplicates:
        raise PlanError(f"{source}: duplicate tests: {', '.join(duplicates)}")
    for path in paths:
        _validate_test_path(path)
        if path not in tracked:
            raise PlanError(f"{source}: test is not tracked: {path}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(_manifest_bytes(paths))
    return paths


def _read_report(
    path: Path,
    root: Path,
    expected_suites: Iterable[str],
) -> tuple[dict[str, int], list[str]]:
    results: Counter[str] = Counter()
    completed: list[bool] = []
    suites: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise PlanError(f"cannot read test report {path}: {error}") from error
    for line in lines:
        try:
            event = json.loads(line)
        except json.JSONDecodeError as error:
            raise PlanError(f"{path}: invalid JSON reporter line: {error}") from error
        if event.get("type") == "testDone":
            result = event.get("result")
            if isinstance(result, str):
                results[result] += 1
        elif event.get("type") == "done":
            completed.append(event.get("success") is True)
        elif event.get("type") == "suite":
            suite = event.get("suite")
            raw_path = suite.get("path") if isinstance(suite, dict) else None
            if not isinstance(raw_path, str):
                raise PlanError(f"{path}: suite event has no path")
            suite_path = Path(raw_path)
            if not suite_path.is_absolute():
                suite_path = root / suite_path
            try:
                relative = (
                    suite_path.resolve().relative_to(root.resolve()).as_posix()
                )
            except ValueError as error:
                raise PlanError(
                    f"{path}: suite is outside the checkout: {raw_path}"
                ) from error
            _validate_test_path(relative)
            suites.append(relative)
    if completed != [True]:
        raise PlanError(f"{path}: reporter did not finish exactly once with success")
    duplicate_suites = sorted(
        suite for suite, count in Counter(suites).items() if count > 1
    )
    if duplicate_suites:
        raise PlanError(
            f"{path}: reporter repeated suites: {', '.join(duplicate_suites)}"
        )
    expected = sorted(expected_suites)
    actual = sorted(suites)
    if actual != expected:
        missing = sorted(set(expected).difference(actual))
        extra = sorted(set(actual).difference(expected))
        detail = []
        if missing:
            detail.append("missing suites: " + ", ".join(missing))
        if extra:
            detail.append("unexpected suites: " + ", ".join(extra))
        raise PlanError(f"{path}: " + "; ".join(detail))
    return dict(sorted(results.items())), actual


def _validate_run_identity(run_id: int, run_attempt: int) -> None:
    for label, value in (("run ID", run_id), ("run attempt", run_attempt)):
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise PlanError(f"{label} must be a positive integer")


def record_artifact(
    root: Path,
    plan_dir: Path,
    shard_index: int,
    coverage: Path,
    report: Path,
    expected_sha: str,
    run_id: int,
    run_attempt: int,
    output: Path,
) -> None:
    _validate_run_identity(run_id, run_attempt)
    if not SHA_RE.fullmatch(expected_sha):
        raise PlanError("expected SHA must be 40 lowercase hexadecimal characters")
    plan_bytes = (plan_dir / "plan.json").read_bytes()
    plan = json.loads(plan_bytes)
    if plan.get("commit") != expected_sha:
        raise PlanError("test plan commit does not match the workflow SHA")
    if shard_index not in range(plan.get("shard_count", 0)):
        raise PlanError("shard index is outside the test plan")
    manifest = plan_dir / f"shard-{shard_index}.txt"
    manifest_bytes = manifest.read_bytes()
    manifest_paths = manifest_bytes.decode("utf-8").splitlines()
    coverage_bytes = coverage.read_bytes()
    if (
        not coverage_bytes
        or b"SF:" not in coverage_bytes
        or b"DA:" not in coverage_bytes
    ):
        raise PlanError(f"{coverage}: LCOV report has no source/line records")
    results, suites = _read_report(report, root, manifest_paths)
    metadata = {
        "coverage_sha256": _sha256(coverage_bytes),
        "manifest_sha256": _sha256(manifest_bytes),
        "plan_sha256": _sha256(plan_bytes),
        "report_sha256": _sha256(report.read_bytes()),
        "run_attempt": run_attempt,
        "run_id": run_id,
        "schema": METADATA_SCHEMA,
        "sha": expected_sha,
        "shard_count": plan["shard_count"],
        "shard_index": shard_index,
        "suite_count": len(suites),
        "suite_paths_sha256": _sha256(_manifest_bytes(suites)),
        "test_results": results,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(_canonical_json(metadata))


def verify_artifacts(
    root: Path,
    weights_path: Path,
    artifact_root: Path,
    shard_count: int,
    expected_sha: str,
    run_id: int,
    run_attempt: int,
) -> None:
    _validate_run_identity(run_id, run_attempt)
    if not SHA_RE.fullmatch(expected_sha):
        raise PlanError("expected SHA must be 40 lowercase hexadecimal characters")
    expected_plan, expected_shards = build_plan(root, shard_count, weights_path)
    if expected_plan["commit"] != expected_sha:
        raise PlanError("checked-out commit does not match the workflow SHA")
    expected_plan_bytes = _canonical_json(expected_plan)

    artifact_entries = list(artifact_root.iterdir())
    expected_names = [
        f"flutter-coverage-run-{run_id}-attempt-{run_attempt}-shard-{index}"
        for index in range(shard_count)
    ]
    if (
        any(not path.is_dir() for path in artifact_entries)
        or {path.name for path in artifact_entries} != set(expected_names)
    ):
        raise PlanError(
            "coverage artifacts must be exactly: " + ", ".join(expected_names)
        )

    seen: list[str] = []
    artifacts = {path.name: path for path in artifact_entries}
    for index, artifact_name in enumerate(expected_names):
        artifact = artifacts[artifact_name]
        plan_path = artifact / "build" / "ci" / "test-plan" / "plan.json"
        manifest_path = (
            artifact / "build" / "ci" / "test-plan" / f"shard-{index}.txt"
        )
        metadata_path = (
            artifact
            / "build"
            / "ci"
            / "test-plan"
            / f"metadata-{index}.json"
        )
        coverage_path = artifact / "coverage" / f"shard-{index}.info"
        report_path = artifact / "test-results" / f"shard-{index}.json"
        if plan_path.read_bytes() != expected_plan_bytes:
            raise PlanError(f"{artifact.name}: plan differs from the checkout")
        expected_manifest = _manifest_bytes(expected_shards[index])
        if manifest_path.read_bytes() != expected_manifest:
            raise PlanError(f"{artifact.name}: shard manifest differs from the plan")

        results, suites = _read_report(report_path, root, expected_shards[index])
        metadata = _load_json_without_duplicates(metadata_path)
        expected_metadata = {
            "coverage_sha256": _sha256(coverage_path.read_bytes()),
            "manifest_sha256": _sha256(expected_manifest),
            "plan_sha256": _sha256(expected_plan_bytes),
            "report_sha256": _sha256(report_path.read_bytes()),
            "run_attempt": run_attempt,
            "run_id": run_id,
            "schema": METADATA_SCHEMA,
            "sha": expected_sha,
            "shard_count": shard_count,
            "shard_index": index,
            "suite_count": len(suites),
            "suite_paths_sha256": _sha256(_manifest_bytes(suites)),
            "test_results": results,
        }
        if metadata != expected_metadata:
            invalid = sorted(
                key
                for key in set(metadata).union(expected_metadata)
                if metadata.get(key) != expected_metadata.get(key)
            )
            raise PlanError(
                f"{artifact.name}: invalid metadata fields: {', '.join(invalid)}"
            )
        coverage_bytes = coverage_path.read_bytes()
        if (
            not coverage_bytes
            or b"SF:" not in coverage_bytes
            or b"DA:" not in coverage_bytes
        ):
            raise PlanError(f"{artifact.name}: LCOV report has no source/line records")
        seen.extend(manifest_path.read_text(encoding="utf-8").splitlines())

    expected_tests, _ = runnable_tests(root)
    if len(seen) != len(set(seen)):
        raise PlanError("downloaded shard manifests overlap")
    if sorted(seen) != expected_tests:
        raise PlanError(
            "downloaded shard manifests do not cover every non-capture test"
        )


def _path(value: str) -> Path:
    return Path(value).resolve()


def _positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return parsed


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=_path, default=ROOT)
    subparsers = parser.add_subparsers(dest="command", required=True)

    plan = subparsers.add_parser("plan")
    plan.add_argument("--shards", type=int, default=4)
    plan.add_argument("--weights", type=_path, default=DEFAULT_WEIGHTS)
    plan.add_argument("--output-dir", type=_path, required=True)

    listed = subparsers.add_parser("validate-list")
    listed.add_argument("--list", dest="source", type=_path, required=True)
    listed.add_argument("--output", type=_path, required=True)

    record = subparsers.add_parser("record")
    record.add_argument("--plan-dir", type=_path, required=True)
    record.add_argument("--shard", type=int, required=True)
    record.add_argument("--coverage", type=_path, required=True)
    record.add_argument("--report", type=_path, required=True)
    record.add_argument("--sha", required=True)
    record.add_argument("--run-id", type=_positive_int, required=True)
    record.add_argument("--run-attempt", type=_positive_int, required=True)
    record.add_argument("--output", type=_path, required=True)

    verify = subparsers.add_parser("verify-artifacts")
    verify.add_argument("--weights", type=_path, default=DEFAULT_WEIGHTS)
    verify.add_argument("--artifact-root", type=_path, required=True)
    verify.add_argument("--shards", type=int, default=4)
    verify.add_argument("--sha", required=True)
    verify.add_argument("--run-id", type=_positive_int, required=True)
    verify.add_argument("--run-attempt", type=_positive_int, required=True)
    return parser


def main() -> int:
    arguments = _parser().parse_args()
    try:
        if arguments.command == "plan":
            plan, shards = build_plan(
                arguments.root,
                arguments.shards,
                arguments.weights,
            )
            write_plan(arguments.output_dir, plan, shards)
            print(
                f"Planned {plan['test_count']} non-capture tests across "
                f"{plan['shard_count']} deterministic shards."
            )
        elif arguments.command == "validate-list":
            paths = validate_list(
                arguments.root,
                arguments.source,
                arguments.output,
            )
            print(f"Validated {len(paths)} tracked tests from {arguments.source}.")
        elif arguments.command == "record":
            record_artifact(
                arguments.root,
                arguments.plan_dir,
                arguments.shard,
                arguments.coverage,
                arguments.report,
                arguments.sha,
                arguments.run_id,
                arguments.run_attempt,
                arguments.output,
            )
            print(f"Recorded fail-closed metadata for shard {arguments.shard}.")
        elif arguments.command == "verify-artifacts":
            verify_artifacts(
                arguments.root,
                arguments.weights,
                arguments.artifact_root,
                arguments.shards,
                arguments.sha,
                arguments.run_id,
                arguments.run_attempt,
            )
            print(f"Verified all {arguments.shards} coverage shard artifacts.")
        else:  # pragma: no cover - argparse makes this unreachable.
            raise PlanError(f"unsupported command: {arguments.command}")
    except (OSError, PlanError, ValueError) as error:
        raise SystemExit(f"Flutter test shard plan rejected: {error}") from error
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
