import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/layout/bottom_inset.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/app_failure_copy.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_failure_block.dart';
import '../../../core/widgets/jeeb/jeeb_refresh_failed_note.dart';
import '../../../core/widgets/jeeb/jeeb_snack.dart';
import '../../../core/widgets/jeeb/jeeb_state_host.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../../settings/presentation/widgets/notification_toggle_track.dart';
import '../application/notification_prefs_cubit.dart';
import '../application/notification_prefs_state.dart';
import '../domain/notification_prefs_model.dart';

/// Trailing padlock on the locked transactional row — R22 draws the same glyph
/// at 17px on its always-on line (board `tpl 1397`).
const double _kLockGlyphSize = 17;

/// Notification Preferences (JM-058, blueprint `notification-prefs`).
///
/// Categories (D64): offers / order-status / wallet / marketing — each a
/// debounced PUT toggle. The transactional class is locked (always-on, shown as
/// a non-interactive padlock row). A push-only note (R2) clarifies these are
/// push-channel preferences. Back → `customer-profile`.
///
/// MIDNIGHT M3-24: derived from R22 Settings (M2-19), which is this screen's
/// parent band — `/settings` → MORE → Notifications lands here, and R22 draws
/// the same NOTIFICATIONS card in miniature. Carried across verbatim: the
/// `content` field with its single orange glow at `topEnd` (R22 declares no
/// periwinkle), the grouped glass card, the 11/14→13/16 row rungs, and the
/// board's own [NotificationToggleTrack] — 46×26 orange track, Ø20 white knob,
/// `0 0 12px` bloom. That track is painted rather than themed for the reason
/// R22 found: `OmdsSettingsSwitchRow` forwards only `activeColor` (the *thumb*),
/// so the ON track resolved off `SwitchThemeData.trackColor` and rendered
/// PERIWINKLE here too, exactly as it did on R22 before M2-19.
///
/// Exposed Semantics identifiers (JM-058 AC):
///   notif_prefs_root            — screen host (nav-honesty re-assert)
///   notif_prefs_offers_toggle
///   notif_prefs_order_status_toggle
///   notif_prefs_wallet_toggle
///   notif_prefs_marketing_toggle
///   notif_prefs_transactional_lock_icon — the locked always-on row indicator
///   notif_prefs_push_only_note  — the push-only channel note (R2)
///   notif_prefs_back            — app-bar back control → customer-profile
///   notif_prefs_retry_cta       — retry on the failed cold read
class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  /// Cold-read and failed-read illustration hosts.
  static const String loadingIdentifier = 'notif_prefs_loading';
  static const String loadErrorIdentifier = 'notif_prefs_load_error';

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

  /// Back → customer-profile. Real entry is `goNamed('settings-notifications')`
  /// from the Profile tab (poppable → returns there); the named fallback only
  /// fires on a cold deep-link (mirrors `wallet_charge_info_screen` pattern).
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
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      glowPlacement: JeebFieldGlowPlacement.topEnd,
      animateDecor: false,
      child: Semantics(
        identifier: 'notif_prefs_root',
        container: true,
        explicitChildNodes: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          // The redesign's header is a body row, not a Material app bar (§5 #1):
          // no elevation, no surface tint, Ø40 back circle + 20/w700 title.
          body: SafeArea(
            // The list reserves the nav-bar inset itself so the last row scrolls
            // clear of the soft buttons in edge-to-edge mode.
            bottom: false,
            child: Column(
              children: [
                JeebTopBar.back(
                  title: l10n.notificationPreferencesTitle,
                  // FROZEN: the leading circle carries `notif_prefs_back`.
                  identifier: 'notif_prefs_back',
                  leadingTooltip: l10n.kycWizardBack,
                  onLeadingPressed: _onBack,
                ),
                Expanded(
                  child: BlocConsumer<NotificationPrefsCubit,
                      NotificationPrefsState>(
                    listenWhen: _shouldListen,
                    listener: _onSaveError,
                    builder: _buildBody,
                  ),
                ),
              ],
            ),
          ),
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
    final cubit = context.read<NotificationPrefsCubit>();
    final AppFailure? failure =
        state is NotificationPrefsLoaded ? state.saveFailure : null;
    showJeebErrorSnack(
      context,
      message: failure == null
          ? l10n.notificationPrefsSaveError
          : failureCopy(l10n, failure).body,
      identifier: 'notif_prefs_save_error_snack',
      retryLabel: l10n.actionRetry,
      onRetry: cubit.retryLastSave,
    );
    cubit.acknowledgeError();
  }

  Widget _buildBody(BuildContext context, NotificationPrefsState state) {
    switch (state) {
      case NotificationPrefsLoading():
        return const _LoadingView();
      // Error before empty (R6).
      case NotificationPrefsError(:final failure, :final appFailure):
        return _ErrorView(
          view: failure,
          failure: appFailure ?? const UnknownFailure(),
          onRetry: context.read<NotificationPrefsCubit>().load,
        );
      case NotificationPrefsLoaded(
          :final prefs,
          :final saveFailure,
          :final refreshFailure,
          :final isRefreshing,
        ):
        final Widget body = _PrefsBody(prefs: prefs);
        final AppFailure? noteFailure = refreshFailure ?? saveFailure;
        if (isRefreshing || noteFailure == null) return body;
        final NotificationPrefsCubit cubit =
            context.read<NotificationPrefsCubit>();
        final bool isRefreshNote = refreshFailure != null;
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.medium,
                Spacing.small,
                Spacing.medium,
                0,
              ),
              child: JeebRefreshFailedNote(
                failure: noteFailure,
                identifier: 'notif_prefs_save_failed_note',
                onRetry: isRefreshNote ? cubit.load : cubit.retryLastSave,
                onDismiss: isRefreshNote
                    ? cubit.dismissRefreshFailure
                    : cubit.acknowledgeError,
              ),
            ),
            Expanded(child: body),
          ],
        );
    }
  }
}

