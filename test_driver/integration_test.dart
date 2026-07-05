// Screenshot-persisting driver for the native integration UI tests.
//
// Run a screen test with:
//   flutter drive \
//     --driver=test_driver/integration_test.dart \
//     --target=integration_test/screens/<screen>_test.dart \
//     -d emulator-5554
//
// Every `binding.takeScreenshot('<name>')` call inside a test is delivered here
// and written to .maestro/screen-tests/screenshots/<name>.png on the HOST
// (kept alongside the iteration-1 evidence). PNG bytes come straight from the
// Flutter surface (Android needs convertFlutterSurfaceToImage first — the
// harness does that).
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final dir = Directory('integration_test/screenshots');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/$name.png');
      file.writeAsBytesSync(bytes);
      stdout.writeln('WROTE screenshot ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
