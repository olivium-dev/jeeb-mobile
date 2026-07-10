import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';
import '../application/offline_cubit.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.cubit});

  /// Optional cubit override. Defaults to `null`, which preserves the exact
  /// original behaviour: the banner consumes the ambient [OfflineCubit]
  /// already provided higher in the tree. Passing an explicit [cubit] wraps
  /// the builder in a local `BlocProvider.value` instead, so a host with no
  /// ambient DI tree (e.g. the devtool catalog) can preview each connectivity
  /// state for NO NETWORK. Additive-only: production call sites that never
  /// pass [cubit] are completely unaffected.
  final OfflineCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final builder = BlocBuilder<OfflineCubit, OfflineState>(
      builder: (context, state) {
        if (state.status == ConnectivityStatus.online) {
          return const SizedBox.shrink();
        }
        return const _OfflineMaterialBanner();
      },
    );
    final provided = cubit;
    if (provided != null) {
      return BlocProvider<OfflineCubit>.value(value: provided, child: builder);
    }
    return builder;
  }
}

class _OfflineMaterialBanner extends StatelessWidget {
  const _OfflineMaterialBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MaterialBanner(
      content: Text(
        'You are offline. Changes will sync when connection is restored.',
        style: TextStyle(color: theme.colorScheme.onErrorContainer),
      ),
      leading: Icon(
        Icons.cloud_off,
        color: theme.colorScheme.onErrorContainer,
      ),
      backgroundColor: theme.colorScheme.errorContainer,
      actions: [
        OmdsPrimaryButton(
          text: 'DISMISS',
          variant: OmdsButtonVariant.text,
          textColor: theme.colorScheme.onErrorContainer,
          onTap: () {},
        ),
      ],
    );
  }
}
