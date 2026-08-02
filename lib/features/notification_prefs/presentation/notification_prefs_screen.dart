import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
// The domain import is the typed-failure vocabulary the fixtures take
// (`fetchFailure:` / `saveFailure:`); the screen itself deliberately does not
// know it — `NotificationPrefsState` exposes its own `NotificationPrefsFailureView`
// so the presentation switch stays exhaustive without importing `data/`.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/notification_prefs_screen_fixtures.dart';
import '../domain/notification_prefs_repository.dart';

/// Notification Preferences screen (JM-058).
/// Categories: offers, order-status, wallet, marketing (debounced PUT toggles).
/// Transactional class locked (always-on). Push-channel preferences only.
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() =>
      _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationPrefsCubit>().load();
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('customer-profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'notif_prefs_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.notificationPreferencesTitle,
          leading: Semantics(
            identifier: 'notif_prefs_back',
            button: true,
            container: true,
            child: IconButton(
              icon: Icon(DirectionalIcons.back(context)),
              tooltip: l10n.kycWizardBack,
              onPressed: _onBack,
            ),
          ),
        ),
        body: BlocConsumer<NotificationPrefsCubit, NotificationPrefsState>(
          listenWhen: _shouldListen,
          listener: _onSaveError,
          builder: _buildBody,
        ),
      ),
    );
  }

  bool _shouldListen(
    NotificationPrefsState prev,
    NotificationPrefsState curr,
  ) {
    return curr is NotificationPrefsLoaded &&
        curr.saveError &&
        (prev is! NotificationPrefsLoaded || !prev.saveError);
  }

  void _onSaveError(BuildContext context, NotificationPrefsState state) {
    final l10n = AppLocalizations.of(context);
    showOmdsSnackbar(context, message: l10n.notificationPrefsSaveError);
    context.read<NotificationPrefsCubit>().acknowledgeError();
  }

  Widget _buildBody(BuildContext context, NotificationPrefsState state) {
    switch (state) {
      case NotificationPrefsLoading():
        return const Center(child: OmdsLoadingState());
      case NotificationPrefsError():
        return _ErrorView(onRetry: context.read<NotificationPrefsCubit>().load);
      case NotificationPrefsLoaded(:final prefs):
        return _PrefsBody(prefs: prefs);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.notificationPrefsLoadError),
          const SizedBox(height: Spacing.medium),
          Semantics(
            identifier: 'notif_prefs_retry_cta',
            button: true,
            container: true,
            child: OMDSOutlinedButton(
              text: l10n.notificationPrefsRetry,
              onTap: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrefsBody extends StatelessWidget {
  const _PrefsBody({required this.prefs});

  final NotificationPrefs prefs;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<NotificationPrefsCubit>();
    return ListView(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      children: [
        const _PushOnlyNote(),
        _CategoriesSection(prefs: prefs, cubit: cubit),
        if (prefs.transactionalLocked) const _TransactionalLockedSection(),
      ],
    );
  }
}

/// Push-only note (R2).
class _PushOnlyNote extends StatelessWidget {
  const _PushOnlyNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'notif_prefs_push_only_note',
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: Spacing.small),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline,
              size: Sizes.medium,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                l10n.notificationPreferencesRowSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection({required this.prefs, required this.cubit});

  final NotificationPrefs prefs;
  final NotificationPrefsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = prefs.categories;
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesCategoriesSection,
      children: [
        _CategoryRow(
          identifier: 'notif_prefs_offers_toggle',
          title: l10n.notificationCategoryOffers,
          subtitle: l10n.notificationCategoryOffersSubtitle,
          value: c.offers,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.offers, v),
        ),
        _CategoryRow(
          identifier: 'notif_prefs_order_status_toggle',
          title: l10n.notificationCategoryStatus,
          subtitle: l10n.notificationCategoryStatusSubtitle,
          value: c.orderStatus,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.orderStatus, v),
        ),
        _CategoryRow(
          identifier: 'notif_prefs_wallet_toggle',
          title: l10n.notificationCategoryWallet,
          subtitle: l10n.notificationCategoryWalletSubtitle,
          value: c.wallet,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.wallet, v),
        ),
        _CategoryRow(
          identifier: 'notif_prefs_marketing_toggle',
          title: l10n.notificationCategoryRatingReminders,
          subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
          value: c.marketing,
          onChanged: (v) =>
              cubit.toggleCategory(NotificationCategory.marketing, v),
        ),
      ],
    );
  }
}

