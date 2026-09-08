// EP-24 — the socket's `e.toString()` used to sit in view state, one render
// away from being shown to a user.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/chat/application/chat_connection_cubit.dart';
import 'package:jeeb_mobile/features/chat/application/chat_connection_state.dart';
import 'package:jeeb_mobile/features/chat/data/in_memory_chat_outbox.dart';
import 'package:jeeb_mobile/features/chat/domain/chat_socket.dart';
import 'package:jeeb_mobile/features/chat/domain/connection_status.dart';

class _FakeSocket implements ChatSocket {
  _FakeSocket({this.connectThrows = false});

  final bool connectThrows;
  final _events = StreamController<Map<String, Object?>>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  bool closed = false;

  @override
  Future<void> connect() async {
    if (connectThrows) throw StateError('WebSocketChannelException');
  }

  @override
  Stream<Map<String, Object?>> get events => _events.stream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  void send(Map<String, Object?> message) {}

  @override
  Future<void> close() async {
    closed = true;
    await _events.close();
    await _errors.close();
  }

  void raise(Object error) => _errors.add(error);

  void emit(Map<String, Object?> frame) => _events.add(frame);
}

void main() {
  test('a socket error is a CLASSIFIED failure, not prose', () async {
    final socket = _FakeSocket();
    final cubit = ChatConnectionCubit(
      socketFactory: () => socket,
      outbox: InMemoryChatOutbox(),
      currentUserId: 'me',
    );
    addTearDown(cubit.close);

    await cubit.start();
    socket.raise(StateError('SocketException: Network is unreachable'));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.lastFailure, ChatConnectionFailure.socketError);
  });

  test('a connect throw records connectFailed', () async {
    final socket = _FakeSocket(connectThrows: true);
    final cubit = ChatConnectionCubit(
      socketFactory: () => socket,
      outbox: InMemoryChatOutbox(),
      currentUserId: 'me',
      timerFactory: (Duration d, void Function() run) => Timer(d, run),
    );
    addTearDown(cubit.close);

    await cubit.start();

    expect(cubit.state.lastFailure, ChatConnectionFailure.connectFailed);
    expect(cubit.state.status, isNot(ConnectionStatus.connected));
  });

  test('a server rejection keeps the code out of view state', () async {
    final socket = _FakeSocket();
    final cubit = ChatConnectionCubit(
      socketFactory: () => socket,
      outbox: InMemoryChatOutbox(),
      currentUserId: 'me',
    );
    addTearDown(cubit.close);

    await cubit.start();
    socket.emit(<String, Object?>{
      'type': 'error',
      'code': 'rate_limited',
      'message': 'Slow down, you have sent too many messages',
    });
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.lastFailure, ChatConnectionFailure.serverRejected);
  });

  test('no state field anywhere carries exception prose', () async {
    final socket = _FakeSocket();
    final cubit = ChatConnectionCubit(
      socketFactory: () => socket,
      outbox: InMemoryChatOutbox(),
      currentUserId: 'me',
    );
    addTearDown(cubit.close);

    await cubit.start();
    socket.raise(StateError('SocketException: Network is unreachable'));
    await Future<void>.delayed(Duration.zero);

    for (final Object? prop in cubit.state.props) {
      expect('$prop', isNot(contains('Exception')));
      expect('$prop', isNot(contains('SocketException')));
    }
  });
}
