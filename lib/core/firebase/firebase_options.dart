// TODO(owner): Run `flutterfire configure` to generate this file with real values
// See: https://firebase.flutter.dev/docs/cli/
// NEVER commit real API keys or project IDs here
// This is a placeholder template.
//
// Sprint 1 Stream B note: `flutterfire configure` overwrites this file in place
// with the per-platform FirebaseOptions for the selected Firebase project. The
// generated file is gitignored as a secret (see android/app/google-services.json
// and ios/Runner/GoogleService-Info.plist policy) — keep only this placeholder
// committed so the import in bootstrap resolves before the real file is generated.
//
// Usage once generated:
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Placeholder [FirebaseOptions] selector.
///
/// Every value below is an intentionally fake placeholder. Replace this whole
/// file by running `flutterfire configure`. Until then, calling
/// [currentPlatform] throws so a misconfigured build fails loudly rather than
/// silently shipping bogus credentials.
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

  // ── Placeholder template values (NEVER real) ───────────────────────────────
  // These are documented here only to show the shape `flutterfire configure`
  // will fill in. They are not wired into [currentPlatform] on purpose.
  //
  // static const FirebaseOptions android = FirebaseOptions(
  //   apiKey: 'TODO_ANDROID_API_KEY',
  //   appId: 'TODO_ANDROID_APP_ID',
  //   messagingSenderId: 'TODO_SENDER_ID',
  //   projectId: 'TODO_PROJECT_ID',
  //   storageBucket: 'TODO_PROJECT_ID.appspot.com',
  // );
  //
  // static const FirebaseOptions ios = FirebaseOptions(
  //   apiKey: 'TODO_IOS_API_KEY',
  //   appId: 'TODO_IOS_APP_ID',
  //   messagingSenderId: 'TODO_SENDER_ID',
  //   projectId: 'TODO_PROJECT_ID',
  //   storageBucket: 'TODO_PROJECT_ID.appspot.com',
  //   iosBundleId: 'app.jeeb.mobile',
  // );
}