/// Locked transactional class (D64): always-on, cannot be disabled.
class _TransactionalLockedSection extends StatelessWidget {
  const _TransactionalLockedSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return OmdsSettingsSection(
      title: l10n.notificationPreferencesSecuritySection,
      children: [
        Semantics(
          identifier: 'notif_prefs_transactional_lock_icon',
          container: true,
          child: OmdsSettingsSwitchRow(
            title: l10n.notificationCategoryOtp,
            subtitle: l10n.notificationCategoryOtpAlwaysOn,
            value: true,
            enabled: false,
            onChanged: null,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.identifier,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String identifier;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      toggled: value,
      container: true,
      child: OmdsSettingsSwitchRow(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: onChanged,
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
// Render tests: test/previews/notification_prefs/notification_prefs_screen_preview_test.dart
// ===========================================================================
//
// [NotificationPrefsScreen] is the real notification-preferences surface. The
// thing in `features/settings/presentation/screens/` with the longer name is a
// five-line wrapper that builds this screen's cubit; everything a user sees is
// declared here. Four things follow from that, and they are why these previews
// do not look like a widget's.
//
// 1. The screen owns a `Scaffold` and [jeebPreviewHost] wraps every child in
//    one as well, so the canvas shows two nested Scaffolds. The inner one is
//    the real surface; the outer contributes a background and a `SafeArea`.
//
// 2. The canvas box is a real device, not the harness's 390x200 default — six
//    settings rows under an app bar cannot be judged in a 200 pt strip. The
//    device is pinned INSIDE the fixture (a `MediaQuery` override plus a
//    `SizedBox`) rather than left to `size:`, because the render tests pump
//    onto a fixed 800 x 600 surface: a state that merely ASKED for a 320 x 568
//    canvas would be measured at 800 x 600 and the compact window would
//    silently become the phone one.
//
// 3. There is no ctor seam. `initState` calls
//    `context.read<NotificationPrefsCubit>().load()`, so `NotificationPrefsScreen()`
//    on its own throws `ProviderNotFoundException` and the ONLY way to reach a
//    designed state is a `BlocProvider` over a scripted repository —
//    [notificationPrefsScreenSeeded], shared with the Screen Catalog entry
//    (`lib/devtool/catalog/entries/batch_07_entries.dart`). Nothing below
//    constructs `DioNotificationPrefsRepository` or touches GetIt, so these are
//    network-free by construction, not by the guard in [jeebPreviewHost].
//
// 4. Its one navigation affordance THROWS without a router. `_onBack` calls
//    `context.canPop()`, a GoRouter extension that raises when no `Router` is
//    in scope, and none of that happens during `build` — so a naive host paints
//    perfectly and dies on the first tap of the app-bar arrow. The shared
//    fixture host seeds the production stack instead
//    (`settings-notifications` is declared as a CHILD of `/settings`, so
//    LiveSettingsScreen sits underneath and the arrow pops to it).
//
// Every loaded state renders the SAME fifteen ARB strings — two section
// headers, four category rows with their subtitles, the push-only note and the
// locked transactional row are all static — and a fixture changes only the
// value of four `Switch`es. "Did it render" is therefore a weak question here,
// so each preview is captioned with the fixture it is wired to (the string the
// render test pins) and the test asserts the switch values, which is the only
// thing that actually differs.
//
// What these previews exposed in the screen:
//
//  * **A confirmation dialog that exists in three languages and no code.** The
//    ARB ships `notificationPreferencesDisableOffersTitle` ("Stop offer
//    notifications?"), `…Body` and `…Confirm` ("Turn off"), described in the
//    ARB itself as "the confirmation dialog shown when the user turns the
//    offers toggle off", with generated getters in `app_localizations.dart` and
//    Arabic translations. Nothing in this file — or anywhere under `lib/` —
//    reads them. The offers row turns off on one tap, silently, exactly like
//    the other three. [notificationPrefsScreenAllOff] is that end state, and
//    the render test taps offers off to pin that no dialog appears.
//  * **The typed load failure is computed and then thrown away.** The cubit
//    maps the repository's `NotificationPrefsFailure` onto a
//    `NotificationPrefsFailureView` and `NotificationPrefsError` carries it —
//    and `_ErrorView` never reads it. `network` and `unknown` render the same
//    `notificationPrefsLoadError` line, so an offline user is told "Couldn't
//    load your notification preferences." with no hint that the problem is
//    their connection, and is offered a Retry that will fail the same way.
//  * **`_ErrorView` has no horizontal padding and no scroll.** It is a bare
//    `Center` > `Column`, while every other surface on this screen sits in
//    `Spacing.medium`. At 100% on a 390 pt phone that costs nothing — the
//    failure line is one 298 pt line and the missing margin is invisible in
//    review. At 200% on a 320 pt device the same line wraps to three that start
//    on the left screen border and end on the right one, with no margin at all.
//    Measured with the real faces: it does not overflow and Retry stays on
//    screen, so this is a polish defect rather than a broken state — but the
//    body cannot scroll in the error state, only in the loaded one, so there is
//    no headroom left if the copy ever grows.
//  * **`NotificationPrefsLoaded.isSaving` is emitted and never rendered.** The
//    cubit sets it before every debounced PATCH; the word does not appear in
//    this file. The switch stays interactive and unmarked while the write is in
//    flight, so the only feedback a save ever gives is the snackbar that
//    appears when it FAILS — success is silent and indistinguishable from not
//    having saved. [notificationPrefsScreenSaveFails] is where that shows: tap
//    a row, it flips instantly, sits through the 500 ms debounce plus the round
//    trip, then flips back under a snackbar.
//  * **Back has two answers and the dartdoc names the unreachable one.**
//    `_onBack` falls through to `goNamed('customer-profile')` only when nothing
//    can pop, but `settings-notifications` is declared as a CHILD of
//    `/settings` and go_router materializes a page for every matched ancestor
//    with a builder — so `canPop()` is true on every route into this screen and
//    the arrow always pops to LiveSettingsScreen. The fallback is dead, and
//    were it live it would disagree with the router's own registered fallback
//    for this route, `AppRouter.backFallbacks['settings-notifications'] ==
//    '/settings'`, which is what the SYSTEM back gesture uses.
//  * **The locked Security section is conditional on a flag nothing can turn
//    off.** `_PrefsBody` renders it behind `if (prefs.transactionalLocked)`
//    while `DioNotificationPrefsRepository._parse` hardcodes
//    `transactionalLocked: true` on both of its parse paths. The branch is dead
//    in production, and [notificationPrefsScreenTransactionalUnlocked] shows
//    what it costs if it ever wakes up: the whole section disappears, taking
//    `notif_prefs_transactional_lock_icon` — an id JM-058 AC2 and the on-device
//    jm-058 flow both assert — out of the semantics tree with it.
//  * **At the accessibility ceiling the locked row is not merely below the
//    fold, it is not BUILT.** On a 320 x 568 device at 200% the body carries
//    814 pt of scroll behind a 512 pt viewport and the `ListView` stops
//    building past its viewport plus cache extent: four of the five rows exist
//    on arrival and `notif_prefs_transactional_lock_icon` is absent from the
//    widget tree AND from the semantics tree until the user scrolls to it. A
//    driver or a screen reader querying the id the AC publishes finds nothing.
//    The 814 pt is measured with the REAL Inter face; the same layout under
//    `flutter_test`'s 1-em square face reports 1618 pt, which is where the
//    figure in the wrapper screen's preview section comes from. Halving the
//    extent does not change the conclusion — the locked row is LAST, so it is
//    the first thing to fall off either way.
//  * The good news, recorded because it is cheap to lose: nothing overflows.
//    Every state renders clean in EN and AR, at 100% and 200% text, on a
//    390 x 844 phone and on a 320 x 568 one. `OmdsSettingsSwitchRow` keeps its
//    title column inside the tile's own constraints, so copy wraps instead of
//    pushing the switch off the trailing edge, and the loaded body is a
//    `ListView` that simply grows a scroll extent.

/// The canvas box for a whole screen: a real phone, plus the fixture's 1 pt
/// outline (12 pt) and its caption strip (44 pt).
const Size _notificationPrefsScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on, framed the
/// same way.
const Size _notificationPrefsScreenCompactCanvas = Size(332, 612);

/// Every state is the same screen behind the same app bar, differing only in
/// the fake repository its cubit is built on — so each one names itself.
///
/// The `NotificationPrefsScreen()` is constructed HERE rather than inside the
/// shared fixture: `tool/preview_coverage.dart` credits a section only when it
/// literally builds the widget its previews are named after, and it keeps the
/// fixture library free of a circular import back into this one.
Widget _notificationPrefsScreenHosted(
  NotificationPreferencesScreenFakeRepository repository, {
  required String caption,
  NotificationPreferencesScreenWindow window =
      NotificationPreferencesScreenWindows.phone,
}) =>
    NotificationPreferencesScreenPreviewHost(
      window: window,
      caption: caption,
      screen: notificationPrefsScreenSeeded(
        repository: repository,
        child: const NotificationPrefsScreen(),
      ),
    );

/// Cold start: `GET /v1/notifications/preferences` is on the wire.
///
/// The cubit is constructed in `NotificationPrefsLoading` and `initState` calls
/// `load()`, which emits it again — so this is what every user sees first: a
/// centered 48 pt spinner under a titled app bar, with no skeleton of the rows
/// about to arrive and nothing to say what is loading. The fake never resolves,
/// so the state holds for as long as the canvas is open.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loading',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenLoading() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenPendingRepository(),
      caption: 'NotifPrefs · Loading · phone 390 × 844',
    );

/// The happy path, and the exact snapshot the Screen Catalog's `Loaded` state
/// has always shown: offers and order status on, wallet and marketing off,
/// transactional locked.
///
/// Matrixed because this is a stack of `title + subtitle | switch` rows and the
/// AR card is where the whole row mirrors — the switch has to land on the left
/// and the two-line text column on the right — while the 200% card is where the
/// six rows stop fitting a phone and the composition becomes a scroll. It is
/// also the only loaded state whose four switches are not all the same value,
/// so it is where a row wired to the wrong field would show.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · catalog defaults',
  size: _notificationPrefsScreenPhoneCanvas,
  matrix: true,
)
Widget notificationPrefsScreenLoaded() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPrefsScreenCatalogPrefs,
      ),
      caption: 'NotifPrefs · Loaded · catalog defaults · phone 390 × 844',
    );

/// Everything the user is allowed to turn off, turned off.
///
/// The nearest thing this screen has to an EMPTY state — there is no list to be
/// empty, so "opted out of everything" is the degenerate reading. It is the one
/// state in which the locked Security row is legible as a statement rather than
/// as one more switch that happens to be on, and the one that shows how little
/// separates the two: the locked row differs only by opacity, and at a glance
/// it reads as a category the user simply forgot to turn off.
///
/// It is also the end state of the confirmation dialog that does not exist —
/// the ARB has "Stop offer notifications?" copy for the moment the offers row
/// goes off, and reaching this state takes four unguarded taps.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · everything off',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenAllOff() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenAllOffPrefs,
      ),
      caption: 'NotifPrefs · Everything off · phone 390 × 844',
    );

