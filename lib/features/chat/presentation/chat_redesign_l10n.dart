import 'package:flutter/widgets.dart';

/// Feature-local stopgap for the **seven** redesign-2026-08 screen-21 strings
/// that do not exist in the shared ARBs yet.
///
/// The ARB files and the hand-authored `AppLocalizations` getter layer are
/// integrator-owned — a screen lane never edits them. The queued batch is
/// recorded verbatim in `docs/redesign-2026-08/wiring/21-order-chat.md`; this
/// class supplies the same EN/AR values from a feature-local map until it
/// lands, so the feature compiles and its widget tests run today. It is the
/// `LiveTrackingL10n` / `OtpHandoverL10n` precedent from screens 12 and 13,
/// deliberately kept to the smallest possible surface: every string that
/// ALREADY has a getter is read straight off `AppLocalizations` at the call
/// site — nothing is mirrored here.
///
/// Maestro asserts on `Semantics(identifier:)` only, and this lane's widget
/// tests assert through these getters rather than through literals, so the swap
/// is a no-op for every gate.
///
/// **Delete this file** once the integrator lands `chatMessageReadLabel` ·
/// `chatQuickReplyImHome` · `chatQuickReplyCallAtDoor` · `chatQuickReplyThanks`
/// · `chatQuickReplyRowA11y` · `chatSystemChipWithTime` ·
/// `chatCounterpartRatingA11y`, and point its call sites at
/// `AppLocalizations.of(context)`.
class ChatRedesignL10n {
  const ChatRedesignL10n({required bool isArabic}) : _isArabic = isArabic;

  /// Resolves against the ambient locale — `Localizations.localeOf` is the same
  /// source `AppLocalizations.of` reads, so the two can never disagree.
  factory ChatRedesignL10n.of(BuildContext context) => ChatRedesignL10n(
        isArabic: Localizations.localeOf(context).languageCode == 'ar',
      );

  final bool _isArabic;

  String _pick(String en, String ar) => _isArabic ? ar : en;

  /// Outgoing-bubble read state, rendered as the literal WORD in the meta line
  /// (`JeebChatStatus.text`). The board draws `9:25 · Read`; the cyan
  /// `readTick` token has zero board occurrences and is banned.
  String get messageReadLabel => _pick('Read', 'تمت القراءة');

  /// Quick-reply pill `order_chat_quick_reply_home`. Tapping sends this exact
  /// text as a chat message, so the label IS the message.
  String get quickReplyImHome => _pick("I'm home", 'أنا في المنزل');

  /// Quick-reply pill `order_chat_quick_reply_door`.
  String get quickReplyCallAtDoor =>
      _pick('Call me at the door', 'اتصل بي عند الباب');

  /// Quick-reply pill `order_chat_quick_reply_thanks`. DELIBERATELY Arabic in
  /// BOTH locales — the board draws the Arabic pill inside the English thread
  /// (designer note: "one-tap quick replies incl. Arabic"). Product choice
  /// pending owner confirmation; if refused, this becomes EN "Thanks".
  String get quickReplyThanks => 'شكراً';

  /// Accessible name of the quick-reply row container.
  String get quickReplyRowA11y => _pick('Quick replies', 'ردود سريعة');

  /// System timeline chip that carries a server timestamp — `Offer accepted ·
  /// 9:12`. Built ONLY when the message really has one (an undated row gets no
  /// clock — `chat_undated_band_contract_test`).
  String systemChipWithTime(String event, String time) => '$event · $time';

  /// Accessible label for the header's counterpart star rating (★ 4.9). The
  /// visible glyph + number are `ExcludeSemantics`'d behind this sentence.
  String counterpartRatingA11y(String value) =>
      _pick('Rating $value out of 5', 'التقييم $value من 5');
}
