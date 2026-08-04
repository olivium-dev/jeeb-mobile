// M6 MATERIAL-LEAK PROBE — TEMPORARY AUDIT INSTRUMENT, NOT A GATE.
// Mounts each Material surface under AppTheme.midnight(), rasterises the frame
// and reports a colour histogram so a light Material default cannot hide.
// Every test PASSES; the evidence is the printed report.
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';

const Key _root = Key('m6_probe_root');
const Size _phone = Size(440, 956);

Widget _host(Widget home) => RepaintBoundary(
      key: _root,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.midnight(),
        darkTheme: AppTheme.midnight(),
        themeMode: ThemeMode.dark,
        home: home,
      ),
    );

class _Px {
  const _Px(this.value, this.count);
  final int value; // 0xAARRGGBB-ish packed RGB
  final int count;
  int get r => (value >> 16) & 0xFF;
  int get g => (value >> 8) & 0xFF;
  int get b => value & 0xFF;
  bool get isLight => r >= 170 && g >= 170 && b >= 170;
  String get hex =>
      '#${r.toRadixString(16).padLeft(2, '0')}'
      '${g.toRadixString(16).padLeft(2, '0')}'
      '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
}

Future<void> _report(WidgetTester tester, String label) async {
  final RenderRepaintBoundary boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(_root));
  late ui.Image image;
  late Uint8List bytes;
  await tester.runAsync(() async {
    image = await boundary.toImage();
    final ByteData data =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    bytes = data.buffer.asUint8List();
  });
  final Map<int, int> hist = <int, int>{};
  for (int i = 0; i < bytes.length; i += 4) {
    final int key = (bytes[i] << 16) | (bytes[i + 1] << 8) | bytes[i + 2];
    hist[key] = (hist[key] ?? 0) + 1;
  }
  final List<_Px> top = hist.entries
      .map((MapEntry<int, int> e) => _Px(e.key, e.value))
      .toList()
    ..sort((_Px a, _Px b) => b.count.compareTo(a.count));
  final int total = image.width * image.height;
  final int lightCount =
      top.where((_Px p) => p.isLight).fold(0, (int s, _Px p) => s + p.count);
  final StringBuffer sb = StringBuffer()
    ..writeln('')
    ..writeln('### PROBE $label  (${image.width}x${image.height})')
    ..writeln('    light(>=170 all ch) pixels: $lightCount '
        '(${(100 * lightCount / total).toStringAsFixed(2)}%)');
  for (final _Px p in top.take(6)) {
    sb.writeln('    ${p.hex}  ${p.count}  '
        '(${(100 * p.count / total).toStringAsFixed(2)}%)'
        '${p.isLight ? '   <-- LIGHT' : ''}');
  }
  // Biggest single LIGHT colour block: a slab, not antialiased text.
  final Iterable<_Px> lights = top.where((_Px p) => p.isLight);
  if (lights.isNotEmpty) {
    final _Px biggest = lights.first;
    sb.writeln('    biggest light block: ${biggest.hex} x${biggest.count}');
  }
  // ignore: avoid_print
  print(sb.toString());
  image.dispose();
}

Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
      const Duration(milliseconds: 16),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 6),
    );

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_host(home));
}

Widget _plainScaffold({Widget? body, Widget? drawer}) => Scaffold(
      drawer: drawer,
      body: body ?? const SizedBox.expand(),
    );