/// The cold read. `radar` for the reason M3-07 and `account_status` picked it:
/// its subject is a channel listening for a signal, which is what a push
/// preference is. The identity discs are dropped — there is no second party
/// here to name.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebStateHost(
      child: JeebEmptyState(
        variant: JeebEmptyStateVariant.radar,
        reason: JeebEmptyStateReason.loading,
        medallions: const <JeebEmptyMedallion>[],
        identifier: NotificationPrefsScreen.loadingIdentifier,
        headline: l10n.notificationPrefsLoadingHeadline,
      ),
    );
  }
}

/// The failed cold read: same illustration, danger-tinted centre (kit ruling 1),
/// and the retry stays the glass pill — never an orange act R22 does not draw.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.view,
    required this.failure,
    required this.onRetry,
  });

  /// F24: the kind-specific view. The screen used to print one sentence for
  /// every failure.
  final NotificationPrefsFailureView view;

  final AppFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // R6: on a terminal kind the block hides Retry, so it must still offer an
    // exit rather than leaving the screen with no act at all.
    final bool retryable = failureCopy(l10n, failure).retryable;
    return JeebStateHost(
      child: JeebFailureBlock(
        failure: failure,
        variant: JeebEmptyStateVariant.radar,
        identifier: NotificationPrefsScreen.loadErrorIdentifier,
        retryIdentifier: 'notif_prefs_retry_cta',
        headlineOverride:
            retryable ? l10n.notificationPrefsErrorTitle : null,
        bodyOverride: view == NotificationPrefsFailureView.network
            ? l10n.notificationPrefsErrorNetwork
            : null,
        onRetry: onRetry,
        exitLabel: retryable ? null : l10n.actionBack,
        onExit: retryable ? null : () => Navigator.of(context).maybePop(),
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
      // The board's 24px gutter, and the nav-bar inset so the last row clears
      // the soft buttons (see [BottomInsetX.scrollBodyBottomInset]).
      padding: EdgeInsetsDirectional.fromSTEB(
        Spacing.xLarge,
        Spacing.medium,
        Spacing.xLarge,
        context.scrollBodyBottomInset,
      ),
      children: [
        const _PushOnlyNote(),
        // R22 opens each labelled band with 20 (`tpl 1370`/`1377`).
        const SizedBox(height: Spacing.large),
        _CategoriesSection(prefs: prefs, cubit: cubit),
        if (prefs.transactionalLocked) ...[
          const SizedBox(height: Spacing.large),
          const _TransactionalLockedSection(),
        ],
      ],
    );
  }
}

