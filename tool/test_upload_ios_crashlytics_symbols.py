"""Exercise the distribution wrapper with isolated SDK/config/archive fixtures."""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest
import zipfile


class SymbolUploadTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        source = Path(__file__).resolve().parent.parent
        # The real plist validator delegates to the canonical contract gate.
        # Preserve that complete tracked dependency graph in the isolated repo.
        paths = subprocess.check_output(['git', 'ls-files', '-z', '--',
            '.firebaserc', 'contracts', 'android/app/build.gradle',
            'ios/Runner.xcodeproj/project.pbxproj', 'lib', '.github/workflows',
            'tool/upload_ios_crashlytics_symbols.sh',
            'tool/validate_ios_google_service_info.sh',
            'tool/validate_jeeb_firebase_contract.sh',
            'tool/run_with_android_firebase_config.sh',
            'tool/run_with_dev_firebase_config.sh',
            'tool/run_with_ios_firebase_config.sh',
            'tool/validate_android_google_services.sh',
            'tool/validate_dev_google_services.sh'], cwd=source).decode().split('\0')
        for name in filter(None, paths):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / name, target)
        self.sdk = self.root / 'sdk'
        (self.sdk / 'Crashlytics').mkdir(parents=True)
        self.uploader = self.sdk / 'Crashlytics/upload-symbols'
        self.uploader.write_text('#!/bin/bash\nprintf "%s\\n" "$@" >"$UPLOAD_RECEIPT"\nexit "${UPLOAD_EXIT:-0}"\n')
        self.uploader.chmod(0o755)
        for args in (['init', '-q'], ['add', '.'], ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', 'commit', '-qm', 'fixture']):
            subprocess.run(['git', '-C', str(self.sdk), *args], check=True)
        revision = subprocess.check_output(['git', '-C', str(self.sdk), 'rev-parse', 'HEAD'], text=True).strip()
        lock = self.root / 'ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved'
        lock.parent.mkdir(parents=True)
        lock.write_text(json.dumps({'pins': [{'identity': 'firebase-ios-sdk', 'state': {'revision': revision}}]}))
        self.config = self.root / 'GoogleService-Info.plist'
        config = plistlib.loads((source / 'ios/Runner/GoogleService-Info.plist.template').read_bytes())
        config.update(API_KEY='AIza' + 'A' * 35, GCM_SENDER_ID='1051234312170', PROJECT_ID='jeeb-5a293',
                      STORAGE_BUCKET='jeeb-5a293.appspot.com',
                      GOOGLE_APP_ID=json.loads((source / 'contracts/jeeb-mobile-firebase-apps-v1.json').read_text())['ios']['store']['appId'],
                      CLIENT_ID='1051234312170-fixture.apps.googleusercontent.com',
                      REVERSED_CLIENT_ID='com.googleusercontent.apps.1051234312170-fixture')
        self.config.write_bytes(plistlib.dumps(config))
        self.config.chmod(0o600)
        self.receipt = self.root / 'receipt'
        self.archive = self.root / 'symbols.zip'
        self.ipa = self.root / 'app.ipa'
        with zipfile.ZipFile(self.ipa, 'w') as archive:
            archive.writestr('Payload/Runner.app/Runner', 'fixture')
            archive.writestr('Payload/Runner.app/Frameworks/App.framework/App', 'fixture')
        self.write_archive()
        # Synthetic UUID response isolates wrapper behavior from actual SDK upload.
        mockbin = self.root / 'bin'
        mockbin.mkdir()
        (mockbin / 'xcrun').write_text('#!/bin/bash\necho "UUID: 12345678-1234-1234-1234-123456789ABC (arm64) fixture"\n')
        (mockbin / 'xcrun').chmod(0o755)
        self.env = dict(os.environ, PATH=str(mockbin) + ':' + os.environ['PATH'],
                        UPLOAD_RECEIPT=str(self.receipt),
                        IOS_FIREBASE_EXPECTED_CLIENT_ID=config['CLIENT_ID'],
                        IOS_FIREBASE_EXPECTED_REVERSED_CLIENT_ID=config['REVERSED_CLIENT_ID'])

    def write_archive(self, names=('Runner', 'App'), extra=None):
        with zipfile.ZipFile(self.archive, 'w') as archive:
            for name in names:
                archive.writestr(f'dSYMs/{name}.dSYM/Contents/Resources/DWARF/{name}', 'fixture')
            if extra:
                archive.writestr(extra, 'unsafe')

    def run_upload(self, **overrides):
        env = dict(self.env, EXPECTED_DSYM_SHA256=hashlib.sha256(self.archive.read_bytes()).hexdigest(),
                   EXPECTED_IPA_SHA256=hashlib.sha256(self.ipa.read_bytes()).hexdigest(), **overrides)
        return subprocess.run(['bash', str(self.root / 'tool/upload_ios_crashlytics_symbols.sh'),
                               str(self.archive), str(self.config), str(self.sdk), str(self.ipa)], env=env,
                              capture_output=True, text=True)

    def test_supported_upload_arguments(self):
        result = self.run_upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.receipt.read_text().splitlines()[:4], ['-gsp', str(self.config), '-p', 'ios'])

    def test_upload_failure_propagates(self):
        self.assertEqual(self.run_upload(UPLOAD_EXIT='17').returncode, 17)

    def test_missing_flutter_symbols_rejected(self):
        self.write_archive(names=('Runner',))
        self.assertNotEqual(self.run_upload().returncode, 0)
        self.assertFalse(self.receipt.exists())

    def test_unsafe_archive_rejected_before_upload(self):
        self.write_archive(extra='../escape')
        self.assertNotEqual(self.run_upload().returncode, 0)
        self.assertFalse(self.receipt.exists())

    def test_tampered_uploader_rejected(self):
        self.uploader.write_text(self.uploader.read_text() + '# tampered\n')
        self.assertNotEqual(self.run_upload().returncode, 0)
        self.assertFalse(self.receipt.exists())

    def test_firebase_identity_mismatch_rejected(self):
        config = plistlib.loads(self.config.read_bytes())
        config['GOOGLE_APP_ID'] = '1:1051234312170:ios:0123456789abcdef'
        self.config.write_bytes(plistlib.dumps(config))
        result = self.run_upload()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Google app identity does not match', result.stderr)
        self.assertFalse(self.receipt.exists())

    def test_canonical_project_drift_rejected_before_upload(self):
        (self.root / '.firebaserc').write_text('{"projects":{"default":"wrong-project"}}')
        result = self.run_upload()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('.firebaserc default project drifted', result.stderr)
        self.assertFalse(self.receipt.exists())

    def test_hash_mismatch_rejected(self):
        self.env['EXPECTED_DSYM_SHA256'] = '0' * 64
        self.env['EXPECTED_IPA_SHA256'] = hashlib.sha256(self.ipa.read_bytes()).hexdigest()
        result = subprocess.run(['bash', str(self.root / 'tool/upload_ios_crashlytics_symbols.sh'),
                                 str(self.archive), str(self.config), str(self.sdk), str(self.ipa)], env=self.env,
                                capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(self.receipt.exists())

    def test_normalized_duplicate_rejected(self):
        self.write_archive(extra='dSYMs/Runner.dSYM/Contents/Resources/./DWARF/Runner')
        self.assertNotEqual(self.run_upload().returncode, 0)
        self.assertFalse(self.receipt.exists())

    def test_symlink_rejected(self):
        with zipfile.ZipFile(self.archive, 'a') as archive:
            entry = zipfile.ZipInfo('symlink')
            entry.external_attr = 0o120777 << 16
            archive.writestr(entry, '/tmp')
        self.assertNotEqual(self.run_upload().returncode, 0)
        self.assertFalse(self.receipt.exists())

    def test_real_macho_uuid_match_and_mismatch(self):
        # Real arm64 Mach-O/dSYM pair, with no uploader network calls.
        self.env['PATH'] = os.environ['PATH']
        src = self.root / 'fixture.c'
        binary = self.root / 'binary'
        src.write_text('int main(void) { return 0; }\n')
        subprocess.run(['/usr/bin/xcrun', 'clang', '-arch', 'arm64', '-g', str(src), '-o', str(binary)], check=True, capture_output=True)
        subprocess.run(['/usr/bin/xcrun', 'dsymutil', str(binary)], check=True, capture_output=True)
        dwarf = (self.root / 'binary.dSYM/Contents/Resources/DWARF/binary').read_bytes()
        with zipfile.ZipFile(self.archive, 'w') as archive:
            for name in ('Runner', 'App'):
                archive.writestr(f'dSYMs/{name}.dSYM/Contents/Resources/DWARF/{name}', dwarf)
        def write_ipa(app_binary):
            with zipfile.ZipFile(self.ipa, 'w') as archive:
                archive.writestr('Payload/Runner.app/Runner', binary.read_bytes())
                archive.writestr('Payload/Runner.app/Frameworks/App.framework/App', app_binary)
        write_ipa(binary.read_bytes())
        result = self.run_upload()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.receipt.unlink()
        src.write_text('int main(void) { return 42; }\n')
        other = self.root / 'other'
        subprocess.run(['/usr/bin/xcrun', 'clang', '-arch', 'arm64', '-g', str(src), '-o', str(other)], check=True, capture_output=True)
        write_ipa(other.read_bytes())
        self.assertNotEqual(self.run_upload().returncode, 0)
        self.assertFalse(self.receipt.exists())


if __name__ == '__main__':
    unittest.main()
