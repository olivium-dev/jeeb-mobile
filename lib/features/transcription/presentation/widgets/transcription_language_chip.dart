import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../transcription_screen.dart';

/// The detected-language pill (`Lebanese Arabic · auto-detected`, tpl 322).
///
/// Renders **only** for a language code we ship a display name for. An unknown
/// or absent code renders nothing — echoing a raw code, or deriving one from
/// `Localizations.localeOf`, would fabricate a detection result the gateway
/// never sent.
class TranscriptionLanguageChip extends StatelessWidget {
  const TranscriptionLanguageChip({super.key, required this.languageCode});

  /// The gateway's `TranscribeResponse.language`, as seeded onto the state.
  final String? languageCode;

  /// True when [code] maps to a shipped display name. The screen gates the
  /// surrounding gap on this so an absent chip leaves no hole in the stack.
  static bool isSupported(String? code) => _canonical(code) != null;

  static String? _canonical(String? code) {
    final normalized = code?.trim().toLowerCase();
    return switch (normalized) {
      'ar-lb' || 'ar' || 'en' => normalized,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = _displayName(context);
    if (name == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    // TODO(redesign-24): swap to JeebSelectChip(role: meta) when the kit ships
    // it — the shipped role enum has no static meta pill.
    return Semantics(
      identifier: TranscriptionKeys.languageChip,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: OmdsBorderRadius.pill,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.twoXSmall,
          ),
          child: Text(
            l10n.transcriptionLanguageDetected(name),
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  String? _displayName(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (_canonical(languageCode)) {
      'ar-lb' => l10n.transcriptionLanguageArabicLebanese,
      'ar' => l10n.transcriptionLanguageArabic,
      'en' => l10n.transcriptionLanguageEnglish,
      _ => null,
    };
  }
}
