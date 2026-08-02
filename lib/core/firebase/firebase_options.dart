// TODO(owner): Run `flutterfire configure` to generate this file with real values.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'firebase_options.dart is a placeholder. Run `flutterfire configure` '
        'to generate real web options before initializing Firebase on web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'firebase_options.dart is a placeholder. Run `flutterfire configure` '
          'to generate real options for this platform.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for '
          '$defaultTargetPlatform — run `flutterfire configure`.',
        );
    }
  }
}
