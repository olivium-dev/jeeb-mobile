/// Pure helpers for exporting on-device diag session files (no IO here — the
/// screen and tests share these so the documented `adb` command and the app's
/// actual file layout can never drift apart).
library;

/// Export-command helpers for the diag JSONL session files.
abstract final class DiagExport {
  /// Extracts the Android application id from an app-private data path like
  /// `/data/user/0/app.jeeb.mobile.dev/files/diag/x.jsonl` (or the legacy
  /// `/data/data/<pkg>/…` alias). Null for non-Android/non-app-data paths.
  static String? androidPackageFromPath(String path) {
    final match =
        RegExp(r'^/data/(?:user/\d+|data)/([^/]+)/').firstMatch(path);
    return match?.group(1);
  }

  /// The exact one-liner that copies [filePath] off a device.
  ///
  /// The diag files live in the app's PRIVATE support dir, so a plain
  /// `adb pull` cannot read them; for a debuggable build `run-as` can. The
  /// produced command is relative to the app-data dir (`run-as` cwd), e.g.:
  ///
  /// ```
  /// adb exec-out run-as app.jeeb.mobile.dev cat 'files/diag/<session>.jsonl' \
  ///   > <session>.jsonl
  /// ```
  ///
  /// Non-Android paths (iOS simulator etc.) fall back to a plain `adb pull`
  /// shape purely as a copyable hint of where the file lives.
  static String adbPullCommand(String filePath) {
    final pkg = androidPackageFromPath(filePath);
    final name = filePath.split('/').last;
    if (pkg == null) return 'adb pull "$filePath" $name';
    final marker = '/$pkg/';
    final relative =
        filePath.substring(filePath.indexOf(marker) + marker.length);
    return "adb exec-out run-as $pkg cat '$relative' > $name";
  }

  /// Human-readable size for the sessions list (`532 B`, `12.4 KB`, `1.2 MB`).
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
