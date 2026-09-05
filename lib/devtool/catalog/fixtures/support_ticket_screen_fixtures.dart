// Designed states for `SupportTicketScreen` (JM-063 contact-support) — ONE

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../features/case_evidence/domain/case_evidence.dart';
import '../../../features/support/application/support_cubit.dart';
import '../../../features/support/data/unavailable_support_repository.dart';
import '../../../features/support/domain/support_repository.dart';

/// Answers every submit with one canned [SupportTicket], with no latency.
/// Extracted from the catalog's private `_StubSupportRepository` /
/// `_ImmediateSupportRepository`, which differed only in a ticket id. Nothing
class SupportTicketScreenCannedRepository implements SupportRepository {
  const SupportTicketScreenCannedRepository({
    this.ticketId = 'ticket-preview-001',
  });

  /// The id the ticket comes back with. Never painted by the screen.
  final String ticketId;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      SupportTicket(id: ticketId, status: 'open');
}

/// A submit that never resolves — the in-flight phase, held open.
/// This is not a synthetic condition: it is the first frame of EVERY submit,
/// because `SupportCubit.submit()` emits [SupportPhase.submitting] before it
class SupportTicketScreenPendingRepository implements SupportRepository {
  const SupportTicketScreenPendingRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) =>
      Completer<SupportTicket>().future;
}

/// Fails every submit with one typed [SupportFailure].
/// Both error readings the screen has — the network line and the generic
/// "Couldn't submit." — arrive through this one class, so the D30 error body is
class SupportTicketScreenFailingRepository implements SupportRepository {
  const SupportTicketScreenFailingRepository(this.failure, [this.appFailure]);

  final SupportFailure failure;

  /// The classified failure the screen actually renders through.
  final AppFailure? appFailure;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    throw SupportRepositoryException.classified(
      failure,
      message: 'fixture',
      appFailure: appFailure ?? const UnknownFailure(),
    );
  }
}

/// UX-28: the upload leg fails, so the form shows the per-row failure note and
/// its retry rather than a bare "!".
class SupportTicketScreenUploadFailingRepository
    implements SupportRepository, SupportTicketV2Repository {
  const SupportTicketScreenUploadFailingRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) =>
      submitTicketV2(draft);

  @override
  Future<SupportTicket> submitTicketV2(
    SupportTicketDraft draft, {
    CaseAttachmentProgressCallback? onProgress,
  }) async {
    for (final CaseAttachmentDraft attachment in draft.attachments) {
      onProgress?.call(
        CaseAttachmentProgress(
          localId: attachment.localId,
          state: CaseAttachmentUploadState.failed,
        ),
      );
    }
    throw const SupportRepositoryException.classified(
      SupportFailure.upload,
      appFailure: ServerFailure(status: 502),
    );
  }
}

/// The longest plausible complaint a user types into the details field.
/// Public because the render test pins the fact that NONE of it reaches the
const String kSupportTicketScreenLongBody =
    'The jeeber marked my delivery as handed over at 19:40 but nobody ever '
    'rang the door, the building concierge has no package, and the photo '
    'attached to the handover is of a different building entrance. I called '
    'the masked number four times and it rang out each time. I paid 42.50 in '
    'cash for goods I never received and I would like the order refunded and '
    'the handover photo reviewed.';

/// The body on [SupportTicketScreenPreviewFixtures.sessionExpired].
/// Public because the render test asserts it is on the CUBIT and not on the
const String kSupportTicketScreenSessionExpiredBody =
    'I cannot reach anyone about order REQ-4821 and the jeeber stopped '
    'replying in chat.';

/// An order reference at its full UUID-shaped length.
const String kSupportTicketScreenLongOrderRef =
    'REQ-2f8c1d94-7b6a-4e05-9c3f-0a1b2c3d4e5f';

/// The five attachment paths a capped ticket carries.
const List<String> kSupportTicketScreenFullAttachments = <String>[
  'support_attach_door_1.jpg',
  'support_attach_door_2.jpg',
  'support_attach_concierge_desk.jpg',
  'support_attach_handover_photo.jpg',
  'support_attach_chat_screenshot.jpg',
];

/// The designed states, named once for both dev surfaces.
/// Every member is a getter so that each read hands out a FRESH cubit — the
abstract final class SupportTicketScreenPreviewFixtures {
  /// A form nobody has touched: no category, no body, Submit disabled.
  /// Same picture as the catalog's seam-less "Form — empty", reached through
  static SupportCubit get emptyForm =>
      SupportCubit(const SupportTicketScreenCannedRepository());

  /// CATALOG · "Form — ready to submit". A category picked and a body typed, so
  /// `canSubmit` is true and the CTA is live.
  static SupportCubit get readyToSubmit =>
      SupportCubit(const SupportTicketScreenCannedRepository())
        ..setCategory(SupportCategory.delivery)
        ..setBody('My delivery never arrived and the Jeeber is unreachable.');

