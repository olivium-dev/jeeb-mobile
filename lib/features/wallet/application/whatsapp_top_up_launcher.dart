/// F2 — the `wa.me` deep-link builder for the wallet top-up WhatsApp CTA.
/// Pure, no `BuildContext`, fully unit-testable.
library;

/// Injectable seam for `url_launcher`'s `launchUrl`, mirroring the
/// `mapsUrlBuilder` DI pattern (`app_router.dart`'s active-delivery maps CTA).
typedef WhatsAppLauncher = Future<bool> Function(Uri uri);

class WhatsAppTopUpLink {
  const WhatsAppTopUpLink._();

  /// Builds `https://wa.me/<digits>?text=<encoded>`: strips non-digits, and
  /// hand-encodes the query so spaces stay `%20` (never `+`), incl. Arabic.
  static Uri build({
    required String supportPhoneE164,
    required String baseMessage,
    String? accountPhoneSentence,
  }) {
    final String digits = supportPhoneE164.replaceAll(RegExp(r'[^0-9]'), '');
    final bool hasSentence =
        accountPhoneSentence != null && accountPhoneSentence.isNotEmpty;
    final String message = hasSentence
        ? '$baseMessage $accountPhoneSentence'
        : baseMessage;
    return Uri(
      scheme: 'https',
      host: 'wa.me',
      path: '/$digits',
      query: 'text=${Uri.encodeComponent(message)}',
    );
  }
}
