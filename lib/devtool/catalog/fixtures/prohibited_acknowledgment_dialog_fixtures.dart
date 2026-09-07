// Designed states for `ProhibitedAcknowledgmentDialog` — the prohibited-items
// gate the create funnel opens on a 409 `prohibited-item-requires-ack`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_acknowledgment_repository.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/domain/prohibited_item.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart';
import 'package:jeeb_mobile/features/prohibited_acknowledgment/presentation/cubit/prohibited_acknowledgment_cubit.dart';

/// The catalogue every state is reviewed against — one blocked, one warned.
const List<ProhibitedItem> prohibitedAcknowledgmentSampleItems =
    <ProhibitedItem>[
      ProhibitedItem(
        id: 'p1',
        name: 'Weapons & Ammunition',
        category: 'Restricted',
        severity: ProhibitedItemSeverity.block,
      ),
      ProhibitedItem(
        id: 'p2',
        name: 'Prescription Medication',
        category: 'Health',
        severity: ProhibitedItemSeverity.warn,
      ),
      ProhibitedItem(
        id: 'p3',
        name: 'Unsealed Alcohol',
        category: 'Beverages',
        severity: ProhibitedItemSeverity.warn,
      ),
    ];

/// The happy read; [throwOnFetch] drives the catalogue-failure rung.
class FakeProhibitedAckRepository
    implements ProhibitedAcknowledgmentRepository {
  const FakeProhibitedAckRepository({this.throwOnFetch = false});

  final bool throwOnFetch;

  @override
  Future<List<ProhibitedItem>> fetchItems() async {
    if (throwOnFetch) throw const ServerFailure(status: 500);
    return prohibitedAcknowledgmentSampleItems;
  }

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

/// The read never lands: the first frame of every mount, held open.
class PendingProhibitedAckRepository
    implements ProhibitedAcknowledgmentRepository {
  const PendingProhibitedAckRepository();

  @override
  Future<List<ProhibitedItem>> fetchItems() =>
      Completer<List<ProhibitedItem>>().future;

  @override
  Future<void> acknowledge() async {}

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async {}
}

/// F4's state: the catalogue loads, the SERVER ack fails. Nothing is latched
/// locally, so the dialog must stay open and offer the ack again.
class AckFailingProhibitedAckRepository
    implements ProhibitedAcknowledgmentRepository {
  AckFailingProhibitedAckRepository({
    this.failure = const ServerFailure(status: 503),
  });

  final AppFailure failure;

  /// Proof for the F4 assertion: this must never be called on a failed ack.
  bool savedLocally = false;
  int acknowledgmentAttempts = 0;

  @override
  Future<List<ProhibitedItem>> fetchItems() async =>
      prohibitedAcknowledgmentSampleItems;

  @override
  Future<void> acknowledge() async {
    acknowledgmentAttempts++;
    throw failure;
  }

  @override
  Future<bool> hasAcknowledged() async => false;

  @override
  Future<void> saveLocalAcknowledgment() async => savedLocally = true;
}

/// Opens the dialog on the first frame, the way a submit failure does.
class ProhibitedAckDialogHost extends StatefulWidget {
  const ProhibitedAckDialogHost({
    super.key,
    required this.repository,
    this.matches = const <String>[],
    this.attemptAcknowledgment = false,
  });

  final ProhibitedAcknowledgmentRepository repository;

  /// The gateway's flagged keywords, rendered above the catalogue.
  final List<String> matches;
  final bool attemptAcknowledgment;

  @override
  State<ProhibitedAckDialogHost> createState() =>
      _ProhibitedAckDialogHostState();
}

class _ProhibitedAckDialogHostState extends State<ProhibitedAckDialogHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showProhibitedAcknowledgmentDialog(
        context,
        repository: widget.repository,
        matches: widget.matches,
        cubitFactory: widget.attemptAcknowledgment
            ? () {
                final cubit = ProhibitedAcknowledgmentCubit(
                  repository: widget.repository,
                  matches: widget.matches,
                );
                unawaited(() async {
                  await cubit.load();
                  if (!cubit.isClosed) await cubit.acknowledge();
                }());
                return cubit;
              }
            : null,
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
}
