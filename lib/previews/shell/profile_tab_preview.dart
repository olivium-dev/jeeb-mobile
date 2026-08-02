/// Widget previews for [ProfileTab] — run with
/// `flutter widget-preview start`.
///
/// **This widget is an orphan.** `profile_tab.dart` carries an
/// `ORPHAN (JEBV4-227, verified 2026-07-12)` marker: nothing routes to it (the
/// shell's Profile tab hosts `CustomerProfileScreen`), and the in-app role
/// switch it is built around violates the no-role-switch core UX rule. These
/// previews exist so the surface can be *looked at* before it is deleted or
/// revived — they are not evidence that it ships.
///
/// [ProfileTab] takes no constructor arguments, so every state it can be in is
/// a function of the two ambient cubits it watches:
///
///  * [RoleCubit] — decides whether the Become-a-Jeeber card renders at all
///    (T-MOB-027 AC2 hides it once the user already has the Jeeber role) and
///    which of the two role rows carries the check;
///  * [LocaleCubit] — decides which of the two language rows carries the check.
///
/// Both are the REAL cubits, over a local in-memory [SharedPreferences]
/// stand-in. That keeps the previews network-free by construction rather than
/// by the guard in `jeebPreviewHost`, and it keeps the rows genuinely tappable
/// in the canvas: tapping "العربية" moves the check, because the write lands in
/// the map instead of on disk. `LocaleCubit`'s optional remote
/// (`LanguagePreferenceRepository`) is deliberately left null — that is the one
/// seam in this tree that would talk to a gateway.
///
/// Each preview pins its own width instead of leaving it to the canvas [Size].
/// The canvas honours `size`, but the render tests in `test/previews/` pump
/// onto a fixed 800 × 600 surface — so a 320 pt state that only asked for a
/// 320 pt canvas would be rendered at 800 pt under test and silently become
/// the same widget as the default one.
///
/// Three things these previews surfaced, all in the widgets rather than in the
/// previews — see the notes on the individual states:
///
///  * the settings sections have **no horizontal inset at all** (title and row
///    text start at x = 0), while the Become-a-Jeeber card directly above them
///    is inset by 16 pt;
///  * the card's text column is squeezed to ~111 pt at 390 pt wide and ~41 pt
///    at 320 pt, so "Become a Jeeber" wraps to 3 lines on a normal phone and to
///    7 on a small one — at 1× text scale;
///  * at 200% text that same row overflows outright (15 pt at 390, 85 pt at
///    320). Nothing else in the tab overflows: the jeeber state, which differs
///    only by the card being gone, is clean at 200% in both locales.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/locale/locale_cubit.dart';
import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../../features/shell/tabs/profile_tab.dart';
import '../harness/jeeb_preview.dart';

/// A typical phone: the width both cubit-driven states are designed against.
const double _phoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen, and
/// the small Android estate). The Become-a-Jeeber card's single [Row] —
/// avatar + expanded text + CTA button — is the squeeze point.
const double _narrowPhoneWidth = 320;

/// A full tab, not a widget: tall enough for all four blocks (card + three
/// settings sections) so the canvas shows the whole surface without scrolling.
const Size _tabBox = Size(_phoneWidth, 780);

/// Same height, narrow width.
const Size _narrowTabBox = Size(_narrowPhoneWidth, 780);

/// An in-memory stand-in for [SharedPreferences].
///
/// [RoleCubit] and [LocaleCubit] both REQUIRE a `SharedPreferences`, and the
/// real one is async (`getInstance()`) and platform-channel backed — neither of
/// which a synchronous `Widget Function()` preview can have. This answers from
/// a plain map, so construction is synchronous and a write in the canvas is
/// simply a map write.
class _InMemoryPrefs implements SharedPreferences {
  _InMemoryPrefs([Map<String, Object>? seed])
      : _store = <String, Object>{...?seed};

  final Map<String, Object> _store;

  @override
  Object? get(String key) => _store[key];

  @override
  bool? getBool(String key) => _store[key] as bool?;

  @override
  double? getDouble(String key) => _store[key] as double?;

  @override
  int? getInt(String key) => _store[key] as int?;

  @override
  String? getString(String key) => _store[key] as String?;

  @override
  List<String>? getStringList(String key) =>
      (_store[key] as List<String>?)?.toList();

  @override
  Set<String> getKeys() => _store.keys.toSet();

  @override
  bool containsKey(String key) => _store.containsKey(key);

  @override
  Future<bool> setBool(String key, bool value) => _put(key, value);

  @override
  Future<bool> setDouble(String key, double value) => _put(key, value);

  @override
  Future<bool> setInt(String key, int value) => _put(key, value);

  @override
  Future<bool> setString(String key, String value) => _put(key, value);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _put(key, value);

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _store.clear();
    return true;
  }

  @override
  Future<bool> commit() async => true;

  @override
  Future<void> reload() async {}

  Future<bool> _put(String key, Object value) async {
    _store[key] = value;
    return true;
  }
}

