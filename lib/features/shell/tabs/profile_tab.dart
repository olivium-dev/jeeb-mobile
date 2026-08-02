import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/locale/locale_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/screens/settings_screen.dart';
import '../../settings/presentation/widgets/become_jeeber_card.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/previews/jeeb_preview.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = context.watch<LocaleCubit>().state;
    final role = context.watch<RoleCubit>().state;

    return ListView(
      key: const Key('profile-tab-root'),
      padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
      children: [
        BecomeJeeberCard(
          isAlreadyJeeber: role == UserRole.jeeber,
          onTap: () => _openKycFlow(context),
        ),
        OmdsSettingsSection(
          title: l10n.settingsLanguage,
          children: [
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-language-en'),
              title: l10n.settingsLanguageEnglish,
              selected: locale.languageCode == 'en',
              onTap: () => context
                  .read<LocaleCubit>()
                  .setLocale(const Locale('en')),
            ),
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-language-ar'),
              title: l10n.settingsLanguageArabic,
              selected: locale.languageCode == 'ar',
              onTap: () => context
                  .read<LocaleCubit>()
                  .setLocale(const Locale('ar')),
            ),
          ],
        ),
        OmdsSettingsSection(
          title: l10n.settingsRole,
          children: [
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-role-client'),
              title: l10n.settingsRoleClient,
              selected: role == UserRole.client,
              onTap: () =>
                  context.read<RoleCubit>().setRole(UserRole.client),
            ),
            _SelectableSettingsRow(
              rowKey: const Key('settings-row-role-jeeber'),
              title: l10n.settingsRoleJeeber,
              selected: role == UserRole.jeeber,
              onTap: () =>
                  context.read<RoleCubit>().setRole(UserRole.jeeber),
            ),
          ],
        ),
        OmdsSettingsSection(
          title: l10n.settingsAccountSection,
          children: [
            OmdsSettingsRow(
              key: const Key('profile-tab-open-settings'),
              title: l10n.settingsTitle,
              subtitle: l10n.settingsOpenSubtitle,
              leadingIcon: Icons.settings_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SettingsScreen(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openKycFlow(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    router?.goNamed('kyc-status');
  }
}

class _SelectableSettingsRow extends StatelessWidget {
  const _SelectableSettingsRow({
    required this.rowKey,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final Key rowKey;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      button: true,
      inMutuallyExclusiveGroup: true,
      selected: selected,
      child: ExcludeSemantics(
        child: OmdsSettingsRow(
          key: rowKey,
          title: title,
          trailing: selected ? const Icon(Icons.check) : null,
          onTap: onTap,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/shell/profile_tab_preview_test.dart
// ===========================================================================
//
// **This widget is an orphan.** `profile_tab.dart` carries an
// `ORPHAN (JEBV4-227, verified 2026-07-12)` marker: nothing routes to it (the
// shell's Profile tab hosts `CustomerProfileScreen`), and the in-app role
// switch it is built around violates the no-role-switch core UX rule. These
// previews exist so the surface can be *looked at* before it is deleted or
// revived — they are not evidence that it ships.
//
// [ProfileTab] takes no constructor arguments, so every state it can be in is
// a function of the two ambient cubits it watches:
//
//  * [RoleCubit] — decides whether the Become-a-Jeeber card renders at all
//    (T-MOB-027 AC2 hides it once the user already has the Jeeber role) and
//    which of the two role rows carries the check;
//  * [LocaleCubit] — decides which of the two language rows carries the check.
//
// Both are the REAL cubits, over a local in-memory [SharedPreferences]
// stand-in. That keeps the previews network-free by construction rather than
// by the guard in `jeebPreviewHost`, and it keeps the rows genuinely tappable
// in the canvas: tapping "العربية" moves the check, because the write lands in
// the map instead of on disk. `LocaleCubit`'s optional remote
// (`LanguagePreferenceRepository`) is deliberately left null — that is the one
// seam in this tree that would talk to a gateway.
//
// Each preview pins its own width instead of leaving it to the canvas [Size].
// The canvas honours `size`, but the render tests in `test/previews/` pump
// onto a fixed 800 × 600 surface — so a 320 pt state that only asked for a
// 320 pt canvas would be rendered at 800 pt under test and silently become
// the same widget as the default one.
//
// Three things these previews surfaced, all in the widgets rather than in the
// previews — see the notes on the individual states:
//
//  * the settings sections have **no horizontal inset at all** (title and row
//    text start at x = 0), while the Become-a-Jeeber card directly above them
//    is inset by 16 pt;
//  * the card's text column is squeezed to ~111 pt at 390 pt wide and ~41 pt
//    at 320 pt, so "Become a Jeeber" wraps to 3 lines on a normal phone and to
//    7 on a small one — at 1× text scale;
//  * at 200% text that same row overflows outright (15 pt at 390, 85 pt at
//    320). Nothing else in the tab overflows: the jeeber state, which differs
//    only by the card being gone, is clean at 200% in both locales.

/// A typical phone: the width both cubit-driven states are designed against.
const double _profileTabPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen, and
/// the small Android estate). The Become-a-Jeeber card's single [Row] —
/// avatar + expanded text + CTA button — is the squeeze point.
const double _profileTabNarrowPhoneWidth = 320;

/// A full tab, not a widget: tall enough for all four blocks (card + three
/// settings sections) so the canvas shows the whole surface without scrolling.
const Size _profileTabBox = Size(_profileTabPhoneWidth, 780);

/// Same height, narrow width.
const Size _profileTabNarrowBox = Size(_profileTabNarrowPhoneWidth, 780);

/// An in-memory stand-in for [SharedPreferences].
///
/// [RoleCubit] and [LocaleCubit] both REQUIRE a `SharedPreferences`, and the
/// real one is async (`getInstance()`) and platform-channel backed — neither of
/// which a synchronous `Widget Function()` preview can have. This answers from
/// a plain map, so construction is synchronous and a write in the canvas is
/// simply a map write.
class _ProfileTabInMemoryPrefs implements SharedPreferences {
  _ProfileTabInMemoryPrefs([Map<String, Object>? seed])
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
class _ProfileTabViewport extends StatelessWidget {
  const _ProfileTabViewport({required this.width, required this.child});

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
Widget _profileTabHosted({
  required UserRole role,
  required Locale locale,
  double width = _profileTabPhoneWidth,
}) {
  final SharedPreferences prefs = _ProfileTabInMemoryPrefs();
  return _ProfileTabViewport(
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
@JeebPreview(group: 'shell', name: 'Client', size: _profileTabBox)
Widget profileTabClient() => _profileTabHosted(
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
@JeebPreview(group: 'shell', name: 'Jeeber', size: _profileTabBox)
Widget profileTabJeeber() => _profileTabHosted(
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
@JeebPreview(group: 'shell', name: 'Arabic selected', size: _profileTabBox)
Widget profileTabArabicSelected() => _profileTabHosted(
      role: UserRole.client,
      locale: const Locale('ar'),
    );

/// Layout ceiling: the same Client surface at [_profileTabNarrowPhoneWidth].
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
@JeebPreview(group: 'shell', name: 'Narrow 320', size: _profileTabNarrowBox)
Widget profileTabNarrowPhone() => _profileTabHosted(
      role: UserRole.client,
      locale: const Locale('en'),
      width: _profileTabNarrowPhoneWidth,
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
@JeebPreview(
  group: 'shell',
  name: 'Jeeber narrow · Arabic',
  size: _profileTabNarrowBox,
)
Widget profileTabJeeberNarrowArabic() => _profileTabHosted(
      role: UserRole.jeeber,
      locale: const Locale('ar'),
      width: _profileTabNarrowPhoneWidth,
    );
