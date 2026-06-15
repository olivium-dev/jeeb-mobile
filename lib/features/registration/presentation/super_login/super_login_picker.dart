import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/super_login_demo_user.dart';

/// Opens the "Super user login plus" demo-user picker (debug-only).
///
/// Fetches the predefined roster from `GET /api/User/demo-users` via
/// [SuperLoginDemoUserService] and lists each user (name + role badge). When
/// the user taps a row the sheet pops with the chosen [SuperLoginDemoUser];
/// the caller then opens the existing super-login sheet pre-filled with that
/// user's `userId` + `passcode`. Returns `null` if dismissed.
///
/// Pass [service] from tests; production resolves it from DI.
Future<SuperLoginDemoUser?> showSuperLoginPicker(
  BuildContext context, {
  SuperLoginDemoUserService? service,
}) {
  final resolved = service ?? sl<SuperLoginDemoUserService>();
  return showModalBottomSheet<SuperLoginDemoUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: OmdsBorderRadius.topLarge,
    ),
    builder: (sheetContext) => _SuperLoginPickerBody(service: resolved),
  );
}

/// Owns the async fetch lifecycle (loading → data | error) and renders the
/// matching body. Kept stateful so a Retry re-issues the fetch in place.
class _SuperLoginPickerBody extends StatefulWidget {
  const _SuperLoginPickerBody({required this.service});

  final SuperLoginDemoUserService service;

  @override
  State<_SuperLoginPickerBody> createState() => _SuperLoginPickerBodyState();
}

class _SuperLoginPickerBodyState extends State<_SuperLoginPickerBody> {
  late Future<List<SuperLoginDemoUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.fetchDemoUsers();
  }

  void _retry() => setState(() {
        _future = widget.service.fetchDemoUsers();
      });

  void _select(SuperLoginDemoUser user) =>
      Navigator.of(context).pop(user);

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    // The entire sheet is ONE SingleChildScrollView so an isScrollControlled
    // modal sizes to min(content, viewport) and scrolls — content can never
    // overflow the bottom of the screen (the trap a `Column(min)` falls into).
    return Semantics(
      identifier: 'super_login_plus_picker',
      container: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Spacing.large,
          Spacing.medium,
          Spacing.large,
          Spacing.large + viewInsets,
        ),
        child: _SuperLoginPickerContent(
          future: _future,
          onRetry: _retry,
          onSelect: _select,
        ),
      ),
    );
  }
}

/// Drag handle + header + the async-resolved list/loading/error region, as a
/// shrink-wrapping column inside the sheet's single scroll view.
class _SuperLoginPickerContent extends StatelessWidget {
  const _SuperLoginPickerContent({
    required this.future,
    required this.onRetry,
    required this.onSelect,
  });

  final Future<List<SuperLoginDemoUser>> future;
  final VoidCallback onRetry;
  final ValueChanged<SuperLoginDemoUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PickerDragHandle(),
        const SizedBox(height: Spacing.large),
        const _PickerHeader(),
        const SizedBox(height: Spacing.large),
        _PickerAsyncRegion(
          future: future,
          onRetry: onRetry,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _PickerDragHandle extends StatelessWidget {
  const _PickerDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Sizes.fourXLarge,
        height: Spacing.xSmall,
        decoration: BoxDecoration(
          color:
              colorScheme.onSurface.withValues(alpha: UIConstants.opacityLow),
          borderRadius: OmdsBorderRadius.small,
        ),
      ),
    );
  }
}

class _PickerHeader extends StatelessWidget {
  const _PickerHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.superLoginPickerTitle,
          key: const Key('superLoginPlus.pickerTitle'),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.superLoginPickerSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Resolves [future] to one of: loading spinner, error state (with Retry), or
/// the scrollable user list.
class _PickerAsyncRegion extends StatelessWidget {
  const _PickerAsyncRegion({
    required this.future,
    required this.onRetry,
    required this.onSelect,
  });

  final Future<List<SuperLoginDemoUser>> future;
  final VoidCallback onRetry;
  final ValueChanged<SuperLoginDemoUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SuperLoginDemoUser>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _PickerLoading();
        }
        if (snapshot.hasError) {
          return _PickerError(onRetry: onRetry);
        }
        final users = snapshot.data ?? const <SuperLoginDemoUser>[];
        if (users.isEmpty) return _PickerError(onRetry: onRetry);
        return _PickerList(users: users, onSelect: onSelect);
      },
    );
  }
}

