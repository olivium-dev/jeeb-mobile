// M6 L15 — JeebTopBar publishes the status-bar chrome for the ~44 screens it
// heads. It is not an AppBar, so `appBarTheme.systemOverlayStyle` never reached
// any of them.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_top_bar.dart';

/// The status-bar inset a notched phone reports.
const double _statusBarDp = 47;

/// Where `RenderView._updateSystemChrome` samples the upper annotation:
/// horizontally centred, at half the top padding — i.e. INSIDE the status bar
/// and therefore ABOVE anything a `SafeArea` has pushed down.
Offset _statusBarProbe(WidgetTester tester) => Offset(
      tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
      _statusBarDp / 2,
    );

/// Mounts [child] the way a real screen does: under a status-bar inset, inside
/// a `SafeArea`, so the bar's own rect starts BELOW the probe point.
Widget _screen(Widget child) => MediaQuery(
      data: const MediaQueryData(
        padding: EdgeInsets.only(top: _statusBarDp),
        viewPadding: EdgeInsets.only(top: _statusBarDp),
      ),
      child: MaterialApp(
        theme: AppTheme.midnight(),
        home: Scaffold(
          body: SafeArea(
            child: Column(children: <Widget>[child]),
          ),
        ),
      ),
    );

SystemUiOverlayStyle? _resolvedChrome(WidgetTester tester) {
  final RenderView view = tester.binding.renderViews.first;
  return view.debugLayer!.find<SystemUiOverlayStyle>(_statusBarProbe(tester));
}

AnnotatedRegionLayer<SystemUiOverlayStyle> _chromeLayer(WidgetTester tester) =>
    tester.layers.whereType<AnnotatedRegionLayer<SystemUiOverlayStyle>>().single;

void main() {
  group('JeebTopBar system chrome (M6 L15)', () {
    testWidgets('publishes AppTheme.systemOverlayStyle, unsized',
        (WidgetTester tester) async {
      await tester.pumpWidget(_screen(const JeebTopBar.back(title: 'Offers')));

      final AnnotatedRegion<SystemUiOverlayStyle> region =
          tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.descendant(
          of: find.byType(JeebTopBar),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ),
      );

      expect(region.value, AppTheme.systemOverlayStyle);
      expect(region.value, JeebTopBar.overlayStyle);
      // The whole point of L15: the app's ONE ratified chrome, not a Material
      // default. Both fields are what a wrong theme would get wrong.
      expect(region.value.statusBarIconBrightness, Brightness.light);
      expect(region.value.statusBarBrightness, Brightness.dark);
      expect(
        region.sized,
        isFalse,
        reason: 'a sized region is only found when the probe lands inside the '
            'bar, and the bar sits below the status bar on every screen',
      );
      expect(_chromeLayer(tester).size, isNull, reason: 'unsized on the layer');
    });

    testWidgets('resolves at the status-bar probe even though the bar is below it',
        (WidgetTester tester) async {
      await tester.pumpWidget(_screen(const JeebTopBar.back(title: 'Offers')));

      // The bar really is below the probe — otherwise this test would pass for
      // the wrong reason and `sized: false` would be unnecessary.
      expect(
        tester.getRect(find.byType(JeebTopBar)).top,
        greaterThan(_statusBarProbe(tester).dy),
      );
      expect(_resolvedChrome(tester), AppTheme.systemOverlayStyle);
    });

    testWidgets('all three leading modes carry it', (WidgetTester tester) async {
      for (final JeebTopBar bar in <JeebTopBar>[
        const JeebTopBar.back(title: 'Back'),
        const JeebTopBar.close(title: 'Close'),
        const JeebTopBar.identity(title: 'Identity'),
      ]) {
        await tester.pumpWidget(_screen(bar));
        expect(_resolvedChrome(tester), AppTheme.systemOverlayStyle);
      }
    });

    testWidgets('DISCRIMINATION — a screen with no top bar resolves nothing',
        (WidgetTester tester) async {
      await tester.pumpWidget(_screen(const Text('bare screen')));

      expect(
        _resolvedChrome(tester),
        isNull,
        reason: 'this is the ~44-screen defect L15 describes; if a Material '
            'default ever supplies chrome here the probe stops discriminating',
      );
    });

    testWidgets('DISCRIMINATION — the sized form does NOT resolve at the probe',
        (WidgetTester tester) async {
      // Same geometry, same value, `sized: true` — the one-token revert of the
      // fix. It must fail, or the assertion above proves nothing about `sized`.
      await tester.pumpWidget(
        _screen(
          const AnnotatedRegion<SystemUiOverlayStyle>(
            value: AppTheme.systemOverlayStyle,
            child: SizedBox(height: 60, width: double.infinity),
          ),
        ),
      );

      expect(_resolvedChrome(tester), isNull);
    });
  });
}
