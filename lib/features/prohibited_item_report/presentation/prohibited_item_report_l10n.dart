import 'package:flutter/widgets.dart';

/// Feature-local stopgap for this screen's **five** user-visible strings.
///
/// The screen shipped with all five hardcoded in English. `lib/l10n/*` is
/// integrator-owned (a hand-authored ARB parser, no gen-l10n), so a screen lane
/// cannot add the keys itself — the queued batch is recorded verbatim in
/// `docs/redesign-2026-08/wiring/w4-prohibited-item.md`. This class supplies the
/// same EN values plus their AR counterparts until it lands, which is strictly
/// better than the literals it replaces: the screen is now RTL-complete in copy
/// as well as layout. It is the `OtpHandoverL10n` / `LiveTrackingL10n` precedent
/// from the screen-13 and screen-12 lanes.
///
/// The EN wording is **byte-identical to what shipped** — this pass re-skins,
/// it does not rewrite copy. The AR wording reuses the live report path's
/// existing lexicon (`jeeberRequestDetailReport*`: صنف ممنوع / إبلاغ).
///
/// **Delete this file** once the integrator lands the five keys and point the
/// call sites at `AppLocalizations.of(context)`.
class ProhibitedItemReportL10n {
  const ProhibitedItemReportL10n({required bool isArabic})
      : _isArabic = isArabic;

  /// Resolves against the ambient locale. `maybeLocaleOf` (not `localeOf`)
  /// because this screen is also mounted bare by the dev-tool catalog, which
  /// has no `Localizations` ancestor of its own to guarantee.
  factory ProhibitedItemReportL10n.of(BuildContext context) =>
      ProhibitedItemReportL10n(
        isArabic: Localizations.maybeLocaleOf(context)?.languageCode == 'ar',
      );

  final bool _isArabic;

  /// Top-bar title.
  String get title =>
      _pick('Report Prohibited Item', 'الإبلاغ عن صنف ممنوع');

  /// The caution note above the form — when to use this screen.
  String get guidanceNote => _pick(
        'If the Client requested delivery of a prohibited item, '
            'report it here.',
        'إذا طلب العميل توصيل صنف ممنوع، أبلغ عنه هنا.',
      );

  /// Floating label of the free-text description field.
  String get descriptionLabel =>
      _pick('Describe the prohibited item', 'صف الصنف الممنوع');

  /// Secondary outline action — optional photo evidence.
  String get attachPhotoCta => _pick('Attach Photo', 'إرفاق صورة');

  /// The docked primary action.
  String get reportCta => _pick('Report Item', 'إبلاغ عن الصنف');

  String _pick(String en, String ar) => _isArabic ? ar : en;
}
