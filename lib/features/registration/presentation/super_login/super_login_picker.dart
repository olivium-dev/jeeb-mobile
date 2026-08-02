import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/layout/bottom_inset.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/super_login_demo_user.dart';

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
    // Keyboard + system nav-bar inset for bottom row visibility under edge-to-edge.
    final bottomInset = context.sheetBottomInset;
    // Sheet's outer SingleChildScrollView owns scrolling; this list lays out inline.
    return Semantics(
      identifier: 'super_login_plus_picker',
      container: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          Spacing.large,
          Spacing.medium,
          Spacing.large,
          Spacing.large + bottomInset,
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
        return _PickerFilterableList(users: users, onSelect: onSelect);
      },
    );
  }
}

class _PickerFilterableList extends StatefulWidget {
  const _PickerFilterableList({required this.users, required this.onSelect});

  final List<SuperLoginDemoUser> users;
  final ValueChanged<SuperLoginDemoUser> onSelect;

  static const int _searchThreshold = 8;

  @override
  State<_PickerFilterableList> createState() => _PickerFilterableListState();
}

class _PickerFilterableListState extends State<_PickerFilterableList> {
  String _query = '';

  void _onQueryChanged(String value) => setState(() => _query = value);

  List<SuperLoginDemoUser> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.users;
    return widget.users
        .where((u) =>
            u.name.toLowerCase().contains(q) ||
            u.role.toLowerCase().contains(q) ||
            u.userId.toLowerCase().contains(q) ||
            u.availableRoles.any((r) => r.toLowerCase().contains(q)))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showSearch =
        widget.users.length > _PickerFilterableList._searchThreshold;
    final filtered = _filtered;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSearch) ...[
          Semantics(
            identifier: 'super_login_plus_picker_search',
            child: OmdsSearchBar(
              key: const Key('superLoginPlus.pickerSearch'),
              hintText: l10n.superLoginPickerSearchHint,
              onChanged: _onQueryChanged,
            ),
          ),
          const SizedBox(height: Spacing.medium),
        ],
        if (filtered.isEmpty)
          _PickerNoMatches(message: l10n.superLoginPickerNoMatches)
        else
          _PickerList(users: filtered, onSelect: widget.onSelect),
      ],
    );
  }
}

class _PickerNoMatches extends StatelessWidget {
  const _PickerNoMatches({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xLarge),
      child: Semantics(
        identifier: 'super_login_plus_picker_no_matches',
        child: Text(
          message,
          key: const Key('superLoginPlus.pickerNoMatches'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// EXEMPT(flutter-omds-design-system-usage): raw CircularProgressIndicator acceptable (non-interactive state only; tracked under JEEB-57).
class _PickerLoading extends StatelessWidget {
  const _PickerLoading();

  @override
  Widget build(BuildContext context) {
    // Semantics has no const constructor; only the leaf CircularProgressIndicator is const.
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

class _PickerList extends StatelessWidget {
  const _PickerList({required this.users, required this.onSelect});

  final List<SuperLoginDemoUser> users;
  final ValueChanged<SuperLoginDemoUser> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('superLoginPlus.pickerList'),
      // Shrink-wrapped + non-scrolling: sheet's outer SingleChildScrollView owns scrolling.
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: users.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
      itemBuilder: (context, index) =>
          _DemoUserRow(user: users[index], onTap: onSelect),
    );
  }
}

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

/// Client → primaryContainer, jeeber → tertiaryContainer (M3 roles, dark-mode safe).
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
