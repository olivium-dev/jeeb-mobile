#!/usr/bin/env python3
"""Verify the parallel CI graph and its stable release gates."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
WORKFLOWS = ROOT / ".github" / "workflows"


def fail(message: str) -> None:
    raise SystemExit(f"CI topology rejected: {message}")


def require(source: str, fragment: str, location: str) -> None:
    if fragment not in source:
        fail(f"{location} is missing {fragment!r}")


def job_block(source: str, job: str, location: str = "workflow") -> str:
    match = re.search(rf"^  {re.escape(job)}:\s*$", source, re.M)
    if match is None:
        fail(f"{location} is missing job {job!r}")
    remainder = source[match.end() :]
    next_job = re.search(r"^  [A-Za-z0-9_-]+:\s*$", remainder, re.M)
    return remainder[: next_job.start()] if next_job else remainder


def main() -> int:
    orchestrator = (WORKFLOWS / "ci.yml").read_text()
    stages = {
        "flutter": "ci-flutter-stage.yml",
        "android": "ci-android-stage.yml",
        "ios": "ci-ios-stage.yml",
    }

    for job, filename in stages.items():
        call = job_block(orchestrator, job, "ci.yml")
        require(
            call,
            f"uses: ./.github/workflows/{filename}",
            f"ci.yml job {job}",
        )

        stage = (WORKFLOWS / filename).read_text()
        require(stage, "workflow_call:", filename)
        if re.search(r"^  (?:push|pull_request|workflow_dispatch):", stage, re.M):
            fail(f"{filename} must only be callable by ci.yml")

    for platform in ("android", "ios"):
        require(
            job_block(orchestrator, platform, "ci.yml"),
            "needs: flutter",
            f"ci.yml job {platform}",
        )

    flutter_stage = (WORKFLOWS / "ci-flutter-stage.yml").read_text()
    require(flutter_stage, "dart analyze --fatal-infos .", "ci-flutter-stage.yml")
    if "flutter test" in flutter_stage:
        fail("ci-flutter-stage.yml must stay analyze-only")

    ios_stage = (WORKFLOWS / "ci-ios-stage.yml").read_text()
    for job in ("dev-firebase-contracts", "release-contracts"):
        block = job_block(ios_stage, job, "ci-ios-stage.yml")
        require(block, "runs-on: macos-26", f"ci-ios-stage.yml job {job}")
        if re.search(r"^    needs:", block, re.M):
            fail(f"ci-ios-stage.yml job {job} must run independently")
    require(
        job_block(ios_stage, "dev-firebase-contracts", "ci-ios-stage.yml"),
        "bash tool/build_ios_dev_firebase_contract.sh",
        "iOS dev Firebase contracts",
    )
    require(
        job_block(ios_stage, "release-contracts", "ci-ios-stage.yml"),
        "bash tool/build_unsigned_ios_release_contract.sh",
        "iOS release contracts",
    )

    ready = job_block(orchestrator, "ready", "ci.yml")
    require(ready, "name: CI ready", "ci.yml job ready")
    require(ready, "if: ${{ always() }}", "ci.yml job ready")
    require(ready, "needs: [flutter, android, ios]", "ci.yml job ready")
    results = {
        "FLUTTER_RESULT": "flutter",
        "ANDROID_RESULT": "android",
        "IOS_RESULT": "ios",
    }
    for result, dependency in results.items():
        require(
            ready,
            f"{result}: ${{{{ needs.{dependency}.result }}}}",
            "ci.yml job ready",
        )
        require(ready, f'[[ "${{{result}}}" == success ]]', "ci.yml job ready")

    coverage = (WORKFLOWS / "flutter-ci.yml").read_text()
    require(coverage, "group: flutter-ci-${{ github.ref }}", "flutter-ci.yml")
    require(coverage, "cancel-in-progress: true", "flutter-ci.yml")
    regression = job_block(coverage, "regression", "flutter-ci.yml")
    require(regression, "fail-fast: false", "Flutter regression matrix")
    require(regression, "max-parallel: 4", "Flutter regression matrix")
    require(regression, "--coverage-path=", "Flutter regression matrix")
    require(regression, "--exclude-tags capture", "Flutter regression matrix")
    require(regression, "tool/plan_test_shards.py plan", "Flutter regression matrix")
    require(regression, "--run-id", "Flutter regression artifact provenance")
    require(regression, "--run-attempt", "Flutter regression artifact provenance")
    require(
        regression,
        "flutter-coverage-run-${{ github.run_id }}-attempt-${{ github.run_attempt }}",
        "Flutter regression artifacts",
    )
    require(
        regression,
        "Upload failed shard diagnostics",
        "Flutter regression diagnostics",
    )
    for index in range(4):
        require(regression, f"index: {index}", "Flutter regression matrix")

    smoke = job_block(coverage, "smoke", "flutter-ci.yml")
    require(smoke, "flutter-smoke.txt", "Flutter smoke job")
    staging = job_block(coverage, "staging-variant", "flutter-ci.yml")
    for define in ("JEEB_DEVTOOL_ENABLED=true", "JEEB_OBS_OVERLAY=true"):
        require(staging, define, "Flutter staging variant job")

    coverage_gate = job_block(coverage, "coverage", "flutter-ci.yml")
    require(
        coverage_gate,
        "name: Flutter CI + coverage (79%)",
        "Flutter coverage gate",
    )
    require(coverage_gate, "if: ${{ always() }}", "Flutter coverage gate")
    require(
        coverage_gate,
        "needs: [smoke, staging-variant, regression]",
        "Flutter coverage gate",
    )
    for result in ("SMOKE_RESULT", "STAGING_RESULT", "REGRESSION_RESULT"):
        require(
            coverage_gate,
            f'[[ "${{{result}}}" == success ]]',
            "Flutter coverage gate",
        )
    for fragment in (
        "actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093",
        "merge-multiple: false",
        "tool/plan_test_shards.py verify-artifacts",
        "--run-id",
        "--run-attempt",
        "--add-tracefile",
        "min_coverage: 79",
    ):
        require(coverage_gate, fragment, "Flutter coverage gate")

    release = (WORKFLOWS / "trusted-mobile-rc.yml").read_text()
    for fragment in (
        "actions/workflows/ci.yml/runs?",
        '.head_branch == "main"',
        '.event == "push"',
        '.path == ".github/workflows/ci.yml"',
        "max_by(.run_number)",
        '.conclusion == "success"',
    ):
        require(release, fragment, "trusted-mobile-rc.yml")
    if '"CI ready"' in release:
        fail("release policy must bind the CI workflow, not trust a check name")
    for old_context in (
        '"Analyze"',
        '"Test"',
        '"Build APK (dev)"',
        '"Android release signing contracts"',
        '"iOS release contracts"',
    ):
        if old_context in release:
            fail(f"release policy still depends on internal job {old_context}")

    print(
        "CI topology verified: Analyze -> Android/iOS, four coverage shards "
        "-> fail-closed 79% gate."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
