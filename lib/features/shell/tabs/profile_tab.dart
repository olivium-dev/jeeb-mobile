import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/locale/locale_cubit.dart';
import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
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
            const _LanguageSyncPendingNote(),
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
    if (router == null) {
      // The card only mounts inside the shell, so this is unreachable in
      // production — but a silent no-op must still be traceable.
      Diag.event('profile_tab_kyc_nav_unavailable');
      return;
    }
    router.goNamed('kyc-status');
  }
}

/// LANG-01: the local language change has not reached the server yet, so the
/// row's selection is honest but not synced.
class _LanguageSyncPendingNote extends StatelessWidget {
  const _LanguageSyncPendingNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: context.read<LocaleCubit>().languagePushPending,
      builder: (BuildContext context, bool pending, _) {
        if (!pending) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.xSmall,
          ),
          child: Semantics(
            identifier: 'language_sync_pending_note',
            container: true,
            child: JeebInfoNote.muted(text: l10n.languageSyncPendingBody),
          ),
        );
      },
    );
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
// DEV-ONLY, NOT SHIPPED.

/// A typical phone: the width both cubit-driven states are designed against.
const double _profileTabPhoneWidth = 390;

/// The narrowest width the app still has to survive (iPhone SE 1st gen, and
/// the small Android estate). The Become-a-Jeeber card's single [Row] —
const double _profileTabNarrowPhoneWidth = 320;

/// A full tab, not a widget: tall enough for all four blocks (card + three
/// settings sections) so the canvas shows the whole surface without scrolling.
const Size _profileTabBox = Size(_profileTabPhoneWidth, 780);

/// Same height, narrow width.
const Size _profileTabNarrowBox = Size(_profileTabNarrowPhoneWidth, 780);

/// An in-memory stand-in for [SharedPreferences].
/// [RoleCubit] and [LocaleCubit] both REQUIRE a `SharedPreferences`, and the
/// real one is async (`getInstance()`) and platform-channel backed — neither of
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
/// [role] and [locale] are passed as explicit initial values rather than seeded
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
/// This is the only state in which the Become-a-Jeeber card exists, so it is
@JeebPreview(group: 'shell', name: 'Client', size: _profileTabBox)
Widget profileTabClient() => _profileTabHosted(
      role: UserRole.client,
      locale: const Locale('en'),
    );

/// T-MOB-027 AC2, made visible: once the user's `available_roles` already
/// include Jeeber, the Become-a-Jeeber card must disappear entirely — not grey
@JeebPreview(group: 'shell', name: 'Jeeber', size: _profileTabBox)
Widget profileTabJeeber() => _profileTabHosted(
      role: UserRole.jeeber,
      locale: const Locale('en'),
    );

/// The selection state the check-icon logic can invert: [LocaleCubit] holds
/// Arabic, so the check belongs on the **second** language row.
@JeebPreview(group: 'shell', name: 'Arabic selected', size: _profileTabBox)
Widget profileTabArabicSelected() => _profileTabHosted(
      role: UserRole.client,
      locale: const Locale('ar'),
    );

/// Layout ceiling: the same Client surface at [_profileTabNarrowPhoneWidth].
/// The Become-a-Jeeber card lays out avatar + `Expanded(text)` + an
@JeebPreview(group: 'shell', name: 'Narrow 320', size: _profileTabNarrowBox)
Widget profileTabNarrowPhone() => _profileTabHosted(
      role: UserRole.client,
      locale: const Locale('en'),
      width: _profileTabNarrowPhoneWidth,
    );

/// A jeeber on the narrow phone, in the Arabic selection.
/// The combination matters because the thing that shortens the tab (no card)
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
