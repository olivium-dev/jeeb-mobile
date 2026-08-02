// Designed states for `DisputeStatusScreen` (JM-065 dispute-status) — ONE
// source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_03_entries.dart
//       the designer-facing, on-device Screen Catalog
//   lib/features/dispute_status/presentation/dispute_status_screen.dart
//       the JEEB PREVIEWS section at its bottom
//
// The catalog owned a private `_FakeDisputeStatusRepository` and three inline
// `DisputeStatus` literals. They moved here whole when the screen got a preview
// section: two copies of the same "designed state" drift, and the catalog is
// the one a designer signs off against. The three catalog states below are
// [openUnderReview], [resolvedRefund] and [notFoundFallback] — unchanged in
// meaning, unchanged in label.
//
// ## The screen has exactly ONE seam, and every state drives it
//
// `DisputeStatusScreen` takes a `repository:` constructor override
// (40_GUARDRAILS_ARCH §5.4) and builds its own `DisputeStatusCubit(...)..load()`
// at mount. There is no cubit seed, so a state is expressible here only if the
// real `load()` can reach it. That bounds the set:
//
//  * `loaded` — a repository that answers with a canned [DisputeStatus];
//  * `failed` — a repository that throws a typed [DisputeStatusFailure], OR a
//    blank `disputeId`, which `load()` short-circuits to `notFound` WITHOUT
//    calling the repository at all;
//  * `loading` — a repository whose future never completes.
//
// Note what that last bullet means for [notFoundFallback], the catalog's third
// state: its `EmptyDisputeStatusRepository` is never actually consulted,
// because the blank id short-circuits first. The card is a truthful picture of
// the D30 error surface either way, which is what it was there for.
//
// ## Network-free by construction
//
// Every repository here answers from a `const` object, throws, or never
// completes. None builds a Dio client or touches GetIt, so neither dev surface
// depends on the `CatalogNetworkGuard` its host installs — that is a net, not
// the plan.
//
// ## Each state carries content only IT can produce
//
// The screen paints no dispute id, no order reference and no dates (see the
// preview section's findings), so two states that share an evidence set are
// pixel-identical. Every fixture below therefore varies at least one visible
// line — the reason, the message counts, the outcome — so that a card silently
// wired to a neighbour's fixture is visible rather than plausible.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import '../../../features/dispute_status/data/empty_dispute_status_repository.dart';
import '../../../features/dispute_status/domain/dispute_status_repository.dart';

/// One designed state: the id the route would carry, and the repository behind
/// it.
///
/// Both are needed together — a blank id changes the outcome no matter what the
/// repository would have answered — so they travel as a pair rather than as two
/// values a caller could mismatch.
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
///
/// Extracted from the catalog's private `_FakeDisputeStatusRepository`.
class DisputeStatusScreenCannedRepository implements DisputeStatusRepository {
  const DisputeStatusScreenCannedRepository(this.dispute);

  /// The snapshot every read returns, regardless of the id asked for.
  final DisputeStatus dispute;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async => dispute;
}

/// Fails every read with one typed [DisputeStatusFailure].
///
/// The three failures the screen renders differently — `network`, `notFound`
/// and everything else — all arrive through this one class, so the D30 error
/// body is exercised by the same path a real `DioException` takes.
class DisputeStatusScreenFailingRepository implements DisputeStatusRepository {
  const DisputeStatusScreenFailingRepository(this.failure);

  final DisputeStatusFailure failure;

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) async {
    throw DisputeStatusRepositoryException(failure, 'fixture');
  }
}

/// A read that never completes — the cold-load state, held open.
///
/// This is not a synthetic condition: it is the first frame of EVERY dispute,
/// because `DisputeStatusCubit` emits `loading` before it awaits and only
/// leaves it when the fetch resolves. Holding it open is the only way to
/// inspect that frame without a real slow connection.
class DisputeStatusScreenPendingRepository implements DisputeStatusRepository {
  const DisputeStatusScreenPendingRepository();

  @override
  Future<DisputeStatus> fetchDispute(String disputeId) =>
      Completer<DisputeStatus>().future;
}

/// A perfectly healthy read that records every id it is asked for.
///
/// Exists for one state — [DisputeStatusScreenFixtures.blankIdWithLiveData] —
/// where the interesting fact is that [fetchedIds] stays EMPTY: neither
/// `load()` nor `refresh()` ever reaches the repository when the id is blank.
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
///
/// Public because the render test pins it in two places at once — see the note
/// on that fixture. Long enough to wrap several times at 320 pt and to be the
/// tallest single string this screen can be handed.
const String kDisputeStatusScreenLongNote =
    'The back-office reviewed the delivery timeline, the attached chat '
    'snapshot and all five photos, and issued a partial refund covering the '
    'damaged contents. The remaining amount covers the completed delivery leg '
    'and is not refundable under the cancellation policy.';

/// The designed states, named once for both dev surfaces.
///
/// Every member is a getter so that each read hands out a fresh state — the
/// preview canvas mounts many cards at once and the catalog rebuilds on every
/// navigation. [blankIdRepository] is the one deliberate exception: it is a
/// single shared instance precisely so a test can look at what it recorded.
///
/// The first three are the states the Screen Catalog has shown since DT-04.
/// The rest are reachable only from the preview canvas today; they are kept
/// here, beside their siblings, so that adding them to the catalog later is a
/// one-line change rather than a re-derivation.
abstract final class DisputeStatusScreenFixtures {
  /// CATALOG · "Open — under review". The reference reading: a dispute under
  /// review with a full D53 evidence set behind it.
  static DisputeStatusScreenDesignedState get openUnderReview =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-1',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-1',
            state: DisputeState.open,
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

