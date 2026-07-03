import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag_export.dart';

/// Pins the EXACT export path contract documented in docs/diagnostics.md —
/// if the on-device layout or the adb one-liner shape changes, this fails and
/// the doc must move with it.
void main() {
  group('androidPackageFromPath', () {
    test('extracts the applicationId from a modern user-0 data path', () {
      expect(
        DiagExport.androidPackageFromPath(
          '/data/user/0/app.jeeb.mobile.dev/files/diag/x.jsonl',
        ),
        'app.jeeb.mobile.dev',
      );
    });

    test('extracts from the legacy /data/data alias', () {
      expect(
        DiagExport.androidPackageFromPath(
          '/data/data/app.jeeb.mobile/files/diag/x.jsonl',
        ),
        'app.jeeb.mobile',
      );
    });

    test('multi-user paths resolve too', () {
      expect(
        DiagExport.androidPackageFromPath(
          '/data/user/10/app.jeeb.mobile/files/diag/x.jsonl',
        ),
        'app.jeeb.mobile',
      );
    });

    test('non-Android paths yield null', () {
      expect(
        DiagExport.androidPackageFromPath(
          '/Users/qa/Library/Application Support/diag/x.jsonl',
        ),
        isNull,
      );
    });
  });

  group('adbPullCommand (the documented one-liner)', () {
    test('produces the run-as cat command for the dev-flavor path', () {
      const path = '/data/user/0/app.jeeb.mobile.dev/files/diag/'
          '2026-07-03T10-30-15-123Z-client.jsonl';
      expect(
        DiagExport.adbPullCommand(path),
        'adb exec-out run-as app.jeeb.mobile.dev '
        "cat 'files/diag/2026-07-03T10-30-15-123Z-client.jsonl' "
        '> 2026-07-03T10-30-15-123Z-client.jsonl',
      );
    });

    test('falls back to plain adb pull for non-app-data paths', () {
      const path = '/sdcard/Download/diag/x.jsonl';
      expect(
        DiagExport.adbPullCommand(path),
        'adb pull "/sdcard/Download/diag/x.jsonl" x.jsonl',
      );
    });
  });

  group('formatBytes', () {
    test('renders B / KB / MB with one decimal', () {
      expect(DiagExport.formatBytes(532), '532 B');
      expect(DiagExport.formatBytes(12 * 1024 + 410), '12.4 KB');
      expect(DiagExport.formatBytes(1258291), '1.2 MB');
    });
  });
}