/// Push-only note (R2): every category here is a *push* preference.
class _PushOnlyNote extends StatelessWidget {
  const _PushOnlyNote();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return JeebInfoNote.muted(
      icon: Icons.info,
      // l10n reuse (CTO-D R-F): generic "manage what you get notified about"
      // stands in for the push-only note until the dedicated key lands
      // (50_ROUTE_REQUESTS JM-058).
      text: l10n.notificationPreferencesRowSubtitle,
      identifier: 'notif_prefs_push_only_note',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.notificationPreferencesCategoriesSection),
        const SizedBox(height: Spacing.xSmall),
        JeebOutlinedCard.grouped(
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
              // Dedicated wallet-notification copy (F9): title + a wallet-specific
              // subtitle, not the page-header "manage what you get notified about".
              title: l10n.notificationCategoryWallet,
              subtitle: l10n.notificationCategoryWalletSubtitle,
              value: c.wallet,
              onChanged: (v) =>
                  cubit.toggleCategory(NotificationCategory.wallet, v),
            ),
            _CategoryRow(
              identifier: 'notif_prefs_marketing_toggle',
              // Surfaced as the rating-reminders category (D64 mapping): use the
              // dedicated rating-reminders subtitle, not the duplicated offers copy
              // ("Discounts and seasonal promotions") — F9.
              title: l10n.notificationCategoryRatingReminders,
              subtitle: l10n.notificationCategoryRatingRemindersSubtitle,
              value: c.marketing,
              onChanged: (v) =>
                  cubit.toggleCategory(NotificationCategory.marketing, v),
            ),
          ],
        ),
      ],
    );
  }
}

/// The locked transactional class (D64) — always on, cannot be disabled.
class _TransactionalLockedSection extends StatelessWidget {
  const _TransactionalLockedSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeebSectionLabel(l10n.notificationPreferencesSecuritySection),
        const SizedBox(height: Spacing.xSmall),
        const JeebOutlinedCard.grouped(
          children: [_TransactionalLockedRow()],
        ),
      ],
    );
  }
}

/// The always-on transactional line. It is a *fact*, not a control, so — like
/// R22's security-codes row — it renders as a plain row with a trailing padlock
/// rather than a switch nobody can move. Non-interactive by construction: no
/// `onTap`, no toggle to actuate.
class _TransactionalLockedRow extends StatelessWidget {
  const _TransactionalLockedRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = (Theme.of(context).extension<JeebSemanticColors>() ?? JeebSemanticColors.midnight()).mutedText;

    return Semantics(
      // JM-058 AC2: the locked-transactional indicator. The flow asserts
      // `notif_prefs_transactional_lock_icon` (67_W34_TEST_PLAN coined id).
      identifier: 'notif_prefs_transactional_lock_icon',
      container: true,
      child: JeebListRow(
        // l10n reuse (CTO-D R-F): the OTP/security-codes row copy stands in for
        // the transactional-locked label until the dedicated key lands.
        title: l10n.notificationCategoryOtp,
        subtitle: l10n.notificationCategoryOtpAlwaysOn,
        titleStyle: context.jeebText.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: JeebOutlinedCard.defaultPadding,
        trailing: Icon(Icons.lock, size: _kLockGlyphSize, color: muted),
      ),
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
      child: JeebListRow(
        title: title,
        subtitle: subtitle,
        titleStyle: context.jeebText.body.copyWith(
          fontWeight: FontWeight.w600,
        ),
        padding: JeebOutlinedCard.defaultPadding,
        trailing: NotificationToggleTrack(value: value),
        onTap: () => onChanged(!value),
      ),
    );
  }
}
