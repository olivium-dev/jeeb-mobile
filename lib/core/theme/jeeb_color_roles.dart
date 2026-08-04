import 'package:flutter/material.dart';

import 'jeeb_midnight_palette.dart';

/// The single semantic color-role layer for Jeeb.
///
/// UX-AUDIT sprint-009 §3/T1 ("No color-role system") found 7+ ad-hoc accent
/// families (periwinkle, navy, orange, dark-red, red, mauve, green, brown) with
/// no role semantics — the root cause of most visual chaos and the broken light
/// theme (§T2). Material 3's [ColorScheme] already models primary / secondary /
/// surface / onSurface / error, but it has **no** success / warning / info
/// roles, so those hues drifted per-screen (green "Light" tier label, dark-red
/// "Top up" banner, etc.).
///
/// This extension closes that gap. It is **not** a parallel color system: the
/// M3 roles remain the single source of truth in [ColorScheme] (resolve them
/// via [JeebRoles] below), and this class only adds the semantic roles M3 omits
/// — `success`, `warning`, `info` — each with its `on*` text pair and a
/// tonal `*Container` / `on*Container` pair, generated for BOTH light and dark
/// from the same intent.
///
/// The redesign (redesign-2026-08 §4.1) adds one more: `accent`, the brand
/// orange as a *named role*. The 18 files behind
/// `no_raw_semantic_colors_test.dart` may not touch `colorScheme.tertiary`, so
/// `accent` is the only sanctioned way for them to paint brand orange —
/// rationed to state and emphasis, never chrome.
///
/// Every text pair here is WCAG 2.2 AA verified (≥ 4.5:1) by
/// `test/core/theme/color_role_contrast_test.dart`, the automated audit harness
/// the UX plan (§7.1) calls for. Do not add a role without adding it to that
/// gate.
///
/// Read these via `context.jeebRoles.<role>` ([JeebRoles]), never by reaching
/// for a hex literal — see `flutter-no-magic-values-design-tokens`.
/// MIDNIGHT (M0-2): `.light()`/`.dark()` both return [JeebColorRoles.midnight].
@immutable
class JeebColorRoles extends ThemeExtension<JeebColorRoles> {
  const JeebColorRoles({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.onAccentContainer,
  });

  /// Named `.light()` for API stability only; returns [JeebColorRoles.midnight].
  factory JeebColorRoles.light() => JeebColorRoles.midnight();

  /// Named `.dark()` for API stability only; returns [JeebColorRoles.midnight].
  factory JeebColorRoles.dark() => JeebColorRoles.midnight();

  /// Token sheet §2. `onSuccess`/`onInfo` are page-navy, NOT white: white on
  /// `#3BB273` is 2.2:1 and on `#8A93D8` is 2.4:1 — both fail AA.
  factory JeebColorRoles.midnight() => const JeebColorRoles(
        success: JeebMidnight.success,
        onSuccess: JeebMidnight.page,
        successContainer: JeebMidnight.successContainer,
        onSuccessContainer: JeebMidnight.successSoft,
        warning: JeebMidnight.amber,
        onWarning: JeebMidnight.onAmber,
        warningContainer: JeebMidnight.amberContainer,
        onWarningContainer: JeebMidnight.amberSoft,
        info: JeebMidnight.inkMuted,
        onInfo: JeebMidnight.page,
        infoContainer: JeebMidnight.surfaceHigh,
        onInfoContainer: JeebMidnight.inkSoft,
        // 4.65:1 — AA by 0.15, so `onAccent` has no headroom to be faded.
        accent: JeebMidnight.orange,
        onAccent: Color(0xFFFFFFFF),
        accentContainer: JeebMidnight.orangeContainer,
        onAccentContainer: JeebMidnight.orangeTint,
      );

  /// Positive / completed / online (e.g. "On the way", delivered success).
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Caution / attention needed (e.g. "Top up to bid", expiring soon).
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Neutral informational (e.g. fee explainers, tips).
  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  /// Brand orange as a role — emphasis and live state only (Edit/Change links,
  /// broadcasting, active stepper node, "Best value"), never chrome and never
  /// a large fill except the at-door arrival banner. Same value as
  /// `colorScheme.tertiary`; this is the accessor the contrast-gated files use.
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color onAccentContainer;