/// Pins the width [ProfileTab] is laid out against, so the canvas and the
/// render tests see the same line breaks. Top-aligned because the tab is a
/// [ListView] and must keep the full height it is offered.
class _Viewport extends StatelessWidget {
  const _Viewport({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(width: width, child: child),
    );
  }
}

/// Seats [ProfileTab] under the two cubits it watches.
///
/// [role] and [locale] are passed as explicit initial values rather than seeded
/// through the prefs map so the state is readable here and cannot drift with
/// either cubit's storage-key or device-locale resolution.
Widget _hosted({
  required UserRole role,
  required Locale locale,
  double width = _phoneWidth,
}) {
  final SharedPreferences prefs = _InMemoryPrefs();
  return _Viewport(
    width: width,
    child: MultiBlocProvider(
      providers: <BlocProvider<Object?>>[
        BlocProvider<RoleCubit>(
          create: (_) => RoleCubit(prefs: prefs, initialRole: role),
        ),
        BlocProvider<LocaleCubit>(
          create: (_) => LocaleCubit(
            prefs: prefs,
            deviceLocaleProvider: () => locale,
          ),
        ),
      ],
      child: const ProfileTab(),
    ),
  );
}

/// The default surface: a Client who has never taken on the Jeeber role.
///
/// This is the only state in which the Become-a-Jeeber card exists, so it is
/// also the tallest — and the one place the tab mixes two different horizontal
/// insets. Measured at 390 pt: the card is inset by `Spacing.medium`, but every
/// settings section below it starts at x = 0, because `OmdsSettingsSection`
/// adds no horizontal padding, `OmdsSettingsRow` is built with
/// `contentPadding: EdgeInsets.zero`, and `ProfileTab`'s own `ListView` padding
/// is vertical-only. "Language", "English", "Role" and "Account" therefore
/// touch the screen edge.
///
/// The card is also 204 pt tall here, not the ~80 pt its design implies: its
/// single `Row` gives the CTA and the avatar priority, leaving the
/// `Expanded` text column ~111 pt, so the title wraps to three lines.
@JeebPreview(group: 'shell', name: 'Client', size: _tabBox)
Widget profileTabClient() => _hosted(
      role: UserRole.client,
      locale: const Locale('en'),
    );

/// T-MOB-027 AC2, made visible: once the user's `available_roles` already
/// include Jeeber, the Become-a-Jeeber card must disappear entirely — not grey
/// out, not show "already a jeeber".
///
/// Worth a preview of its own because the card collapses to a
/// `SizedBox.shrink()`, so the failure mode is a silent 100 pt of the tab
/// vanishing rather than an error. The check also moves to the Jeeber role row.
@JeebPreview(group: 'shell', name: 'Jeeber', size: _tabBox)
Widget profileTabJeeber() => _hosted(
      role: UserRole.jeeber,
      locale: const Locale('en'),
    );

/// The selection state the check-icon logic can invert: [LocaleCubit] holds
/// Arabic, so the check belongs on the **second** language row.
///
/// The AR RTL rendering of this preview is the true production state (in the
/// app the same cubit drives both the check and `MaterialApp.locale`); the EN
/// rendering exists so the check can be seen moving without the labels
/// changing script at the same time.
@JeebPreview(group: 'shell', name: 'Arabic selected', size: _tabBox)
Widget profileTabArabicSelected() => _hosted(
      role: UserRole.client,
      locale: const Locale('ar'),
    );

/// Layout ceiling: the same Client surface at [_narrowPhoneWidth].
///
/// The Become-a-Jeeber card lays out avatar + `Expanded(text)` + an
/// `OmdsPrimaryButton` in ONE unwrapped [Row], and neither the avatar nor the
/// button ever yields, so the 70 pt lost here come entirely out of the text.
/// Measured: the text column collapses to ~41 pt and "Become a Jeeber" wraps to
/// seven lines, making the card 168 pt tall — at 1× text scale, before any
/// accessibility setting is involved.
///
/// The 200%-text rendering of this state is the one to open first: the row
/// overflows by 85 pt there (15 pt at 390). The jeeber states, which differ
/// only in that the card is absent, are clean at 200% — the card is the whole
/// problem.
@JeebPreview(group: 'shell', name: 'Narrow 320', size: _narrowTabBox)
Widget profileTabNarrowPhone() => _hosted(
      role: UserRole.client,
      locale: const Locale('en'),
      width: _narrowPhoneWidth,
    );

/// A jeeber on the narrow phone, in the Arabic selection.
///
/// The combination matters because the thing that shortens the tab (no card)
/// and the things that lengthen its rows (narrow width, Arabic labels in the
/// RTL rendering) only ever meet here: this is the rendering where the settings
/// rows themselves — not the card — have to hold up. They do: the check mirrors
/// to the left edge, and nothing overflows even at 200% text. The two language
/// rows stay "English" / "العربية" in both locales on purpose — a language is
/// named in its own script.
@JeebPreview(group: 'shell', name: 'Jeeber narrow · Arabic', size: _narrowTabBox)
Widget profileTabJeeberNarrowArabic() => _hosted(
      role: UserRole.jeeber,
      locale: const Locale('ar'),
      width: _narrowPhoneWidth,
    );
