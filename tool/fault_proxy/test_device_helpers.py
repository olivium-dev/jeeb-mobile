import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from device import helpers


SAFE_XML = b'<?xml version="1.0"?><hierarchy><node resource-id="customer_profile_load_error" text="Try again" bounds="[0,0][20,40]"/></hierarchy>'
LOGCAT = (
    "01-01 00:00:00.000 I flutter : [http\u2192] GET /v1/users/me headers={authorization: tok:ab12~cd34} body=null\n"
    "01-01 00:00:00.100 I flutter : [http\u2717] 503 GET /v1/users/me body=<binary 12 bytes>\n"
    "01-01 00:00:00.200 I flutter : [http\u2717] 503 GET /v1/users/me body=<binary 12 bytes>\n"
    "01-01 00:00:00.300 I flutter : an unrelated flutter print\n"
).encode()


class HelperTests(unittest.TestCase):
    def test_sensitive_hierarchy_is_refused(self):
        for content in [
            b'<node resource-id="access_token" text="hidden"/>',
            b'<node text="Bearer sensitive-value"/>',
            b'<node text="eyJabc.def.ghi"/>',
            b'<node password="true" text="hidden"/>',
        ]:
            with self.assertRaises(ValueError):
                helpers.safe_hierarchy(b'<?xml version="1.0"?><hierarchy>' + content + b'</hierarchy>')

    def test_dump_requires_screen_confirmation_and_preserves_existing_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix = Path(temporary) / "screen"
            with patch.object(helpers, "adb") as adb:
                with self.assertRaises(ValueError):
                    helpers.dump("device", prefix, False)
                Path(str(prefix) + ".xml").write_text("original")
                with self.assertRaises(ValueError):
                    helpers.dump("device", prefix, True)
                adb.assert_not_called()

    def test_dump_is_explicit_device_private_files_and_no_logcat(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix = Path(temporary) / "screen"
            with patch.object(helpers, "adb", side_effect=[SAFE_XML, b"\x89PNG\r\n\x1a\nfixture"]) as adb, patch("sys.stdout", new_callable=io.StringIO) as output:
                helpers.dump("selected", prefix, True)
                self.assertIn("(10,20)", output.getvalue())
                self.assertTrue(all(call.args[0] == "selected" for call in adb.call_args_list))
                self.assertNotIn("logcat", str(adb.call_args_list))
            self.assertEqual(Path(str(prefix) + ".xml").stat().st_mode & 0o777, 0o600)
            self.assertTrue(Path(str(prefix) + ".png").exists())

    def test_logcat_slice_keeps_only_the_app_wire_ledger(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix = Path(temporary) / "S03"
            with patch.object(helpers, "adb", return_value=LOGCAT) as adb, patch("sys.stdout", new_callable=io.StringIO) as output:
                helpers.logcat("selected", prefix)
                adb.assert_called_once_with("selected", "logcat", "-d", "-s", "flutter")
                self.assertIn("3 wire-ledger lines, 2 failed reads", output.getvalue())
            saved = Path(str(prefix) + ".txt")
            self.assertEqual(saved.read_text().count("[http\u2717] 503 GET /v1/users/me"), 2)
            self.assertNotIn("unrelated flutter print", saved.read_text())
            self.assertEqual(saved.stat().st_mode & 0o777, 0o600)

    def test_logcat_refuses_credentials_empty_buffer_overwrite_and_relative_prefix(self):
        with tempfile.TemporaryDirectory() as temporary:
            prefix = Path(temporary) / "S03"
            for raw in [LOGCAT.replace(b"tok:ab12~cd34", b"Bearer real-secret-value"), b"01-01 I flutter : no wire lines\n"]:
                with patch.object(helpers, "adb", return_value=raw):
                    with self.assertRaises(ValueError):
                        helpers.logcat("selected", prefix)
                self.assertFalse(Path(str(prefix) + ".txt").exists())
            with patch.object(helpers, "adb", return_value=LOGCAT) as adb, patch("sys.stdout", new_callable=io.StringIO):
                with self.assertRaises(ValueError):
                    helpers.logcat("selected", Path("relative/S03"))
                adb.assert_not_called()
                helpers.logcat("selected", prefix)
                with self.assertRaises(ValueError):
                    helpers.logcat("selected", prefix)

    def test_teardown_requires_restoration_and_removes_only_selected_port(self):
        with patch.object(helpers, "adb") as adb, patch.object(helpers, "control") as control, patch("sys.stdout", new_callable=io.StringIO):
            with self.assertRaises(ValueError):
                helpers.teardown("selected", False)
            control.assert_not_called()
            helpers.teardown("selected", True)
            control.assert_called_once_with("/__fault/rules", "DELETE")
            adb.assert_called_once_with("selected", "reverse", "--remove", "tcp:8089")

    def test_preflight_refuses_active_faults_before_network_or_device(self):
        with patch.object(helpers, "control", side_effect=[{"upstream": helpers.UPSTREAM}, {"scenario": "S01", "rules": [{}]}]), patch.object(helpers, "open_url") as request, patch.object(helpers, "adb") as adb:
            with self.assertRaises(ValueError):
                helpers.preflight("selected")
            request.assert_not_called()
            adb.assert_not_called()

    def test_preflight_preserves_a_conflicting_tunnel(self):
        with patch.object(helpers, "control", side_effect=[{"upstream": helpers.UPSTREAM}, {"scenario": "S00", "rules": []}]), patch.object(helpers, "open_url") as request, patch.object(helpers, "adb", side_effect=[b"device", b"selected tcp:8089 tcp:9999"]) as adb:
            response = request.return_value.__enter__.return_value
            response.status = 200
            response.url = helpers.UPSTREAM + "/gateway/health/ready"
            with self.assertRaises(ValueError):
                helpers.preflight("selected")
            self.assertEqual(adb.call_count, 2)


if __name__ == "__main__":
    unittest.main()