/// The initial fetch failed with a typed `network` failure.
///
/// The cubit classified it — `NotificationPrefsFailureView.network` — and
/// `_ErrorView` discards the classification, so this renders exactly what an
/// `unknown` failure renders: one generic line and a Retry. There is no "check
/// your connection" copy anywhere on the screen and no state in which the two
/// failures can be told apart.
///
/// Matrixed for the second thing it shows: `_ErrorView` is a bare `Center` >
/// `Column` with no horizontal padding and no scroll view, so the 200% card is
/// where the failure line runs edge-to-edge and the column stops having room —
/// the loaded body can scroll, this one cannot.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Error · fetch failed',
  size: _notificationPrefsScreenPhoneCanvas,
  matrix: true,
)
Widget notificationPrefsScreenError() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        fetchFailure: NotificationPrefsFailure.network,
      ),
      caption: 'NotifPrefs · Error · fetch failed · phone 390 × 844',
    );

/// Loaded, but the next PATCH will fail — the D30 optimistic-revert path.
///
/// Identical to `Loaded · catalog defaults` until you touch it, which is the
/// point: the screen renders no in-flight affordance at all
/// (`NotificationPrefsLoaded.isSaving` is emitted by the cubit and read by
/// nothing), so a toggle flips instantly, stays flipped through the 500 ms
/// debounce and the round trip, then silently flips BACK under an OMDS
/// snackbar. This is the only preview in the file that has to be tapped to show
/// its state; the render test taps it.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · the save will fail',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenSaveFails() => _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPrefsScreenCatalogPrefs,
        saveFailure: NotificationPrefsFailure.network,
      ),
      caption: 'NotifPrefs · Save will fail · phone 390 × 844',
    );

