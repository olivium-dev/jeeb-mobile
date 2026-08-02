import 'package:flutter/material.dart';

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

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

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

@immutable
class JeebRoles {
  const JeebRoles(this._scheme, this._semantic);

  final ColorScheme _scheme;
  final JeebColorRoles _semantic;

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

extension JeebRolesX on BuildContext {
  JeebRoles get jeebRoles {
    final theme = Theme.of(this);
    return JeebRoles(
      theme.colorScheme,
      theme.extension<JeebColorRoles>() ?? JeebColorRoles.light(),
    );
  }
}
