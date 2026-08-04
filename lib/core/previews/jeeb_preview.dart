/// Widget previews foundation with automated EN/AR/200% rendering matrix.
library;

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../devtool/catalog/catalog_network_guard.dart';

/// Real app themes for accurate preview rendering.
PreviewThemeData jeebPreviewTheme() => PreviewThemeData(
      materialLight: AppTheme.light(),
      materialDark: AppTheme.dark(),
    );

/// English (LTR) localizations, using the app's real delegate.
PreviewLocalizationsData jeebPreviewEnglish() => const PreviewLocalizationsData(
      locale: Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _delegates,
    );

/// Arabic (RTL); RTL mirroring breaks layouts first.
PreviewLocalizationsData jeebPreviewArabic() => const PreviewLocalizationsData(
      locale: Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: _delegates,
    );

const List<LocalizationsDelegate<Object?>> _delegates =
    <LocalizationsDelegate<Object?>>[
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Wraps widget with app surface + fail-closed network guard.
Widget jeebPreviewHost(Widget child) => CatalogNetworkGuard(
      builder: (_) => Scaffold(body: SafeArea(child: child)),
    );

/// Standard preview matrix: EN light / AR RTL dark / EN 200% text.
/// Pass `matrix: true` to render all three; CI asserts both locales always.
final class JeebPreview extends MultiPreview {
  const JeebPreview({
    this.name,
    this.size,
    this.group = 'Other',
    this.matrix = false,
  });

  /// Preview label; each matrix variant is suffixed.
  final String? name;

  /// Canvas size; defaults to phone-width.
  final Size? size;

  /// Canvas section (feature area for grouping).
  final String group;

  /// Render full EN/AR/200% matrix.
  final bool matrix;

  static const Size _defaultSize = Size(390, 200);

  @override
  List<Preview> get previews {
    final Size box = size ?? _defaultSize;
    if (!matrix) {
      return <Preview>[
        Preview(
          name: name,
          group: group,
          size: box,
          brightness: Brightness.light,
          theme: jeebPreviewTheme,
          localizations: jeebPreviewEnglish,
          wrapper: jeebPreviewHost,
        ),
      ];
    }
    final String prefix = name == null ? '' : '$name · ';
    return <Preview>[
      Preview(
        name: '${prefix}EN light',
        group: group,
        size: box,
        brightness: Brightness.light,
        theme: jeebPreviewTheme,
        localizations: jeebPreviewEnglish,
        wrapper: jeebPreviewHost,
      ),
      Preview(
        name: '${prefix}AR RTL dark',
        group: group,
        size: box,
        brightness: Brightness.dark,
        theme: jeebPreviewTheme,
        localizations: jeebPreviewArabic,
        wrapper: jeebPreviewHost,
      ),
      Preview(
        name: '${prefix}EN 200% text',
        group: group,
        size: box,
        textScaleFactor: 2.0,
        brightness: Brightness.light,
        theme: jeebPreviewTheme,
        localizations: jeebPreviewEnglish,
        wrapper: jeebPreviewHost,
      ),
    ];
  }
}
