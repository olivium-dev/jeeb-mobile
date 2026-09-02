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


def main() -> int:
    orchestrator = (WORKFLOWS / "ci.yml").read_text()
    stages = {
        "flutter": "ci-flutter-stage.yml",
        "android": "ci-android-stage.yml",
        "ios": "ci-ios-stage.yml",
    }

    for job, filename in stages.items():
        require(
            orchestrator,
            f"uses: ./.github/workflows/{filename}",
            "ci.yml",
        )
        require(orchestrator, f"{job}:", "ci.yml")

        stage = (WORKFLOWS / filename).read_text()
        require(stage, "workflow_call:", filename)
        if re.search(r"^  (?:push|pull_request|workflow_dispatch):", stage, re.M):
            fail(f"{filename} must only be callable by ci.yml")

    require(orchestrator, "name: CI ready", "ci.yml")
    require(orchestrator, "needs: [flutter, android, ios]", "ci.yml")
    for result in ("FLUTTER_RESULT", "ANDROID_RESULT", "IOS_RESULT"):
        require(orchestrator, f'[[ "${{{result}}}" == success ]]', "ci.yml")

    release = (WORKFLOWS / "trusted-mobile-rc.yml").read_text()
    require(release, '"CI ready"', "trusted-mobile-rc.yml")
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