  /// CATALOG · "Submitting". The POST is on the wire and nothing has come back.
  static SupportCubit get submitting {
    final SupportCubit cubit =
        SupportCubit(const SupportTicketScreenPendingRepository())
          ..setCategory(SupportCategory.delivery)
          ..setBody('My delivery never arrived.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// CATALOG · "Success — confirmation". The ticket was created.
  static SupportCubit get success {
    final SupportCubit cubit =
        SupportCubit(
            const SupportTicketScreenCannedRepository(
              ticketId: 'ticket-preview-902',
            ),
          )
          ..setCategory(SupportCategory.account)
          ..setBody('Please update my phone number on file.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// CATALOG · "Error — network failure". The phone is offline.
  /// Note the category the catalog chose: [SupportCategory.payment], which a
  static SupportCubit get networkError {
    final SupportCubit cubit =
        SupportCubit(
            const SupportTicketScreenFailingRepository(SupportFailure.network),
          )
          ..setCategory(SupportCategory.payment)
          ..setBody('I was charged twice for the same delivery.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// A 401/403 from the gateway — the session expired while the form was open.
  /// `_ErrorView._message` folds [SupportFailure.unauthorized] in with
  static SupportCubit get sessionExpired {
    final SupportCubit cubit =
        SupportCubit(
            const SupportTicketScreenFailingRepository(
              SupportFailure.unauthorized,
            ),
          )
          ..setCategory(SupportCategory.delivery)
          ..setBody(kSupportTicketScreenSessionExpiredBody)
          ..setOrderRef('REQ-4821');
    unawaited(cubit.submit());
    return cubit;
  }

  /// UX-25: a 401 gets the sign-in way out, never a Retry that 401s forever.
  static SupportCubit get unauthorized {
    final SupportCubit cubit =
        SupportCubit(
            const SupportTicketScreenFailingRepository(
              SupportFailure.unauthorized,
              UnauthorizedFailure(),
            ),
          )
          ..setCategory(SupportCategory.delivery)
          ..setBody('I cannot reach my courier.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// UX-28: an attachment that did not upload, with its own note + retry.
  static SupportCubit get uploadFailure {
    final SupportCubit cubit =
        SupportCubit(const SupportTicketScreenUploadFailingRepository())
          ..setCategory(SupportCategory.delivery)
          ..setBody('The parcel arrived crushed.')
          ..addAttachment('support_attach_1.jpg');
    unawaited(cubit.submit());
    return cubit;
  }

  /// WP7-N4: DI has no SupportRepository — the release fallback fails loudly
  /// instead of confirming a ticket that was never created.
  static SupportCubit get unavailableRepository {
    final SupportCubit cubit =
        SupportCubit(const UnavailableSupportRepository())
          ..setCategory(SupportCategory.other)
          ..setBody('Anything at all.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// A category the signed-in role is not allowed to SEE, already selected.
  /// `_CategoryField._visibleCategories` hides [SupportCategory.payment] and
  static SupportCubit get hiddenCategory =>
      SupportCubit(const SupportTicketScreenCannedRepository())
        ..setCategory(SupportCategory.payment)
        ..setBody('I was charged twice for the same delivery.');

  /// The jeeber-only reading: all six categories on offer, with the KYC appeal
  /// selected.
  static SupportCubit get jeeberAppeal =>
      SupportCubit(const SupportTicketScreenCannedRepository())
        ..setCategory(SupportCategory.kycAppeal)
        ..setBody('My ID photo was rejected but the document is valid.')
        ..setOrderRef('REQ-4821');

  /// The attachment ceiling: five photos on, which is where the "Add photo"
  /// button disappears.
  static SupportCubit get attachmentsAtCap {
    final SupportCubit cubit =
        SupportCubit(const SupportTicketScreenCannedRepository())
          ..setCategory(SupportCategory.dispute)
          ..setBody('Photos of the door, the desk and the chat thread.')
          ..setOrderRef('REQ-4821');
    for (final String path in kSupportTicketScreenFullAttachments) {
      cubit.addAttachment(path);
    }
    return cubit;
  }

  /// Every axis at its ceiling at once: the longest category label, a
  /// UUID-shaped order reference, five attachments and a 380-character body.
  static SupportCubit get longestContent {
    final SupportCubit cubit =
        SupportCubit(const SupportTicketScreenCannedRepository())
          ..setCategory(SupportCategory.kycAppeal)
          ..setBody(kSupportTicketScreenLongBody)
          ..setOrderRef(kSupportTicketScreenLongOrderRef);
    for (final String path in kSupportTicketScreenFullAttachments) {
      cubit.addAttachment(path);
    }
    return cubit;
  }
}
