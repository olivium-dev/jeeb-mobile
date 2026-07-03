import 'package:flutter/material.dart';

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
/// Every text pair here is WCAG 2.2 AA verified (≥ 4.5:1) by
/// `test/core/theme/color_role_contrast_test.dart`, the automated audit harness
/// the UX plan (§7.1) calls for. Do not add a role without adding it to that
/// gate.
///
/// Read these via `context.jeebRoles.<role>` ([JeebRoles]), never by reaching
/// for a hex literal — see `flutter-no-magic-values-design-tokens`.
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
  });

  /// Light-mode semantic roles. Solid roles carry white text; containers are a
  /// light tint carrying dark ink. Tuned against the warm-white Jeeb surface.
  factory JeebColorRoles.light() => const JeebColorRoles(
        success: Color(0xFF1B7A3D),
        onSuccess: Color(0xFFFFFFFF),
        successContainer: Color(0xFFDCFCE7),
        onSuccessContainer: Color(0xFF14532D),
        warning: Color(0xFF8A5A00),
        onWarning: Color(0xFFFFFFFF),
        warningContainer: Color(0xFFFEF3C7),
        onWarningContainer: Color(0xFF713F12),
        info: Color(0xFF1D4ED8),
        onInfo: Color(0xFFFFFFFF),
        infoContainer: Color(0xFFDBEAFE),
        onInfoContainer: Color(0xFF1E3A8A),
      );

  /// Dark-mode semantic roles. Solid roles are lifted (brighter) to read on
  /// dark surfaces and carry dark ink; containers are a deep tint carrying
  /// light ink. Mirrors the light intent, generated for dark.
  factory JeebColorRoles.dark() => const JeebColorRoles(
        success: Color(0xFF4ADE80),
        onSuccess: Color(0xFF052E16),
        successContainer: Color(0xFF14532D),
        onSuccessContainer: Color(0xFFBBF7D0),
        warning: Color(0xFFFBBF24),
        onWarning: Color(0xFF3B2600),
        warningContainer: Color(0xFF78350F),
        onWarningContainer: Color(0xFFFDE68A),
        info: Color(0xFF7AA5FF),
        onInfo: Color(0xFF0A1B3D),
        infoContainer: Color(0xFF1E3A8A),
        onInfoContainer: Color(0xFFBFDBFE),
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
