#!/usr/bin/env python3
"""Verify the maintainable CI stage split and its stable release gate."""

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


def job_block(source: str, job: str) -> str:
    match = re.search(rf"^  {re.escape(job)}:\s*$", source, re.M)
    if match is None:
        fail(f"ci.yml is missing job {job!r}")
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
        call = job_block(orchestrator, job)
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
            job_block(orchestrator, platform),
            "needs: flutter",
            f"ci.yml job {platform}",
        )

    ready = job_block(orchestrator, "ready")
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

    print("CI topology verified: Flutter -> Android/iOS -> CI ready.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