/// `transactionalLocked: false` — the branch `_PrefsBody` guards and the
/// gateway cannot currently produce.
///
/// The entire Security section disappears: the header, the always-on row, and
/// `notif_prefs_transactional_lock_icon` with them. That id is named in the
/// JM-058 AC and asserted by the on-device jm-058 flow, so this is the shape in
/// which the screen still "works" while the acceptance test goes red. Kept
/// visible precisely because `DioNotificationPrefsRepository._parse` hardcodes
/// the flag true on both parse paths today — nothing else in the repo exercises
/// this branch.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · transactional unlocked',
  size: _notificationPrefsScreenPhoneCanvas,
)
Widget notificationPrefsScreenTransactionalUnlocked() =>
    _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPreferencesScreenUnlockedPrefs,
      ),
      caption: 'NotifPrefs · Transactional unlocked · phone 390 × 844',
    );

/// The longest this screen's content ever gets: the smallest display AND the
/// largest text.
///
/// There is no data axis to stretch — every string is a fixed ARB key — so the
/// content ceiling here is the text scale, and five two-line rows plus two
/// section headers plus the push-only note at 200% on a 320 x 568 device is
/// where the composition stops fitting. Nothing overflows;
/// `OmdsSettingsSwitchRow` wraps its title column inside the tile's own
/// constraints instead of shoving the switch off the trailing edge, and the
/// body simply becomes a long scroll — 814 pt of it behind a 512 pt viewport,
/// measured with the real Inter face. What it costs is reachability: only FOUR
/// of the five rows are built on arrival, because the `ListView` stops at its
/// viewport plus cache extent. The one that falls off is the last one — the
/// locked Security row — so `notif_prefs_transactional_lock_icon` is absent
/// from the widget tree AND from the semantics tree until the user scrolls, and
/// it is the id JM-058 AC2 publishes as the QA target. Pinned by the render
/// test.
@JeebPreview(
  group: 'notification_prefs',
  name: 'Loaded · compact · 200% text',
  size: _notificationPrefsScreenCompactCanvas,
)
Widget notificationPrefsScreenCompactLargeText() =>
    _notificationPrefsScreenHosted(
      const NotificationPreferencesScreenFakeRepository(
        prefs: notificationPrefsScreenCatalogPrefs,
      ),
      caption: 'NotifPrefs · Longest content · compact 320 × 568 · 200% text',
      window: NotificationPreferencesScreenWindows.compactLargeText,
    );