void main() {
  testWidgets('P00 baseline scaffold', (WidgetTester tester) async {
    await _pump(tester, _plainScaffold());
    await _settle(tester);
    await _report(tester, 'P00 bare Scaffold');
  });

  testWidgets('P01 first frame (no settle)', (WidgetTester tester) async {
    await _pump(tester, _plainScaffold(body: const Center(child: Text('x'))));
    await _report(tester, 'P01 FIRST FRAME (pumpWidget only)');
  });

  testWidgets('P02 AlertDialog', (WidgetTester tester) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: c,
                builder: (BuildContext _) => AlertDialog(
                  title: const Text('Title'),
                  content: const Text('Body copy'),
                  actions: <Widget>[
                    TextButton(onPressed: () {}, child: const Text('Cancel')),
                    TextButton(onPressed: () {}, child: const Text('OK')),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _report(tester, 'P02 AlertDialog + barrier');
  });

  testWidgets('P03 modal bottom sheet', (WidgetTester tester) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: c,
                builder: (BuildContext _) => const SizedBox(
                  height: 260,
                  child: Center(child: Text('sheet')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _report(tester, 'P03 showModalBottomSheet + barrier');
  });

  testWidgets('P04 date picker', (WidgetTester tester) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDatePicker(
                context: c,
                initialDate: DateTime(2026, 8, 4),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _report(tester, 'P04 showDatePicker');
    // Year grid — yearBackgroundColor is NOT set by the theme.
    await tester.tap(find.byIcon(Icons.arrow_drop_down));
    await _settle(tester);
    await _report(tester, 'P04b showDatePicker YEAR GRID');
  });

  testWidgets('P05 time picker', (WidgetTester tester) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showTimePicker(
                context: c,
                initialTime: const TimeOfDay(hour: 10, minute: 30),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _report(tester, 'P05 showTimePicker');
  });

  testWidgets('P06 snackbar', (WidgetTester tester) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(c).showSnackBar(
                SnackBar(
                  content: const Text('Saved'),
                  action: SnackBarAction(label: 'UNDO', onPressed: () {}),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _report(tester, 'P06 SnackBar');
  });

  testWidgets('P07 popup menu', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: Center(
          child: PopupMenuButton<int>(
            itemBuilder: (BuildContext _) => const <PopupMenuEntry<int>>[
              PopupMenuItem<int>(value: 1, child: Text('One')),
              PopupMenuItem<int>(value: 2, child: Text('Two')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<int>));
    await _settle(tester);
    await _report(tester, 'P07 PopupMenuButton open');
  });

  testWidgets('P08 DropdownButton menu', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: Center(
          child: DropdownButton<String>(
            value: 'a',
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(value: 'a', child: Text('Alpha')),
              DropdownMenuItem<String>(value: 'b', child: Text('Beta')),
            ],
            onChanged: (String? _) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownButton<String>));
    await _settle(tester);
    await _report(tester, 'P08 DropdownButton menu open');
  });

  testWidgets('P09 DropdownMenu (M3)', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: const Center(
          child: DropdownMenu<String>(
            initialSelection: 'a',
            dropdownMenuEntries: <DropdownMenuEntry<String>>[
              DropdownMenuEntry<String>(value: 'a', label: 'Alpha'),
              DropdownMenuEntry<String>(value: 'b', label: 'Beta'),
            ],
          ),
        ),
      ),
    );
    await _report(tester, 'P09a DropdownMenu closed (field)');
    await tester.tap(find.byType(DropdownMenu<String>));
    await _settle(tester);
    await _report(tester, 'P09b DropdownMenu open');
  });

  testWidgets('P10 Tooltip', (WidgetTester tester) async {
    final GlobalKey<TooltipState> k = GlobalKey<TooltipState>();
    await _pump(
      tester,
      _plainScaffold(
        body: Center(
          child: Tooltip(
            key: k,
            message: 'Tooltip copy',
            child: const Icon(Icons.info),
          ),
        ),
      ),
    );
    k.currentState!.ensureTooltipVisible();
    await _settle(tester);
    await _report(tester, 'P10 Tooltip visible');
  });

  testWidgets('P11 Drawer', (WidgetTester tester) async {
    final GlobalKey<ScaffoldState> k = GlobalKey<ScaffoldState>();
    await _pump(
      tester,
      Scaffold(
        key: k,
        drawer: const Drawer(
          child: ListTile(title: Text('Drawer item')),
        ),
        body: const SizedBox.expand(),
      ),
    );
    k.currentState!.openDrawer();
    await _settle(tester);
    await _report(tester, 'P11 Drawer open (drawerTheme UNSET)');
  });

  testWidgets('P12 NavigationDrawer', (WidgetTester tester) async {
    final GlobalKey<ScaffoldState> k = GlobalKey<ScaffoldState>();
    await _pump(
      tester,
      Scaffold(
        key: k,
        drawer: const NavigationDrawer(
          selectedIndex: 0,
          children: <Widget>[
            NavigationDrawerDestination(
              icon: Icon(Icons.home),
              label: Text('Home'),
            ),
            NavigationDrawerDestination(
              icon: Icon(Icons.person),
              label: Text('Profile'),
            ),
          ],
        ),
        body: const SizedBox.expand(),
      ),
    );
    k.currentState!.openDrawer();
    await _settle(tester);
    await _report(tester, 'P12 NavigationDrawer open (navigationDrawerTheme UNSET)');
  });

  testWidgets('P13 NavigationRail', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: NavigationRail(
          selectedIndex: 0,
          destinations: const <NavigationRailDestination>[
            NavigationRailDestination(
              icon: Icon(Icons.home),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.person),
              label: Text('Profile'),
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    await _report(tester, 'P13 NavigationRail (navigationRailTheme UNSET)');
  });

  testWidgets('P14 SearchAnchor.bar + view', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: SearchAnchor.bar(
          barHintText: 'Search',
          suggestionsBuilder:
              (BuildContext c, SearchController controller) => <Widget>[
            const ListTile(title: Text('Result A')),
            const ListTile(title: Text('Result B')),
          ],
        ),
      ),
    );
    await _settle(tester);
    await _report(tester, 'P14a SearchBar closed (searchBarTheme UNSET)');
    await tester.tap(find.byType(SearchBar));
    await _settle(tester);
    await _report(tester, 'P14b SearchView open (searchViewTheme UNSET)');
  });

  testWidgets('P15 SegmentedButton', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: Center(
          child: SegmentedButton<int>(
            segments: const <ButtonSegment<int>>[
              ButtonSegment<int>(value: 1, label: Text('One')),
              ButtonSegment<int>(value: 2, label: Text('Two')),
            ],
            selected: const <int>{1},
            onSelectionChanged: (Set<int> _) {},
          ),
        ),
      ),
    );
    await _settle(tester);
    await _report(tester, 'P15 SegmentedButton (segmentedButtonTheme UNSET)');
  });

  testWidgets('P16 ExpansionTile expanded', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: ListView(
          children: const <Widget>[
            ExpansionTile(
              title: Text('Header'),
              children: <Widget>[ListTile(title: Text('Child'))],
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Header'));
    await _settle(tester);
    final IconThemeData icon =
        IconTheme.of(tester.element(find.byIcon(Icons.expand_more)));
    // ignore: avoid_print
    print('### PROBE P16 ExpansionTile EXPANDED trailing icon color = '
        '${icon.color}  (expansionTileTheme UNSET)');
    await _report(tester, 'P16 ExpansionTile expanded');
  });

  testWidgets('P17 Scrollbar thumb', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: Scrollbar(
          thumbVisibility: true,
          child: ListView.builder(
            itemCount: 60,
            itemBuilder: (BuildContext _, int i) =>
                SizedBox(height: 48, child: Text('row $i')),
          ),
        ),
      ),
    );
    await _settle(tester);
    await _report(tester, 'P17 Scrollbar thumbVisible (scrollbarTheme UNSET)');
  });

  testWidgets('P18 Badge', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: const Center(
          child: Badge(
            label: Text('9'),
            child: Icon(Icons.notifications, size: 48),
          ),
        ),
      ),
    );
    await _settle(tester);
    await _report(tester, 'P18 Badge (badgeTheme UNSET)');
  });

  testWidgets('P19 MaterialBanner bare', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: Column(
          children: <Widget>[
            MaterialBanner(
              content: const Text('Bare banner'),
              actions: <Widget>[
                TextButton(onPressed: () {}, child: const Text('DISMISS')),
              ],
            ),
          ],
        ),
      ),
    );
    await _settle(tester);
    await _report(tester, 'P19 MaterialBanner bare (bannerTheme UNSET)');
  });

  testWidgets('P20 route transition mid-flight', (WidgetTester tester) async {
    final GlobalKey<NavigatorState> nav = GlobalKey<NavigatorState>();
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: _root,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.midnight(),
          themeMode: ThemeMode.dark,
          navigatorKey: nav,
          home: const Scaffold(body: Center(child: Text('A'))),
        ),
      ),
    );
    await _settle(tester);
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            const Scaffold(body: Center(child: Text('B'))),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    await _report(tester, 'P20a route push t=40ms');
    await tester.pump(const Duration(milliseconds: 100));
    await _report(tester, 'P20b route push t=140ms');
    await _settle(tester);
  });

  testWidgets('P21 text field cursor / selection / keyboard', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform p in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = p;
      await _pump(
        tester,
        _plainScaffold(
          body: const Padding(
            padding: EdgeInsets.all(24),
            child: TextField(decoration: InputDecoration(hintText: 'Type')),
          ),
        ),
      );
      await _settle(tester);
      final EditableText e = tester.widget<EditableText>(
        find.byType(EditableText),
      );
      // ignore: avoid_print
      print('### PROBE P21 $p  cursorColor=${e.cursorColor} '
          'selectionColor=${e.selectionColor} '
          'keyboardAppearance=${e.keyboardAppearance}');
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('P22 overscroll indicator', (WidgetTester tester) async {
    for (final TargetPlatform p in <TargetPlatform>[
      TargetPlatform.android,
      TargetPlatform.iOS,
    ]) {
      debugDefaultTargetPlatformOverride = p;
      await _pump(
        tester,
        _plainScaffold(
          body: ListView.builder(
            itemCount: 40,
            itemBuilder: (BuildContext _, int i) =>
                SizedBox(height: 60, child: Text('row $i')),
          ),
        ),
      );
      await _settle(tester);
      final Iterable<GlowingOverscrollIndicator> glows =
          tester.widgetList<GlowingOverscrollIndicator>(
        find.byType(GlowingOverscrollIndicator),
      );
      final bool stretch =
          find.byType(StretchingOverscrollIndicator).evaluate().isNotEmpty;
      // ignore: avoid_print
      print('### PROBE P22 $p  glow=${glows.map((GlowingOverscrollIndicator g) => g.color).toList()} '
          'stretch=$stretch');
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('P23 RefreshIndicator', (WidgetTester tester) async {
    await _pump(
      tester,
      _plainScaffold(
        body: RefreshIndicator(
          onRefresh: () async {},
          child: ListView.builder(
            itemCount: 40,
            itemBuilder: (BuildContext _, int i) =>
                SizedBox(height: 60, child: Text('row $i')),
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    await _report(tester, 'P23 RefreshIndicator pulled');
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('P24 selection toolbar', (WidgetTester tester) async {
    final TextEditingController c = TextEditingController(text: 'hello world');
    addTearDown(c.dispose);
    await _pump(
      tester,
      _plainScaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: TextField(controller: c),
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byType(TextField));
    await _settle(tester);
    await tester.longPress(find.byType(TextField));
    await _settle(tester);
    await _report(tester, 'P24 text selection toolbar (long press)');
  });

  testWidgets('P25 progress + FAB + filled', (WidgetTester tester) async {
    await _pump(
      tester,
      Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          child: const Icon(Icons.add),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            const LinearProgressIndicator(value: 0.6),
            const SizedBox(height: 24),
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            const SizedBox(height: 24),
            Switch(value: true, onChanged: (bool _) {}),
            Slider(value: 0.5, onChanged: (double _) {}),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await _report(tester, 'P25 progress/FAB/filled/switch/slider');
  });

  // P26 — reproduces the EXACT production expression used as the modal barrier
  // in 5 sheet launchers: colorScheme.onSecondaryContainer @ UIConstants
  // .opacityHigh (0.87). Under Midnight onSecondaryContainer is #B9C0F0.
  testWidgets('P26 production sheet scrim expression', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: c,
                isScrollControlled: true,
                backgroundColor: Theme.of(c).colorScheme.surface,
                barrierColor: Theme.of(c)
                    .colorScheme
                    .onSecondaryContainer
                    .withValues(alpha: 0.87),
                builder: (BuildContext _) => const SizedBox(
                  height: 260,
                  child: Center(child: Text('sheet')),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await _settle(tester);
    await _report(tester, 'P26 sheet with PRODUCTION scrim '
        '(onSecondaryContainer @ .87)');
  });

  // P27 — the omds search field draws its OWN focusedBorder from
  // colorScheme.primary, bypassing the app inputDecorationTheme.
  testWidgets('P27 focused input borders', (WidgetTester tester) async {
    final FocusNode appFn = FocusNode();
    final FocusNode omdsFn = FocusNode();
    addTearDown(appFn.dispose);
    addTearDown(omdsFn.dispose);
    await _pump(
      tester,
      Builder(
        builder: (BuildContext c) => _plainScaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: <Widget>[
                TextField(
                  focusNode: appFn,
                  decoration: const InputDecoration(hintText: 'app field'),
                ),
                const SizedBox(height: 24),
                // Byte-faithful copy of OmdsSearchBar's decoration.
                TextField(
                  focusNode: omdsFn,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Theme.of(c).colorScheme.surfaceContainerHighest,
                    hintText: 'omds search field',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(c).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    appFn.requestFocus();
    await _settle(tester);
    await _report(tester, 'P27a app TextField focused');
    omdsFn.requestFocus();
    await _settle(tester);
    await _report(tester, 'P27b OmdsSearchBar-style field focused');
  });
}