  @override
  JeebColorRoles copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? onAccentContainer,
  }) {
    return JeebColorRoles(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      onAccentContainer: onAccentContainer ?? this.onAccentContainer,
    );
  }

  @override
  JeebColorRoles lerp(ThemeExtension<JeebColorRoles>? other, double t) {
    if (other is! JeebColorRoles) return this;
    return JeebColorRoles(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer:
          Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer:
          Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      onInfoContainer: Color.lerp(onInfoContainer, other.onInfoContainer, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      onAccentContainer:
          Color.lerp(onAccentContainer, other.onAccentContainer, t)!,
    );
  }
}

/// Unified read facade over the Jeeb semantic color-role layer.
///
/// One accessor for every role a feature should ever need. The Material 3 roles
/// (`primary` / `secondary` / `surface` / `onSurface` / `error` …) are
/// forwarded straight from [ColorScheme] — this facade adds no parallel storage
/// for them, so [ColorScheme] stays the single source of truth. The
/// success / warning / info roles come from the [JeebColorRoles] extension.
///
/// Usage:
/// ```dart
/// final roles = context.jeebRoles;
/// Container(color: roles.successContainer, child: Text(..., style: TextStyle(color: roles.onSuccessContainer)));
/// ```
@immutable
class JeebRoles {
  const JeebRoles(this._scheme, this._semantic);

  final ColorScheme _scheme;
  final JeebColorRoles _semantic;

  // ── Material 3 roles (source of truth: ColorScheme) ──────────────────────
  Color get primary => _scheme.primary;
  Color get onPrimary => _scheme.onPrimary;
  Color get primaryContainer => _scheme.primaryContainer;
  Color get onPrimaryContainer => _scheme.onPrimaryContainer;
  Color get secondary => _scheme.secondary;
  Color get onSecondary => _scheme.onSecondary;
  Color get secondaryContainer => _scheme.secondaryContainer;
  Color get onSecondaryContainer => _scheme.onSecondaryContainer;
  Color get surface => _scheme.surface;
  Color get onSurface => _scheme.onSurface;
  Color get onSurfaceVariant => _scheme.onSurfaceVariant;
  Color get error => _scheme.error;
  Color get onError => _scheme.onError;
  Color get errorContainer => _scheme.errorContainer;
  Color get onErrorContainer => _scheme.onErrorContainer;

  // ── Jeeb semantic roles (source of truth: JeebColorRoles extension) ──────
  Color get success => _semantic.success;
  Color get onSuccess => _semantic.onSuccess;
  Color get successContainer => _semantic.successContainer;
  Color get onSuccessContainer => _semantic.onSuccessContainer;
  Color get warning => _semantic.warning;
  Color get onWarning => _semantic.onWarning;
  Color get warningContainer => _semantic.warningContainer;
  Color get onWarningContainer => _semantic.onWarningContainer;
  Color get info => _semantic.info;
  Color get onInfo => _semantic.onInfo;
  Color get infoContainer => _semantic.infoContainer;
  Color get onInfoContainer => _semantic.onInfoContainer;

  /// Brand orange. The ONLY sanctioned orange in the contrast-gated files —
  /// `.tertiary` is banned there by `no_raw_semantic_colors_test.dart`.
  Color get accent => _semantic.accent;
  Color get onAccent => _semantic.onAccent;
  Color get accentContainer => _semantic.accentContainer;
  Color get onAccentContainer => _semantic.onAccentContainer;
}

/// Resolves the unified [JeebRoles] facade from the active theme.
extension JeebRolesX on BuildContext {
  /// The Jeeb semantic color-role layer for the current theme (light or dark).
  ///
  /// Falls back to [JeebColorRoles.light] if the extension is somehow absent so
  /// call sites never null-crash; in a correctly wired app (see
  /// `AppTheme._build`) the real per-brightness variant is always present.
  JeebRoles get jeebRoles {
    final theme = Theme.of(this);
    return JeebRoles(
      theme.colorScheme,
      theme.extension<JeebColorRoles>() ?? JeebColorRoles.light(),
    );
  }
}