  /// CATALOG · "Resolved — refund issued (D2)". The happy terminal outcome,
  /// with an amount AND a currency — the only fixture here that has both.
  static DisputeStatusScreenDesignedState get resolvedRefund =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-2',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-2',
            state: DisputeState.resolved,
            outcome: DisputeOutcome.refund,
            resolution: 'refund',
            refundAmount: 35,
            currency: 'USD',
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
  ///
  /// The blank id is what produces the error: `load()` short-circuits to
  /// `notFound` before the repository is consulted, so the shipped
  /// [EmptyDisputeStatusRepository] here is a belt-and-braces stand-in for the
  /// unconfigured-GetIt path rather than the thing under test.
  static DisputeStatusScreenDesignedState get notFoundFallback =>
      const DisputeStatusScreenDesignedState(
        disputeId: '',
        repository: EmptyDisputeStatusRepository(),
      );

  /// The other resolved outcome (D2): a penalty, and no amount on the wire.
  ///
  /// `refundAmount == null` is the ordinary case for a penalty — the money
  /// moved on the jeeber's side — so the outcome line drops the figure
  /// entirely. Also the only fixture with a back-office note on a resolved
  /// dispute and no photos at all.
  static DisputeStatusScreenDesignedState get resolvedPenalty =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-8',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-8',
            state: DisputeState.resolved,
            outcome: DisputeOutcome.penalty,
            resolution: 'penalty',
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

  /// The EMPTY state: an open dispute whose evidence summary has nothing in it.
  ///
  /// Reachable in production whenever the wire carries no `reason`, `comment`,
  /// `photos`, `voiceUrl`, `evidence.chatSnapshotUrl` or `evidence.timeline` —
  /// which is every dispute opened from a path that does not auto-attach, and
  /// every dispute the compliment-service returns before the evidence POST has
  /// landed.
  static DisputeStatusScreenDesignedState get openNoEvidence =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-6',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-6',
            state: DisputeState.open,
            orderRef: 'ORD-4877',
            createdAt: '2026-07-30T08:15:00Z',
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
  ///
  /// `DioDisputeStatusRepository._state()` maps anything outside
  /// open/pending/in_review/resolved/closed to [DisputeState.unknown] — an
  /// `escalated` dispute, a `withdrawn` one, or a payload where the field is
  /// simply absent. Very reachable, and the reason this is a designed state
  /// rather than a curiosity.
  static DisputeStatusScreenDesignedState get unknownWireState =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-7',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-7',
            state: DisputeState.unknown,
            resolution: 'escalated',
            orderRef: 'ORD-4901',
            createdAt: '2026-07-28T16:40:00Z',
            evidence: DisputeEvidenceSummary(
              reason: 'fraud',
              timelineCount: 2,
            ),
          ),
        ),
      );

  /// The read behind [blankIdWithLiveData], shared so a test can inspect it.
  ///
  /// A single instance rather than a getter: the assertion is that
  /// [DisputeStatusScreenRecordingRepository.fetchedIds] is still EMPTY after
  /// the screen has mounted and Retry has been tapped, which only holds if the
  /// preview and the test are looking at the same object.
  static final DisputeStatusScreenRecordingRepository blankIdRepository =
      DisputeStatusScreenRecordingRepository(
    const DisputeStatus(
      id: 'dsp-9',
      state: DisputeState.resolved,
      outcome: DisputeOutcome.dismissed,
      resolution: 'dismissed',
      orderRef: 'ORD-4930',
    ),
  );

  /// A blank id in front of a repository that would have answered.
  ///
  /// Renders exactly like [notFoundFallback] — that IS the point. The dispute
  /// is sitting there, resolved, one call away; the id never reaches the read
  /// on mount, and `refresh()` short-circuits on the same guard, so the Retry
  /// button on this card cannot ever change what it shows.
  static DisputeStatusScreenDesignedState get blankIdWithLiveData =>
      DisputeStatusScreenDesignedState(
        disputeId: '  ',
        repository: blankIdRepository,
      );

  /// The longest plausible content on every axis at once — and two defects the
  /// production parser makes ordinary.
  ///
  ///  * `currency` is null while `refundAmount` is not. The Dio parser reads
  ///    the two fields independently, so a payload that omits `currency`
  ///    produces a bare figure in the outcome line.
  ///  * `note` and `evidence.comment` are the SAME string, because
  ///    `DioDisputeStatusRepository._evidence()` reads
  ///    `comment ?? note` while `_parse()` reads `note` — so any dispute whose
  ///    wire object carries `note` and no `comment` renders that text twice.
  ///
  /// Everything else is at its ceiling: a UUID-shaped id, five photos, a
  /// 142-message chat snapshot, an 18-step timeline, and the longest reason
  /// label in the resolver.
  static DisputeStatusScreenDesignedState get longestContent =>
      const DisputeStatusScreenDesignedState(
        disputeId: 'dsp-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
        repository: DisputeStatusScreenCannedRepository(
          DisputeStatus(
            id: 'dsp-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f',
            state: DisputeState.resolved,
            outcome: DisputeOutcome.refund,
            resolution: 'partial_refund',
            refundAmount: 1234.5,
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
