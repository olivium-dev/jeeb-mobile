// Designed states for `SupportTicketScreen` (JM-063 contact-support) — ONE
// source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_11_entries.dart
//       the designer-facing, on-device Screen Catalog
//   lib/features/support/presentation/support_ticket_screen.dart
//       the JEEB PREVIEWS section at its bottom
//
// The catalog owned four private repositories (`_StubSupportRepository`,
// `_ImmediateSupportRepository`, `_PendingSupportRepository`,
// `_FailingSupportRepository`) and built its cubits inline. They moved here
// whole when the screen got a preview section — the two `_Stub`/`_Immediate`
// classes were byte-identical apart from a ticket id that nothing renders, so
// they collapsed into [SupportTicketScreenCannedRepository]. The catalog's four
// seeded states below are [readyToSubmit], [submitting], [success] and
// [networkError] — unchanged in meaning, unchanged in label.
//
// ## The screen has exactly ONE seam, and every seeded state drives it
//
// `SupportTicketScreen` takes a `cubit:` constructor override; with it supplied
// the screen never touches `GetIt`, never reads `GoRouterState.extra`, and
// hands the cubit straight to a `BlocProvider.value`. Without it, it resolves
// `sl<SupportRepository>()` and falls back to the shipped
// `StubSupportRepository`. The catalog's FIRST state deliberately keeps that
// second path (`const SupportTicketScreen()`) because the nav-honesty fallback
// is itself a designed state; everything else here goes through the seam.
//
// `SupportCubit` has no `seed:` constructor, so a phase is expressible here
// only if the cubit's own public API can reach it:
//
//  * `inputting` — `setCategory` / `setBody` / `setOrderRef` / `addAttachment`,
//    all synchronous;
//  * `submitting` — `submit()` against a repository that never completes;
//  * `success` — `submit()` against a repository that resolves immediately;
//  * `error` — `submit()` against a repository that throws a typed
//    [SupportFailure] immediately.
//
// The last three therefore call `unawaited(cubit.submit())` at construction, the
// same idiom the KYC wizard fixtures use. Only `submit()` is async, and none of
// these repositories needs a `Future.delayed`, so the phase has landed before
// the first frame is painted.
//
// ## Network-free by construction
//
// Every repository below answers from a `const` object, throws, or never
// completes. None builds a Dio client or touches GetIt, so neither dev surface
// depends on the `CatalogNetworkGuard` its host installs — that is a net, not
// the plan.
//
// ## Each state carries something only IT can produce
//
// Most of this screen's copy is fixed, and the details field is UNCONTROLLED
// (see the preview section's findings), so a state's body text never reaches
// the pixels. Every fixture below therefore differs in something the screen
// actually paints — the selected category, the order-reference field, the
// attachment chips, the phase — or is captioned by its consumer.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which no shipping code path reaches.

import 'dart:async';

import '../../../features/support/application/support_cubit.dart';
import '../../../features/support/domain/support_repository.dart';

/// Answers every submit with one canned [SupportTicket], with no latency.
///
/// Extracted from the catalog's private `_StubSupportRepository` /
/// `_ImmediateSupportRepository`, which differed only in a ticket id. Nothing
/// on this screen renders `SupportTicket.id` — that is one of the findings — so
/// the id is kept configurable here rather than duplicated into a second class.
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
///
/// This is not a synthetic condition: it is the first frame of EVERY submit,
/// because `SupportCubit.submit()` emits [SupportPhase.submitting] before it
/// awaits the repository. Holding it open is the only way to inspect that frame
/// without a real slow connection.
class SupportTicketScreenPendingRepository implements SupportRepository {
  const SupportTicketScreenPendingRepository();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) =>
      Completer<SupportTicket>().future;
}

/// Fails every submit with one typed [SupportFailure].
///
/// Both error readings the screen has — the network line and the generic
/// "Couldn't submit." — arrive through this one class, so the D30 error body is
/// exercised by the same path a real `DioException` takes.
class SupportTicketScreenFailingRepository implements SupportRepository {
  const SupportTicketScreenFailingRepository(this.failure);

  final SupportFailure failure;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    throw SupportRepositoryException(failure, 'fixture');
  }
}

