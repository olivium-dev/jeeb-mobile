// Tests for OfflineCubit (global-offline-banner / SC-129).
//
// Verifies the cubit is now driven by a ConnectivitySource: it seeds from the
// current value and follows transitions, the banner shows only when offline and
// not dismissed, dismiss hides it, and a fresh offline episode re-shows it.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';
import 'package:jeeb_mobile/features/offline_mode/domain/connectivity_source.dart';

class _FakeConnectivity implements ConnectivitySource {
  _FakeConnectivity({this.initial = true});

  final bool initial;
  final _controller = StreamController<bool>.broadcast();

  void emit(bool online) => _controller.add(online);

  @override
  Future<bool> isOnline() async => initial;

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;
}

void main() {
  test('no source: defaults online, banner hidden', () {
    final cubit = OfflineCubit();
    expect(cubit.state.status, ConnectivityStatus.online);
    expect(cubit.state.showBanner, isFalse);
    cubit.close();
  });

  test('seeds offline from source then follows transitions', () async {
    final source = _FakeConnectivity(initial: false);
    final cubit = OfflineCubit(connectivity: source);

    // Seed is async — let the microtask resolve.
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, ConnectivityStatus.offline);
    expect(cubit.state.showBanner, isTrue);

    source.emit(true);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, ConnectivityStatus.online);
    expect(cubit.state.showBanner, isFalse);

    await cubit.close();
  });

  test('dismiss hides banner; a new offline episode re-shows it', () async {
    final cubit = OfflineCubit();

    cubit.setOffline();
    expect(cubit.state.showBanner, isTrue);

    cubit.dismissBanner();
    expect(cubit.state.status, ConnectivityStatus.offline);
    expect(cubit.state.showBanner, isFalse);

    // Reconnect then drop again → banner returns (dismiss was for that episode).
    cubit.setOnline();
    cubit.setOffline();
    expect(cubit.state.showBanner, isTrue);

    await cubit.close();
  });
}
