"""Fail closed if the audited fixed lane or isolated workflow boundary changes."""
import hashlib
import os
from pathlib import Path
import subprocess
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    'fastlane/Fastfile': '2e2acce91d7f9d5ea82808cc17caa26778796f7d7a866a5efa8a874015b25791',
    'fastlane/AppStoreBuildInventory.rb': 'b9ff0ffcba0b723b94d3014ce340139b5cf9690b65c577429770cf4d48467fb9',
}


class PreflightContracts(unittest.TestCase):
    def test_actual_owner_and_protected_ref_shell_rejects_wrong_authority(self):
        source = (ROOT / '.github/workflows/mobile-store-inventory-preflight.yml').read_text()
        block = textwrap.dedent(source.split('run: |\n', 1)[1].split('\n      -', 1)[0])
        valid = dict(GITHUB_EVENT_NAME='workflow_dispatch', GITHUB_REPOSITORY='olivium-dev/jeeb-mobile',
                     GITHUB_REF='refs/heads/main', REF_PROTECTED='true',
                     REQUESTING_ACTOR='oudaykhaled', TRIGGERING_ACTOR='oudaykhaled')
        for key in (None, *valid):
            environment = dict(os.environ, **valid)
            if key:
                environment[key] = 'wrong'
            result = subprocess.run(['bash', '-euc', block], env=environment, capture_output=True, timeout=5)
            self.assertEqual(key is None, result.returncode == 0)

    def test_reviewed_lane_and_paginated_asc_reader_are_unchanged(self):
        # Any future lane action needs explicit review before this workflow can
        # consume credentials. Existing release lanes are not modified here.
        for path, expected in EXPECTED.items():
            self.assertEqual(expected, hashlib.sha256((ROOT / path).read_bytes()).hexdigest())

    def test_workflow_has_one_isolated_job_and_exact_custody_gates(self):
        source = (ROOT / '.github/workflows/mobile-store-inventory-preflight.yml').read_text()
        for marker in ('environment: mobile-rc', 'permissions:\n  actions: read\n  contents: read',
                       '"$REF_PROTECTED" == true', '"$REQUESTING_ACTOR" == oudaykhaled',
                       '"$TRIGGERING_ACTOR" == oudaykhaled', '"$REVIEWED_SHA" == "$GITHUB_SHA"',
                       'select(.protected == true)', 'persist-credentials: false',
                       'bundle exec ruby tool/run_store_inventory_preflight.rb'):
            self.assertIn(marker, source)
        self.assertEqual(1, source.count('runs-on:'))
        for forbidden in ('needs:', 'secrets: inherit', 'upload-artifact', 'workflow_call:',
                          'flutter build', 'xcodebuild', 'gradlew', 'JEEB_CLARITY',
                          'fastlane ios', 'fastlane android', 'write-all'):
            self.assertNotIn(forbidden, source)

    def test_fixed_lane_only_and_no_output_of_provider_errors(self):
        source = (ROOT / 'tool/run_store_inventory_preflight.rb').read_text()
        self.assertEqual(1, source.count('fastfile.runner.execute('))
        self.assertIn("fastfile.runner.execute('preflight_internal', nil)", source)
        self.assertNotIn('LaneManager.cruise_lane', source)
        self.assertNotIn('ARGV', source)
        self.assertIn('STDOUT.reopen(File::NULL', source)
        self.assertIn('STDERR.reopen(File::NULL', source)
        self.assertNotIn('.message', source)
        self.assertIn('StorePreflightSafety.guard_play_mutations!(Supply::Client::SERVICE)', source)


if __name__ == '__main__':
    unittest.main()
