/// F2 — the `wa.me` deep-link builder for the wallet top-up WhatsApp CTA.
/// Pure, no `BuildContext`, fully unit-testable.
library;

/// Injectable seam for `url_launcher`'s `launchUrl`, mirroring the
/// `mapsUrlBuilder` DI pattern (`app_router.dart`'s active-delivery maps CTA).
typedef WhatsAppLauncher = Future<bool> Function(Uri uri);

class WhatsAppTopUpLink {
  const WhatsAppTopUpLink._();

  /// Builds the `https://wa.me/<digits>?text=<encoded>` URI.
  ///
  /// [supportPhoneE164] is the destination WhatsApp number; non-digit
  /// characters (`+`, spaces, dashes, parens) are stripped — `wa.me`
  /// requires a bare digit string with country code.
  ///
  /// [baseMessage] is the localized greeting. [accountPhoneSentence], if
  /// non-null/non-empty, is the already-localized-and-interpolated "My
  /// account phone number is …" sentence — the caller resolves it (or
  /// leaves it null when the local profile phone is unresolved, e.g. a
  /// cold-start race or the Maestro seam launch, which persists none) so
  /// this builder never has to guess.
  ///
  /// Query is built manually (not `Uri.https`'s query-map, which encodes
  /// spaces as `+`) so the composer text round-trips correctly, including
  /// Arabic copy.
  static Uri build({
    required String supportPhoneE164,
    required String baseMessage,
    String? accountPhoneSentence,
  }) {
    final String digits = supportPhoneE164.replaceAll(RegExp(r'[^0-9]'), '');
    final bool hasSentence =
        accountPhoneSentence != null && accountPhoneSentence.isNotEmpty;
    final String message =
        hasSentence ? '$baseMessage $accountPhoneSentence' : baseMessage;
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$digits',
      query: 'text=${Uri.encodeComponent(message)}',
    );
  }
}