/// The longest plausible complaint a user types into the details field.
///
/// Public because the render test pins the fact that NONE of it reaches the
/// screen: `_BodyField` builds an `OmdsTextField` with an `onChanged` and no
/// `controller` / `initialValue`, so a cubit that already holds a body renders
/// an empty field over an enabled Submit button.
const String kSupportTicketScreenLongBody =
    'The jeeber marked my delivery as handed over at 19:40 but nobody ever '
    'rang the door, the building concierge has no package, and the photo '
    'attached to the handover is of a different building entrance. I called '
    'the masked number four times and it rang out each time. I paid 42.50 in '
    'cash for goods I never received and I would like the order refunded and '
    'the handover photo reviewed.';

/// The body on [SupportTicketScreenPreviewFixtures.sessionExpired].
///
/// Public because the render test asserts it is on the CUBIT and not on the
/// screen after `retryFromError()` — the draft the user typed survives the
/// round trip everywhere except in the field they can read.
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
///
/// Every member is a getter so that each read hands out a FRESH cubit — the
/// preview canvas mounts many cards at once, the catalog rebuilds on every
/// navigation, and a `Cubit` handed to two hosts would emit into both.
///
/// The first four are the seeded states the Screen Catalog has shown since
/// DT-04 (its fifth, "Form — empty", constructs the screen with no seam at all
/// on purpose — see the header). The rest are reachable only from the preview
/// canvas today; they live here, beside their siblings, so adding them to the
/// catalog later is a one-line change rather than a re-derivation.
abstract final class SupportTicketScreenPreviewFixtures {
  /// A form nobody has touched: no category, no body, Submit disabled.
  ///
  /// Same picture as the catalog's seam-less "Form — empty", reached through
  /// the `cubit:` seam so that no preview depends on the state of `GetIt`.
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
    final SupportCubit cubit = SupportCubit(
      const SupportTicketScreenCannedRepository(ticketId: 'ticket-preview-902'),
    )
      ..setCategory(SupportCategory.account)
      ..setBody('Please update my phone number on file.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// CATALOG · "Error — network failure". The phone is offline.
  ///
  /// Note the category the catalog chose: [SupportCategory.payment], which a
  /// client-only account can never see in the list (see [hiddenCategory]).
  /// Kept, because the failure is what the card is for — the invisible
  /// selection is preserved separately so it can be looked at deliberately.
  static SupportCubit get networkError {
    final SupportCubit cubit = SupportCubit(
      const SupportTicketScreenFailingRepository(SupportFailure.network),
    )
      ..setCategory(SupportCategory.payment)
      ..setBody('I was charged twice for the same delivery.');
    unawaited(cubit.submit());
    return cubit;
  }

  /// A 401/403 from the gateway — the session expired while the form was open.
  ///
  /// `_ErrorView._message` folds [SupportFailure.unauthorized] in with
  /// `unknown` and `null`, so this renders the same generic line as an
  /// unclassified failure over a Submit that will 401 again.
  ///
  /// This is the one error fixture that carries BOTH a body and an order
  /// reference, because it is the one the render test drives through
  /// `retryFromError()`: the reference comes back on the returning form and the
  /// body does not, which is the asymmetry the previews are pinning.
  static SupportCubit get sessionExpired {
    final SupportCubit cubit = SupportCubit(
      const SupportTicketScreenFailingRepository(SupportFailure.unauthorized),
    )
      ..setCategory(SupportCategory.delivery)
      ..setBody(kSupportTicketScreenSessionExpiredBody)
      ..setOrderRef('REQ-4821');
    unawaited(cubit.submit());
    return cubit;
  }

  /// A category the signed-in role is not allowed to SEE, already selected.
  ///
  /// `_CategoryField._visibleCategories` hides [SupportCategory.payment] and
  /// [SupportCategory.kycAppeal] from anyone without the `jeeber` role, while
  /// `SupportCubit` will hold either of them quite happily — a deep link, a
  /// restored draft, or the catalog's own network-error state above. The result
  /// is a form with no radio checked and a live Submit button.
  static SupportCubit get hiddenCategory =>
      SupportCubit(const SupportTicketScreenCannedRepository())
        ..setCategory(SupportCategory.payment)
        ..setBody('I was charged twice for the same delivery.');

  /// The jeeber-only reading: all six categories on offer, with the KYC appeal
  /// selected.
  ///
  /// Pair with a `RoleAvailabilityCubit` carrying `jeeber`, or the two extra
  /// options are filtered straight back out.
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
  ///
  /// Pair with a `RoleAvailabilityCubit` carrying `jeeber` — the selected
  /// category is [SupportCategory.kycAppeal], whose label is the longest of the
  /// six, and it is one of the two a client never sees.
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
