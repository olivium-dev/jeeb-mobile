import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../home_client/application/client_home_cubit.dart';
import '../../home_client/data/in_memory_client_home_repository.dart';
import '../../home_client/domain/client_home_repository.dart';
import '../../home_client/presentation/client_home_screen.dart';

/// Client-role home tab. Hosts the [ClientHomeCubit] scoped to this tab —
/// rebuilt on role switches (the shell tears down + reinflates), which is
/// the right lifetime for a per-tab view-model.
///
/// The repository defaults to the in-memory fake until the jeeb-gateway
/// `/api/clients/me/home-summary` endpoint exists. Callers can inject a
/// real repository through the constructor (used by widget tests).
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    this.repository,
    this.greetingNameProvider,
  });

  /// Injection hook so tests + the future DI wiring can swap in a Dio-
  /// backed repository without modifying the tab.
  final ClientHomeRepository? repository;

  /// Returns the first name to greet the user with, or `null` if unknown.
  /// Wired to the profile cubit once that ships.
  final String? Function()? greetingNameProvider;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      key: const Key('home-tab-cubit'),
      create: (_) => ClientHomeCubit(
        repository: repository ?? InMemoryClientHomeRepository(),
        greetingNameProvider: greetingNameProvider ?? () => null,
      ),
      child: const ClientHomeScreen(key: Key('home-tab-root')),
    );
  }
}
