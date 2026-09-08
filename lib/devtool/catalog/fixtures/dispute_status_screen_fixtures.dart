// Designed states for `DisputeStatusScreen` (JM-065 dispute-status) — ONE

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/dispute_status/data/empty_dispute_status_repository.dart';
import '../../../features/dispute_status/domain/dispute_status_repository.dart';

/// One designed state: the id the route would carry, and the repository behind
/// it.
final class DisputeStatusScreenDesignedState {
  const DisputeStatusScreenDesignedState({
    required this.disputeId,
    required this.repository,
  });

  /// The `/disputes/:id` path parameter this state stands for.
  final String disputeId;

  /// The read behind this state. Always a local fake.
  final DisputeStatusRepository repository;
}

/// Answers ONE canned dispute, with no latency.
/// Extracted from the catalog's private `_FakeDisputeStatusRepository`.
class DisputeStatusScreenCannedRepository implements DisputeStatusRepository {
  const DisputeStatusScreenCannedRepository(this.dispute);

  /// The snapshot every read returns, regardless of the id asked for.
  final DisputeStatus dispute;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => dispute;
}

/// Fails every read with one typed [DisputeStatusFailure].
/// The three failures the screen renders differently — `network`, `notFound`
/// and everything else — all arrive through this one class, so the D30 error
class DisputeStatusScreenFailingRepository implements DisputeStatusRepository {
  const DisputeStatusScreenFailingRepository(this.failure);

  final DisputeStatusFailure failure;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    throw DisputeStatusRepositoryException(failure, 'fixture');
  }
}

/// A read that never completes — the cold-load state, held open.
/// This is not a synthetic condition: it is the first frame of EVERY dispute,
/// because `DisputeStatusCubit` emits `loading` before it awaits and only
class DisputeStatusScreenPendingRepository implements DisputeStatusRepository {
  const DisputeStatusScreenPendingRepository();

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) =>
      Completer<DisputeStatus>().future;
}

/// The first read lands, every read after it fails — the WP7-N1 warm-failure
/// state, where the loaded dispute must stay on screen.
class DisputeStatusScreenRefreshFailingRepository
    implements DisputeStatusRepository {
  DisputeStatusScreenRefreshFailingRepository(this.dispute);

  final DisputeStatus dispute;
  int calls = 0;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    calls += 1;
    if (calls == 1) return dispute;
    throw const DisputeStatusRepositoryException.classified(
      DisputeStatusFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }
}

/// A perfectly healthy read that records every id it is asked for.
/// Exists for one state — [DisputeStatusScreenFixtures.blankIdWithLiveData] —
/// where the interesting fact is that [fetchedIds] stays EMPTY: neither
class DisputeStatusScreenRecordingRepository
    implements DisputeStatusRepository {
  DisputeStatusScreenRecordingRepository(this.dispute);

  /// What this repository would have returned, had anything asked.
  final DisputeStatus dispute;

  /// Every id passed to [fetchDispute], in order.
  final List<String> fetchedIds = <String>[];

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    fetchedIds.add(disputeId);
    return dispute;
  }
}

/// The back-office note on [DisputeStatusScreenFixtures.longestContent].
/// Public because the render test pins it in two places at once — see the note
const String kDisputeStatusScreenLongNote =
    'The back-office reviewed the delivery timeline, the attached chat '
    'snapshot and all five photos, then corrected the reported delivery issue. '
    'The case remains visible here with the full status history for reference.';