/// Loading state. EXEMPT(flutter-omds-design-system-usage): the raw
/// [CircularProgressIndicator] is acceptable here — the state is purely
/// non-interactive, matching the `_PhoneField` exemption pattern. Tracked
/// under JEEB-57 alongside the OMDS-loader promotion.
class _PickerLoading extends StatelessWidget {
  const _PickerLoading();

  @override
  Widget build(BuildContext context) {
    // Semantics has no const constructor, so this tree cannot be a const
    // literal; only the leaf CircularProgressIndicator is const.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.threeXLarge),
      child: Center(
        child: Semantics(
          identifier: 'super_login_plus_picker_loading',
          child: const CircularProgressIndicator(
            strokeWidth: UIConstants.strokeWidthNormal,
          ),
        ),
      ),
    );
  }
}

class _PickerError extends StatelessWidget {
  const _PickerError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'super_login_plus_picker_error',
      child: OmdsErrorState(
        key: const Key('superLoginPlus.pickerError'),
        message: l10n.superLoginPickerLoadingError,
        onRetry: onRetry,
        retryLabel: l10n.superLoginPickerRetry,
      ),
    );
  }
}

/// Scrollable list of demo-user rows. Fills the [Flexible] slot its parent
/// allots (bounded to the height-capped sheet) and scrolls when the roster is
/// taller than that slot — so the sheet never overflows the viewport.
class _PickerList extends StatelessWidget {
  const _PickerList({required this.users, required this.onSelect});

  final List<SuperLoginDemoUser> users;
  final ValueChanged<SuperLoginDemoUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('superLoginPlus.pickerList'),
      // Shrink-wrapped + non-scrolling: the sheet's outer SingleChildScrollView
      // owns scrolling, so this list just lays its rows out inline.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
      itemBuilder: (context, index) =>
          _DemoUserRow(user: users[index], onTap: onSelect),
    );
  }
}

/// One tappable demo-user row: avatar + name + role badge. Composed from OMDS
/// primitives via [InkWell] + [Row] (not [ListTile]) so the [OmdsChip] trailing
/// badge lays out without the ListTile height assert.
class _DemoUserRow extends StatelessWidget {
  const _DemoUserRow({required this.user, required this.onTap});

  final SuperLoginDemoUser user;
  final ValueChanged<SuperLoginDemoUser> onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'super_login_plus_user_${user.userId}',
      button: true,
      label: user.name,
      child: InkWell(
        key: Key('superLoginPlus.user.${user.userId}'),
        borderRadius: OmdsBorderRadius.medium,
        onTap: () => onTap(user),
        child: Container(
          padding: const EdgeInsets.all(Spacing.medium),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: OmdsBorderRadius.medium,
          ),
          child: _DemoUserRowContent(user: user),
        ),
      ),
    );
  }
}

class _DemoUserRowContent extends StatelessWidget {
  const _DemoUserRowContent({required this.user});

  final SuperLoginDemoUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OmdsProfileAvatar(
          initial: user.name.isEmpty ? '?' : user.name.characters.first,
          size: Sizes.fiveXLarge,
        ),
        const SizedBox(width: Spacing.medium),
        Expanded(child: _DemoUserName(name: user.name)),
        const SizedBox(width: Spacing.small),
        _RoleBadge(isJeeber: user.isJeeber),
      ],
    );
  }
}

class _DemoUserName extends StatelessWidget {
  const _DemoUserName({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w600),
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Colour-coded role badge: client → primaryContainer, jeeber →
/// tertiaryContainer (M3 roles, dark-mode safe).
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isJeeber});

  final bool isJeeber;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return OmdsChip(
      label: isJeeber
          ? l10n.superLoginPickerRoleJeeber
          : l10n.superLoginPickerRoleClient,
      selectedColor: isJeeber
          ? colorScheme.tertiaryContainer
          : colorScheme.primaryContainer,
      selectedTextColor: isJeeber
          ? colorScheme.onTertiaryContainer
          : colorScheme.onPrimaryContainer,
      isSelected: true,
    );
  }
}
