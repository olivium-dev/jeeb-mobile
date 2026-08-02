import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'jeeber_home_greeting.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/previews/jeeb_preview.dart';
import '../../../../core/session/greeting_profile_cubit.dart';

/// Deliveryman home empty state: greeting → availability switch
class JeeberFeedEmptyView extends StatelessWidget {
  const JeeberFeedEmptyView({
    super.key,
    this.profileName,
    this.profileAvatarUrl,
    this.acceptOrders = true,
    this.onAcceptOrdersChanged,
  });

  static const Key rootKey = Key('jeeber-feed-empty-view-root');

  final String? profileName;
  final String? profileAvatarUrl;
  final bool acceptOrders;
  final ValueChanged<bool>? onAcceptOrdersChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      key: rootKey,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: _EmptyColumn(
              profileName: profileName,
              profileAvatarUrl: profileAvatarUrl,
              acceptOrders: acceptOrders,
              onAcceptOrdersChanged: onAcceptOrdersChanged,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyColumn extends StatelessWidget {
  const _EmptyColumn({
    required this.profileName,
    required this.profileAvatarUrl,
    required this.acceptOrders,
    required this.onAcceptOrdersChanged,
  });

  final String? profileName;
  final String? profileAvatarUrl;
  final bool acceptOrders;
  final ValueChanged<bool>? onAcceptOrdersChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JeeberHomeGreeting(name: profileName, avatarUrl: profileAvatarUrl),
        _AcceptOrdersRow(
          value: acceptOrders,
          onChanged: onAcceptOrdersChanged,
        ),
        const SizedBox(height: Spacing.large),
        const _EmptyHero(),
        const SizedBox(height: Spacing.large),
        const _EmptyText(),
        const SizedBox(height: Spacing.large),
      ],
    );
  }
}

class _AcceptOrdersRow extends StatelessWidget {
  const _AcceptOrdersRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.small,
      ),
      child: Semantics(
        identifier: 'jeeber_home_accept_orders_switch',
        toggled: value,
        child: OmdsSwitchTile(
          key: const Key('jeeber-home-accept-orders-switch'),
          title: AppLocalizations.of(context).jeeberFeedAcceptOrdersLabel,
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
      ),
      child: ExcludeSemantics(
        child: AspectRatio(
          aspectRatio: 1,
          child: Image.asset(
            'assets/illustrations/empty_orders.png',
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _EmptyTitle(text: l10n.jeeberFeedEmptyTitle),
        const SizedBox(height: Spacing.xSmall),
        _EmptySubtitle(text: l10n.jeeberFeedEmptySubtitle),
      ],
    );
  }
}

class _EmptyTitle extends StatelessWidget {
  const _EmptyTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.headlineSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _EmptySubtitle extends StatelessWidget {
  const _EmptySubtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSecondaryContainer,
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
const Size _jeeberFeedEmptyViewPhoneBody = Size(390, 720);

/// The same phone with far less height — a landscape split, a s
const Size _jeeberFeedEmptyViewShortBody = Size(390, 380);

/// The avatar the dev-seam host passes today (`_DevFeedScaffold
const String _jeeberFeedEmptyViewAvatarUrl = 'https://i.pravatar.cc/150?img=12';

/// One state, hosted the way a production shell hosts it. [prof
Widget _jeeberFeedEmptyViewHosted({
  String? name,
  String? avatarUrl,
  bool acceptOrders = true,
  bool wired = true,
  GreetingProfileState? profile,
}) {
  final Widget view = _JeeberFeedEmptyViewAvailabilityHost(
    name: name,
    avatarUrl: avatarUrl,
    acceptOrders: acceptOrders,
    wired: wired,
  );
  if (profile == null) return view;
  return BlocProvider<GreetingProfileCubit>(
    create: (_) => GreetingProfileCubit(seed: profile),
    child: view,
  );
}

/// The intended state: an approved jeeber, online, with nothing
@JeebPreview(
  group: 'jeeber_home',
  name: 'Online · nothing in range',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewAccepting() => _jeeberFeedEmptyViewHosted(
      name: 'Kamal',
      avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
    );

/// Availability OFF: the jeeber has stopped accepting orders. T
@JeebPreview(
  group: 'jeeber_home',
  name: 'Offline · switch off',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewPaused() => _jeeberFeedEmptyViewHosted(
      name: 'Layla',
      avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
      acceptOrders: false,
    );

/// **What the only real host actually renders today.** `_DevFee
@JeebPreview(
  group: 'jeeber_home',
  name: 'Toggle not wired · no avatar',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewDeadToggle() =>
    _jeeberFeedEmptyViewHosted(name: 'Nadia', wired: false);

/// Cold start: no name, no avatar, no ambient profile — `GET /u
@JeebPreview(
  group: 'jeeber_home',
  name: 'Cold start · generic greeting',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewColdStart() => _jeeberFeedEmptyViewHosted();

/// P0-X06 regression guard, made visible. When the Dashboard ta
@JeebPreview(
  group: 'jeeber_home',
  name: 'Ambient profile wins (P0-X06)',
  size: _jeeberFeedEmptyViewPhoneBody,
)
Widget jeeberFeedEmptyViewAmbientProfile() => _jeeberFeedEmptyViewHosted(
      name: 'Kamal',
      profile: const GreetingProfileState(
        name: 'Rami Haddad',
        avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
      ),
    );

/// The layout ceiling: the longest plausible name in the shorte
@JeebPreview(
  group: 'jeeber_home',
  name: 'Long name · short viewport',
  size: _jeeberFeedEmptyViewShortBody,
)
Widget jeeberFeedEmptyViewLongName() => _jeeberFeedEmptyViewHosted(
      name: 'Abdulrahman Al-Muhandis Al-Trabulsi',
      avatarUrl: _jeeberFeedEmptyViewAvatarUrl,
    );

/// Holds the availability value so the switch moves when it is 
class _JeeberFeedEmptyViewAvailabilityHost extends StatefulWidget {
  const _JeeberFeedEmptyViewAvailabilityHost({
    required this.name,
    required this.avatarUrl,
    required this.acceptOrders,
    required this.wired,
  });

  final String? name;
  final String? avatarUrl;
  final bool acceptOrders;

/// Whether `onAcceptOrdersChanged` is supplied at all.
  final bool wired;

  @override
  State<_JeeberFeedEmptyViewAvailabilityHost> createState() =>
      _JeeberFeedEmptyViewAvailabilityHostState();
}

class _JeeberFeedEmptyViewAvailabilityHostState
    extends State<_JeeberFeedEmptyViewAvailabilityHost> {
  late bool _acceptOrders = widget.acceptOrders;

  @override
  Widget build(BuildContext context) {
    return JeeberFeedEmptyView(
      profileName: widget.name,
      profileAvatarUrl: widget.avatarUrl,
      acceptOrders: _acceptOrders,
      onAcceptOrdersChanged: widget.wired
          ? (bool value) => setState(() => _acceptOrders = value)
          : null,
    );
  }
}
