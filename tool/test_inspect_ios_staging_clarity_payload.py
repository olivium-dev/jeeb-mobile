#!/usr/bin/env python3
import pathlib
import subprocess
import tempfile
import unittest

SCRIPT = pathlib.Path(__file__).with_name('inspect_ios_staging_clarity_payload.sh')


class CapturePayloadTests(unittest.TestCase):
    def test_required_application_markers(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = pathlib.Path(directory) / 'App'
            for payload, accepted in (
                (b'\x00y6laxxj143\x00jeeb-clarity-sdk\x00', True),
                (b'\x00jeeb-clarity-sdk\x00', False),
                (b'\x00y6laxxj143\x00', False),
                (b'\x00otherproject\x00jeeb-clarity-sdk\x00', False),
                (b'', False),
            ):
                with self.subTest(payload=payload):
                    binary.write_bytes(payload)
                    result = subprocess.run(['bash', str(SCRIPT), str(binary)],
                                            capture_output=True)
                    self.assertEqual(result.returncode == 0, accepted)
            binary.unlink()
            self.assertNotEqual(subprocess.run(
                ['bash', str(SCRIPT), str(binary)], capture_output=True).returncode, 0)


if __name__ == '__main__':
    unittest.main()
