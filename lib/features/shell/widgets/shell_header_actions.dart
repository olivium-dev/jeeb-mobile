import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:omds/omds.dart';
import '../../../core/previews/jeeb_preview.dart';
import '../../customer_profile/presentation/widgets/customer_profile_header.dart';
import '../../home_client/presentation/widgets/client_home_greeting.dart';
import '../../jeeber_home/presentation/widgets/jeeber_home_greeting.dart';

/// Persistent header actions — the **wallet chip** + **notification bell** — that
/// the shell paints on the customer **Requests** and **Profile** headers
class ShellHeaderActions extends StatelessWidget {
  const ShellHeaderActions({super.key, required this.idPrefix});

  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: '${idPrefix}_wallet_chip',
          button: true,
          container: true,
          label: l10n.shellWalletChipLabel,
          child: IconButton(
            tooltip: l10n.shellWalletChipLabel,
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: colorScheme.primary,
            ),
            onPressed: () {
              final isJeeber =
                  context.read<RoleCubit?>()?.state == UserRole.jeeber;
              context.goNamed(isJeeber ? 'wallet' : 'customer-wallet');
            },
          ),
        ),
        Semantics(
          identifier: '${idPrefix}_bell',
          button: true,
          container: true,
          label: l10n.shellBellLabel,
          child: IconButton(
            tooltip: l10n.shellBellLabel,
            icon: Icon(
              Icons.notifications_none_outlined,
              color: colorScheme.onSurface,
            ),
            // notifications-list (JM-057) IS registered (`/notifications`,
            onPressed: () => context.goNamed('notifications'),
          ),
        ),
      ],
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED.

/// A phone-width slice of a tab: a real trailing edge to pin against, and room
/// for the header the overlay lands on.
const Size _shellHeaderActionsTabBox = Size(390, 260);

/// The narrow phones still in the fleet (iPhone SE, Galaxy A0x): same height,
/// 70 fewer logical pixels for the greeting line to fit beside the overlay.
const Size _shellHeaderActionsNarrowTabBox = Size(320, 260);

/// The bare row needs no tab underneath it, only room for its caption at 200%.
const Size _shellHeaderActionsRowBox = Size(390, 140);

/// The rated, verified customer from `test/customer_profile_screen_test.dart`.
const String _shellHeaderActionsProfileName = 'Sami Fawaz';
const String _shellHeaderActionsProfileEmail = 'kamalhaaj@gmail.com';

/// Longest plausible single-token first name. The greeting widgets show the
/// FIRST name only, so a long *first* name — not a long full name — is what
const String _shellHeaderActionsLongFirstName = 'Abdulrahmanalmuhandis';

/// One specimen: the widget in its host composition, with a caption naming the
/// state.
Widget _shellHeaderActionsHosted({
  required String caption,
  required String idPrefix,
  Widget? body,
}) {
  return _ShellHeaderActionsSpecimen(
    caption: caption,
    child: body == null
        ? _ShellHeaderActionsBareRow(idPrefix: idPrefix)
        : _ShellHeaderActionsHeaderedTab(idPrefix: idPrefix, body: body),
  );
}

/// The component on its own: two [IconButton]s in a `mainAxisSize.min` [Row],
/// 96 × 48 dp, outlined here so the footprint is visible.
@JeebPreview(
  group: 'shell',
  name: 'Actions only',
  size: _shellHeaderActionsRowBox,
)
Widget shellHeaderActionsBareRow() => _shellHeaderActionsHosted(
      caption: 'Actions only · 96 × 48 dp',
      idPrefix: 'orders_home',
    );

/// **The state that breaks**: the Requests tab (`orders_home`, JM-023).
/// [ClientHomeGreeting] is the first child of the HomeTab's `ListView` with
@JeebPreview(
  group: 'shell',
  name: 'Requests tab',
  size: _shellHeaderActionsTabBox,
)
Widget shellHeaderActionsRequestsTab() => _shellHeaderActionsHosted(
      caption: 'Requests tab · orders_home',
      idPrefix: 'orders_home',
      body: ListView(
        children: <Widget>[
          ClientHomeGreeting(name: 'Sami', onAddPressed: () {}),
        ],
      ),
    );

/// The same collision at the width where it hurts, with the longest plausible
/// first name.
@JeebPreview(
  group: 'shell',
  name: 'Requests tab · narrow + long name',
  size: _shellHeaderActionsNarrowTabBox,
)
Widget shellHeaderActionsRequestsNarrowLongName() => _shellHeaderActionsHosted(
      caption: 'Requests tab · long name at 320 dp',
      idPrefix: 'orders_home',
      body: ListView(
        children: <Widget>[
          ClientHomeGreeting(
            name: _shellHeaderActionsLongFirstName,
            onAddPressed: () {},
          ),
        ],
      ),
    );

/// The jeeber dashboard (`delivery_tab`), which the shell only mounts for a
/// user with the jeeber role.
@JeebPreview(
  group: 'shell',
  name: 'Jeeber dashboard',
  size: _shellHeaderActionsTabBox,
)
Widget shellHeaderActionsJeeberDashboard() => _shellHeaderActionsHosted(
      caption: 'Jeeber dashboard · delivery_tab',
      idPrefix: 'delivery_tab',
      body: ListView(
        children: const <Widget>[
          JeeberHomeGreeting(name: _shellHeaderActionsLongFirstName),
        ],
      ),
    );

/// The host that gets it right: the Profile tab (`customer_profile`, JM-035).
/// [CustomerProfileHeader] opens with `Sizes.fiveXLarge` (56 dp) of top inset
@JeebPreview(
  group: 'shell',
  name: 'Profile tab',
  size: _shellHeaderActionsTabBox,
)
Widget shellHeaderActionsProfileTab() => _shellHeaderActionsHosted(
      caption: 'Profile tab · customer_profile',
      idPrefix: 'customer_profile',
      body: ListView(
        children: const <Widget>[
          CustomerProfileHeader(
            name: _shellHeaderActionsProfileName,
            email: _shellHeaderActionsProfileEmail,
            avatarUrl: null,
            isVerified: true,
            rating: 4.8,
            ratingCount: 42,
          ),
        ],
      ),
    );

// ---------------------------------------------------------------------------

/// The shell's overlay, reproduced.
/// A copy of `_HeaderedTab` in `lib/features/shell/shell_screen.dart`, which is
/// private and cannot be imported: same `Stack`, same
class _ShellHeaderActionsHeaderedTab extends StatelessWidget {
  const _ShellHeaderActionsHeaderedTab({
    required this.idPrefix,
    required this.body,
  });

  final String idPrefix;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: body),
          PositionedDirectional(
            top: 0,
            end: Spacing.xSmall,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: ShellHeaderActions(idPrefix: idPrefix),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The actions with nothing behind them, outlined so the 96 × 48 dp footprint
/// is measurable by eye.
class _ShellHeaderActionsBareRow extends StatelessWidget {
  const _ShellHeaderActionsBareRow({required this.idPrefix});

  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: colors.outline)),
        child: Material(
          color: Colors.transparent,
          child: ShellHeaderActions(idPrefix: idPrefix),
        ),
      ),
    );
  }
}

/// The specimen frame: the composition under review, with a caption naming the
/// state beneath it.
/// The caption sits below so it reads as a label on the frame rather than as
class _ShellHeaderActionsSpecimen extends StatelessWidget {
  const _ShellHeaderActionsSpecimen({
    required this.caption,
    required this.child,
  });

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.xSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: child),
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