/// The designed states, named once for both dev surfaces.
/// Every member is a getter so that each read hands out a fresh state — the
abstract final class DisputeStatusScreenFixtures {
  /// CATALOG · "Pending". The reference reading: a dispute under
  /// review with a full D53 evidence set behind it.
  static DisputeStatusScreenDesignedState get pendingReview =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-1',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-1',
            state: DisputeState.pending,
            orderRef: 'ORD-4821',
            createdAt: '2026-07-01T10:00:00Z',
            evidence: DisputeEvidenceSummary(
              reason: 'damaged',
              comment: 'Box arrived crushed.',
              photoCount: 2,
              hasChatSnapshot: true,
              chatMessageCount: 6,
              timelineCount: 4,
            ),
          ),
        ),
      );

  /// CATALOG · "Fixed". A case that support marked as corrected.
  static DisputeStatusScreenDesignedState get fixed =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-2',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-2',
            state: DisputeState.fixed,
            note: 'The reported delivery issue was corrected.',
            orderRef: 'ORD-4790',
            createdAt: '2026-06-28T09:00:00Z',
            resolvedAt: '2026-06-29T14:00:00Z',
            evidence: DisputeEvidenceSummary(
              reason: 'no_show',
              photoCount: 1,
              hasVoice: true,
              timelineCount: 3,
            ),
          ),
        ),
      );

  /// CATALOG · "Error — not found (shipped fallback repository)".
  /// The blank id is what produces the error: `load()` short-circuits to
  static DisputeStatusScreenDesignedState get notFoundFallback =>
      const DisputeStatusScreenDesignedState(
        disputeId: '',
        repository: EmptyDisputeStatusRepository(),
      );

  /// A fixed case with a detailed back-office note.
  static DisputeStatusScreenDesignedState get fixedWithNote =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-8',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-8',
            state: DisputeState.fixed,
            note: 'Reviewed against the courier GPS trail.',
            orderRef: 'ORD-4855',
            conversationRef: 'conv-8',
            resolvedAt: '2026-07-04T11:20:00Z',
            evidence: DisputeEvidenceSummary(
              reason: 'no_show',
              hasChatSnapshot: true,
              chatMessageCount: 11,
            ),
          ),
        ),
      );

  /// The EMPTY state: a pending dispute with no evidence summary items.
  /// Reachable in production whenever the wire carries no `reason`, `comment`,
  static DisputeStatusScreenDesignedState get pendingNoEvidence =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-6',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-6',
            state: DisputeState.pending,
            orderRef: 'ORD-4877',
            createdAt: '2026-07-30T08:15:00Z',
          ),
        ),
      );

  /// WP7-N1: a refresh that fails over a loaded dispute — the rows stay and
  /// `dispute_status_refresh_error` rides above them.
  static DisputeStatusScreenDesignedState get refreshFailure =>
      DisputeStatusScreenDesignedState(
        disputeId: 'dsp-8',
        repository: DisputeStatusScreenRefreshFailingRepository(
          const DisputeStatus(
            id: 'dsp-8',
            state: DisputeState.pending,
            orderRef: 'ORD-4910',
            createdAt: '2026-07-30T08:15:00Z',
          ),
        ),
      );

  /// ES-20: a dispute with NO status history — the card still draws, with the
  /// empty rung inside it.
  static DisputeStatusScreenDesignedState get emptyHistory =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-9',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-9',
            state: DisputeState.pending,
            orderRef: 'ORD-4911',
            createdAt: '2026-07-30T09:00:00Z',
          ),
        ),
      );

  /// Cold start: the fetch is on the wire and nothing has come back.
  static DisputeStatusScreenDesignedState get coldRead =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-3',
        repository: DisputeStatusScreenPendingRepository(),
      );

  /// The phone is offline (or the compliment-service is unreachable).
  static DisputeStatusScreenDesignedState get networkFailure =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-4',
        repository: DisputeStatusScreenFailingRepository(
          DisputeStatusFailure.network,
        ),
      );

  /// A 401/403 from the gateway — the session expired while the screen was
  /// being opened from a push notification.
  static DisputeStatusScreenDesignedState get sessionExpired =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-5',
        repository: DisputeStatusScreenFailingRepository(
          DisputeStatusFailure.unauthorized,
        ),
      );

  /// A dispute whose wire `status` the parser did not recognize.
  /// `DioDisputeStatusRepository._state()` maps anything outside
  static DisputeStatusScreenDesignedState get unknownWireState =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-7',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-7',
            state: DisputeState.unknown,
            orderRef: 'ORD-4901',
            createdAt: '2026-07-28T16:40:00Z',
            evidence: DisputeEvidenceSummary(reason: 'fraud', timelineCount: 2),
          ),
        ),
      );

  /// The read behind [blankIdWithLiveData], shared so a test can inspect it.
  /// A single instance rather than a getter: the assertion is that
  static final DisputeStatusScreenRecordingRepository blankIdRepository =
      DisputeStatusScreenRecordingRepository(
        const DisputeStatus(
          id: 'dsp-9',
          state: DisputeState.closed,
          orderRef: 'ORD-4930',
        ),
      );

  /// A blank id in front of a repository that would have answered.
  /// Renders exactly like [notFoundFallback] — that IS the point. The dispute
  static DisputeStatusScreenDesignedState get blankIdWithLiveData =>
      DisputeStatusScreenDesignedState(
        disputeId: '  ',
        repository: blankIdRepository,
      );

  /// The longest plausible content on every axis at once — and two defects the
  /// production parser makes ordinary.
  static DisputeStatusScreenDesignedState get longestContent =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            state: DisputeState.fixed,
            note: kDisputeStatusScreenLongNote,
            orderRef: 'REQ-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            conversationRef: 'conv-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            createdAt: '2026-06-28T09:00:00Z',
            resolvedAt: '2026-07-02T14:31:00Z',
            evidence: DisputeEvidenceSummary(
              reason: 'wrong_item',
              comment: kDisputeStatusScreenLongNote,
              photoCount: 5,
              hasVoice: true,
              hasChatSnapshot: true,
              chatMessageCount: 142,
              timelineCount: 18,
            ),
          ),
        ),
      );
}
