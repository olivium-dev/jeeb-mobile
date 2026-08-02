library;

abstract final class DiagExport {
  static String? androidPackageFromPath(String path) {
    final match =
        RegExp(r'^/data/(?:user/\d+|data)/([^/]+)/').firstMatch(path);
    return match?.group(1);
  }

  static String adbPullCommand(String filePath) {
    final pkg = androidPackageFromPath(filePath);
    final name = filePath.split('/').last;
    if (pkg == null) return 'adb pull "$filePath" $name';
    final marker = '/$pkg/';
    final relative =
        filePath.substring(filePath.indexOf(marker) + marker.length);
    return "adb exec-out run-as $pkg cat '$relative' > $name";
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
