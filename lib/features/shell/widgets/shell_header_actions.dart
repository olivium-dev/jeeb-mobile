import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../core/theme/jeeb_semantic_colors.dart';
import '../../../l10n/app_localizations.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import 'package:omds/omds.dart';
import '../../../core/previews/jeeb_preview.dart';
import '../../customer_profile/presentation/widgets/customer_profile_header.dart';
import '../../home_client/presentation/widgets/client_home_greeting.dart';
import '../../jeeber_home/presentation/widgets/jeeber_home_greeting.dart';

/// Persistent header actions — the **wallet chip** + **notification bell** — that
/// the shell paints as opaque Ø[buttonSize] glass circles on customer headers.
class ShellHeaderActions extends StatelessWidget {
  const ShellHeaderActions({super.key, required this.idPrefix});

  /// Circle diameter, and the tap target (≥44).
  static const double buttonSize = 44;

  /// Tab whose header carries the settings gear (the `/settings` hub's only
  /// in-app entry point).
  static const String settingsHostIdPrefix = 'customer_profile';

  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (idPrefix == settingsHostIdPrefix) ...[
          _circle(
            context,
            identifier: '${idPrefix}_settings',
            label: l10n.shellSettingsLabel,
            icon: Icons.settings_outlined,
            onTap: () => context.pushNamed('settings'),
          ),
          const SizedBox(width: Spacing.xSmall),
        ],
        _circle(
          context,
          identifier: '${idPrefix}_wallet_chip',
          label: l10n.shellWalletChipLabel,
          // R1: both header glyphs are WHITE. `primary` IS #D73B00 under
          // Midnight, so this wallet chip was the header's only orange.
          icon: Icons.account_balance_wallet_outlined,
          onTap: () {
            final isJeeber =
                context.read<RoleCubit?>()?.state == UserRole.jeeber;
            context.goNamed(isJeeber ? 'wallet' : 'customer-wallet');
          },
        ),
        const SizedBox(width: Spacing.xSmall),
        _circle(
          context,
          identifier: '${idPrefix}_bell',
          label: l10n.shellBellLabel,
          icon: Icons.notifications_none_outlined,
          // notifications-list (JM-057) IS registered (`/notifications`,
          onTap: () => context.goNamed('notifications'),
        ),
      ],
    );
  }

  Widget _circle(
    BuildContext context, {
    required String identifier,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass =
        Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Semantics(
      identifier: identifier,
      button: true,
      container: true,
      label: label,
      child: Tooltip(
        message: label,
        child: SizedBox.square(
          dimension: buttonSize,
          child: Material(
            color: Color.alphaBlend(
              glass.glassFillEmphasis,
              colorScheme.surface,
            ),
            shape: CircleBorder(
              side: BorderSide(color: glass.glassBorderStrong, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(icon, size: 22, color: colorScheme.onSurface),
              ),
            ),
          ),
        ),
      ),
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
  double topOffset = 0,
}) {
  return _ShellHeaderActionsSpecimen(
    caption: caption,
    child: body == null
        ? _ShellHeaderActionsBareRow(idPrefix: idPrefix)
        : _ShellHeaderActionsHeaderedTab(
            idPrefix: idPrefix,
            body: body,
            topOffset: topOffset,
          ),
  );
}

/// The shell's own Requests-tab offset: the two circles centered on the
/// greeting avatar's line.
const double _shellHeaderActionsRequestsTopOffset =
    ClientHomeGreeting.avatarCenterFromSafeTop - ShellHeaderActions.buttonSize / 2;

/// The component on its own: two Ø44 glass circles in a `mainAxisSize.min`
/// [Row], outlined here so the footprint is visible.
@JeebPreview(
  group: 'shell',
  name: 'Actions only',
  size: _shellHeaderActionsRowBox,
)
Widget shellHeaderActionsBareRow() => _shellHeaderActionsHosted(
      caption: 'Actions only · 2 × Ø44',
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
      topOffset: _shellHeaderActionsRequestsTopOffset,
      body: ListView(
        children: <Widget>[
          const ClientHomeGreeting(name: 'Sami'),
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
      topOffset: _shellHeaderActionsRequestsTopOffset,
      body: ListView(
        children: <Widget>[
          const ClientHomeGreeting(
            name: _shellHeaderActionsLongFirstName,
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
    this.topOffset = 0,
  });

  final String idPrefix;
  final Widget body;
  final double topOffset;

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
            top: topOffset,
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

/// The actions with nothing behind them, outlined so the 2 × Ø44 footprint is
/// measurable by eye.
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
