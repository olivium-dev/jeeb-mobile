import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile
import os
import subprocess

import android_crashlytics_mapping as subject


def varint(value):
    result = bytearray()
    while value >= 128:
        result.append((value & 127) | 128)
        value >>= 7
    result.append(value)
    return bytes(result)


def field(number, value):
    return varint(number * 8 + 2) + varint(len(value)) + value


def entry(name, value, config=b""):
    item = field(2, field(1, value))
    pair = field(1, config) + field(2, field(4, item))
    return field(2, name) + field(6, pair)


def table(mapping=b"1234567890abcdef1234567890abcdef", package=subject.PACKAGE,
          duplicate=False, config=b"", missing=False):
    resources = entry(b"google_app_id", b"1:1051234312170:android:85bc801430c9006623dc93")
    if not missing:
        resources = field(3, resources) + field(3, entry(subject.RESOURCE, mapping, config))
    else:
        resources = field(3, resources)
    if duplicate:
        resources += field(3, entry(subject.RESOURCE, mapping))
    kind = field(2, b"string") + resources
    return field(2, field(2, package) + field(3, kind))


class MappingTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.aab = self.root / "candidate.aab"
        self.mapping = self.root / "mapping.txt"
        self.provenance = self.root / "provenance.json"
        self.make_aab(table())
        self.mapping.write_text("original.Name -> a:\n")
        self.record = subject.identity(self.aab) | {
            "artifact_sha256": subject.sha256(self.aab),
            "mapping_sha256": subject.sha256(self.mapping),
        }
        self.provenance.write_text(json.dumps(self.record))

    def make_aab(self, content):
        with zipfile.ZipFile(self.aab, "w") as archive:
            archive.writestr("base/resources.pb", content)

    def test_actual_wire_identity_and_hashes(self):
        self.assertEqual(subject.validate(self.aab, self.mapping, self.provenance),
                         subject.identity(self.aab))

    def test_missing_blank_duplicate_wrong_package_or_localized_rejected(self):
        for options in ({"missing": True}, {"mapping": b"0" * 32},
                        {"duplicate": True}, {"package": b"other.app"},
                        {"config": b"\x08\x01"}, {"mapping": b"bad-id"}):
            with self.subTest(options=options):
                self.make_aab(table(**options))
                with self.assertRaises(ValueError):
                    subject.identity(self.aab)

    def test_truncated_or_invalid_wire_rejected(self):
        for content in (b"\x12\x80", b"\x12\x7fabc", b"\x0b", b"\x00"):
            with self.subTest(content=content), self.assertRaises(ValueError):
                subject.fields(content)

    def test_swapped_mapping_rejected(self):
        self.mapping.write_text("different.Name -> b:\n")
        with self.assertRaisesRegex(ValueError, "mapping differs"):
            subject.validate(self.aab, self.mapping, self.provenance)

    def test_swapped_aab_rejected_even_if_identity_same(self):
        with zipfile.ZipFile(self.aab, "a") as archive:
            archive.writestr("additional", "changed")
        with self.assertRaisesRegex(ValueError, "AAB differs"):
            subject.validate(self.aab, self.mapping, self.provenance)

    def test_provenance_identity_swap_rejected(self):
        for key, value in (("crashlytics_mapping_id", "a" * 32),
                           ("firebase_app_id", "1:123:android:abcd")):
            with self.subTest(key=key):
                record = dict(self.record, **{key: value})
                self.provenance.write_text(json.dumps(record))
                with self.assertRaisesRegex(ValueError, "identity differs"):
                    subject.validate(self.aab, self.mapping, self.provenance)

    def test_untrusted_buildtools_never_executes(self):
        jar = self.root / "bad.jar"
        jar.write_bytes(b"not official buildtools")
        args = ["tool", "upload", "--aab", str(self.aab), "--mapping", str(self.mapping),
                "--provenance", str(self.provenance), "--buildtools", str(jar)]
        with patch("sys.argv", args), patch.object(subject.subprocess, "run") as run:
            with self.assertRaisesRegex(ValueError, "buildtools hash mismatch"):
                subject.main()
            run.assert_not_called()

    def test_upload_exact_arguments_and_failure_propagation(self):
        jar = self.root / "fixture.jar"
        jar.write_bytes(b"offline fixture")
        real_sha256 = subject.sha256
        def fixture_sha256(path):
            return subject.BUILDTOOLS_SHA256 if str(path) == str(jar) else real_sha256(path)
        args = ["tool", "upload", "--aab", str(self.aab), "--mapping", str(self.mapping),
                "--provenance", str(self.provenance), "--buildtools", str(jar)]
        expected = ["java", "-jar", str(jar), "-uploadMappingFile", str(self.mapping),
                    "-mappingFileId", self.record["crashlytics_mapping_id"],
                    "-googleAppId", self.record["firebase_app_id"], "-quiet"]
        with patch("sys.argv", args), patch.object(subject, "sha256", fixture_sha256), \
                patch.object(subject.subprocess, "run") as run:
            subject.main()
            run.assert_called_once_with(expected, check=True)
            run.side_effect = subprocess.CalledProcessError(17, expected)
            with self.assertRaises(subprocess.CalledProcessError) as raised:
                subject.main()
            self.assertEqual(raised.exception.returncode, 17)

    @unittest.skipUnless(os.environ.get("AAPT2_BIN") and os.environ.get("ANDROID_PLATFORM_JAR"),
                         "set AAPT2_BIN and ANDROID_PLATFORM_JAR for real AAPT2 validation")
    def test_real_aapt2_output(self):
        resources = self.root / "res" / "values"
        resources.mkdir(parents=True)
        (resources / "ids.xml").write_text(
            '<resources><string name="com.google.firebase.crashlytics.mapping_file_id">'
            '1234567890abcdef1234567890abcdef</string><string name="google_app_id">'
            '1:1051234312170:android:85bc801430c9006623dc93</string></resources>')
        if os.environ.get("CRASHLYTICS_BUILDTOOLS_JAR"):
            jar = os.environ["CRASHLYTICS_BUILDTOOLS_JAR"]
            self.assertEqual(subject.sha256(jar), subject.BUILDTOOLS_SHA256)
            (resources / "ids.xml").write_text(
                '<resources><string name="google_app_id">'
                '1:1051234312170:android:85bc801430c9006623dc93</string></resources>')
            # This invokes only the same offline ID-generation operation used
            # by the plugin; no symbol/mapping upload command is invoked.
            subprocess.run(["java", "-jar", jar, "-injectMappingFileIdIntoResource",
                            str(resources / "crashlytics.xml"), "-quiet"], check=True)
        manifest = self.root / "AndroidManifest.xml"
        manifest.write_text('<manifest xmlns:android="http://schemas.android.com/apk/res/android" '
                            'package="com.olivium.jeeb"><application/></manifest>')
        compiled, linked = self.root / "compiled.zip", self.root / "linked.apk"
        subprocess.run([os.environ["AAPT2_BIN"], "compile", "--dir", str(resources.parent),
                        "-o", str(compiled)], check=True)
        subprocess.run([os.environ["AAPT2_BIN"], "link", "--proto-format", "-o", str(linked),
                        "--manifest", str(manifest), "-I", os.environ["ANDROID_PLATFORM_JAR"],
                        str(compiled)], check=True)
        with zipfile.ZipFile(linked) as archive:
            self.make_aab(archive.read("resources.pb"))
        mapping_id = subject.identity(self.aab)["crashlytics_mapping_id"]
        if os.environ.get("CRASHLYTICS_BUILDTOOLS_JAR"):
            self.assertRegex(mapping_id, r"^[0-9a-f]{32}$")
            self.assertNotEqual(mapping_id, "0" * 32)
            self.assertNotEqual(mapping_id, "1234567890abcdef1234567890abcdef")
        else:
            self.assertEqual(mapping_id, "1234567890abcdef1234567890abcdef")


if __name__ == "__main__":
    unittest.main()
