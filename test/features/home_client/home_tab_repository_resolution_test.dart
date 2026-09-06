// Critic A2 (P0): a DI miss must NOT render fabricated empty rows as real
// data. The in-memory fixture is reachable only through the debug dev seam.

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jeeb_mobile/features/home_client/data/dio_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/data/in_memory_client_home_repository.dart';
import 'package:jeeb_mobile/features/home_client/domain/client_home_repository.dart';
import 'package:jeeb_mobile/features/shell/tabs/home_tab.dart';

void main() {
  setUp(GetIt.instance.reset);
  tearDown(GetIt.instance.reset);

  test('GetIt empty and no dev seed → a real gateway repository', () {
    final ClientHomeRepository repo = resolveClientHomeRepository(false);
    expect(repo, isA<DioClientHomeRepository>());
    expect(repo, isNot(isA<InMemoryClientHomeRepository>()));
  });

  test('the dev seed is the ONLY path to the in-memory fixture', () {
    expect(
      resolveClientHomeRepository(true),
      isA<InMemoryClientHomeRepository>(),
    );
  });

  test('a registered repository always wins', () {
    final _Stub stub = _Stub();
    GetIt.instance.registerSingleton<ClientHomeRepository>(stub);
    expect(resolveClientHomeRepository(false), same(stub));
  });
}

class _Stub implements ClientHomeRepository {
  @override
  Future<ClientHomeSnapshot> loadSnapshot() async =>
      const ClientHomeSnapshot();
}
