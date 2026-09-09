#!/usr/bin/env python3
"""Unit tests for the deterministic Flutter test shard planner."""

from __future__ import annotations

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

import plan_test_shards as planner


class TestShardPlannerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _write(self, path: str, content: str) -> Path:
        destination = self.root / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(content, encoding="utf-8")
        return destination

    def _commit_tests(self, count: int = 8) -> list[str]:
        capture_list = self.root / planner.CAPTURE_ONLY_LIST
        if not capture_list.exists():
            self._write(planner.CAPTURE_ONLY_LIST.as_posix(), "")
        paths = []
        for index in range(count):
            path = f"test/area_{index}/case_{index}_test.dart"
            self._write(path, "void main() {\n  // test body\n}\n" * (index + 1))
            paths.append(path)
        subprocess.run(
            [
                "git",
                "add",
                "test",
                planner.CAPTURE_ONLY_LIST.as_posix(),
            ],
            cwd=self.root,
            check=True,
        )
        subprocess.run(
            [
                "git",
                "-c",
                "user.name=CI Test",
                "-c",
                "user.email=ci@example.invalid",
                "commit",
                "-qm",
                "fixtures",
            ],
            cwd=self.root,
            check=True,
        )
        return paths

    def _weights(self, durations: dict[str, int] | None = None) -> Path:
        return self._write(
            "weights.json",
            json.dumps({"schema": 1, "durations_ms": durations or {}}) + "\n",
        )

    def _report(self, paths: list[str], *, success: bool = True) -> str:
        events = [
            {
                "type": "suite",
                "suite": {"id": index, "path": str((self.root / path).resolve())},
            }
            for index, path in enumerate(paths)
        ]
        events.extend(
            [
                {"type": "testDone", "result": "success"},
                {"type": "done", "success": success},
            ]
        )
        return "".join(json.dumps(event) + "\n" for event in events)

    def test_plan_is_deterministic_complete_and_disjoint(self) -> None:
        tests = self._commit_tests()
        weights = self._weights({tests[-1]: 50000})
        first, first_shards = planner.build_plan(self.root, 4, weights)
        second, second_shards = planner.build_plan(self.root, 4, weights)

        self.assertEqual(first, second)
        self.assertEqual(first_shards, second_shards)
        flattened = [path for shard in first_shards for path in shard]
        self.assertCountEqual(flattened, tests)
        self.assertEqual(len(flattened), len(set(flattened)))
        heavy_shard = next(shard for shard in first_shards if tests[-1] in shard)
        self.assertEqual(heavy_shard, [tests[-1]])

    def test_duplicate_weight_key_is_rejected(self) -> None:
        tests = self._commit_tests(1)
        weights = self._write(
            "weights.json",
            '{"schema":1,"durations_ms":{"%s":1,"%s":2}}\n'
            % (tests[0], tests[0]),
        )
        with self.assertRaisesRegex(planner.PlanError, "duplicate JSON key"):
            planner.build_plan(self.root, 1, weights)

    def test_allowlist_must_be_tracked_and_unique(self) -> None:
        tests = self._commit_tests(2)
        source = self._write("list.txt", f"{tests[0]}\n{tests[0]}\n")
        with self.assertRaisesRegex(planner.PlanError, "duplicate tests"):
            planner.validate_list(self.root, source, self.root / "out.txt")

        source.write_text("test/missing_test.dart\n", encoding="utf-8")
        with self.assertRaisesRegex(planner.PlanError, "not tracked"):
            planner.validate_list(self.root, source, self.root / "out.txt")

    def test_file_level_capture_suite_is_excluded_from_regression(self) -> None:
        capture = self._write(
            "test/tools/capture_only_test.dart",
            "@Tags(<String>['capture'])\nlibrary;\n",
        )
        self._write(
            planner.CAPTURE_ONLY_LIST.as_posix(),
            "test/tools/capture_only_test.dart\n",
        )
        tests = self._commit_tests(2)
        plan, shards = planner.build_plan(self.root, 2, self._weights())

        flattened = [path for shard in shards for path in shard]
        self.assertCountEqual(flattened, tests)
        self.assertNotIn(capture.relative_to(self.root).as_posix(), flattened)
        self.assertEqual(plan["excluded_capture_count"], 1)

    def test_commented_capture_example_does_not_exclude_a_suite(self) -> None:
        commented = self._write(
            "test/tools/commented_capture_test.dart",
            "// Example only: @Tags(['capture']) library;\nvoid main() {}\n",
        )
        tests = self._commit_tests(1)
        plan, shards = planner.build_plan(self.root, 1, self._weights())

        flattened = [path for shard in shards for path in shard]
        self.assertCountEqual(
            flattened,
            [*tests, commented.relative_to(self.root).as_posix()],
        )
        self.assertEqual(plan["excluded_capture_count"], 0)

    def test_capture_only_list_must_be_tracked(self) -> None:
        tests = self._commit_tests(1)
        subprocess.run(
            ["git", "rm", "--cached", planner.CAPTURE_ONLY_LIST.as_posix()],
            cwd=self.root,
            check=True,
            stdout=subprocess.DEVNULL,
        )

        with self.assertRaisesRegex(planner.PlanError, "must be tracked"):
            planner.build_plan(self.root, 1, self._weights({tests[0]: 1000}))

    def test_record_rejects_a_report_that_omits_a_manifest_suite(self) -> None:
        tests = self._commit_tests(2)
        plan, shards = planner.build_plan(self.root, 1, self._weights())
        plan_dir = self.root / "generated-plan"
        planner.write_plan(plan_dir, plan, shards)
        coverage = self._write(
            "coverage.info",
            "TN:\nSF:lib/app.dart\nDA:1,1\nend_of_record\n",
        )
        report = self._write("report.json", self._report(tests[:1]))

        with self.assertRaisesRegex(planner.PlanError, "missing suites"):
            planner.record_artifact(
                self.root,
                plan_dir,
                0,
                coverage,
                report,
                plan["commit"],
                123,
                1,
                self.root / "metadata.json",
            )

    def test_artifacts_are_bound_to_plan_commit_and_digests(self) -> None:
        self._commit_tests(4)
        weights = self._weights()
        plan, shards = planner.build_plan(self.root, 2, weights)
        plan_dir = self.root / "generated-plan"
        planner.write_plan(plan_dir, plan, shards)
        artifact_root = self.root / "artifacts"
        run_id = 9876
        run_attempt = 2

        for index in range(2):
            artifact = (
                artifact_root
                / f"flutter-coverage-run-{run_id}-attempt-{run_attempt}-shard-{index}"
            )
            artifact_plan = artifact / "build" / "ci" / "test-plan"
            artifact_plan.mkdir(parents=True)
            shutil.copy2(plan_dir / "plan.json", artifact_plan / "plan.json")
            shutil.copy2(
                plan_dir / f"shard-{index}.txt",
                artifact_plan / f"shard-{index}.txt",
            )
            coverage = artifact / "coverage" / f"shard-{index}.info"
            coverage.parent.mkdir()
            coverage.write_text("TN:\nSF:lib/app.dart\nDA:1,1\nend_of_record\n", encoding="utf-8")
            report = artifact / "test-results" / f"shard-{index}.json"
            report.parent.mkdir()
            report.write_text(self._report(shards[index]), encoding="utf-8")
            planner.record_artifact(
                self.root,
                artifact_plan,
                index,
                coverage,
                report,
                plan["commit"],
                run_id,
                run_attempt,
                artifact_plan / f"metadata-{index}.json",
            )

        planner.verify_artifacts(
            self.root,
            weights,
            artifact_root,
            2,
            plan["commit"],
            run_id,
            run_attempt,
        )
        broken = (
            artifact_root
            / f"flutter-coverage-run-{run_id}-attempt-{run_attempt}-shard-1"
            / "coverage"
            / "shard-1.info"
        )
        broken.write_text("TN:\n", encoding="utf-8")
        with self.assertRaisesRegex(planner.PlanError, "invalid metadata fields"):
            planner.verify_artifacts(
                self.root,
                weights,
                artifact_root,
                2,
                plan["commit"],
                run_id,
                run_attempt,
            )


if __name__ == "__main__":
    unittest.main()
