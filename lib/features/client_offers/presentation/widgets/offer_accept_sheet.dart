import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/offer_accept_cubit.dart';
import '../../application/offer_accept_state.dart';
import '../../data/fake_offers_repository.dart';
import '../../domain/offer.dart';
import '../../domain/offers_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/jeeber_vehicle.dart';

class OfferAcceptSheet extends StatelessWidget {
  const OfferAcceptSheet({
    super.key,
    required this.offer,
    required this.requestId,
    this.repository,
    this.onConfirmed,
    this.onCancelled,
    this.initialState,
  });

  final Offer offer;

  final String requestId;

  final OffersRepository? repository;

  final void Function(OfferAcceptResult result)? onConfirmed;

  final VoidCallback? onCancelled;

  final OfferAcceptState? initialState;

  OffersRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<OffersRepository>()) return sl<OffersRepository>();
    return FakeOffersRepository();
  }

  static Future<void> show(
    BuildContext context, {
    required Offer offer,
    required String requestId,
    OffersRepository? repository,
  }) {
    final rootContext = context;
    final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
      alpha: UIConstants.opacityHigh,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: scrim,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: OmdsBorderRadius.topXLarge,
      ),
      builder: (sheetContext) => OfferAcceptSheet(
        offer: offer,
        requestId: requestId,
        repository: repository,
        onConfirmed: (result) {
          Navigator.of(sheetContext).pop();
          final deliveryId = result.deliveryId;
          rootContext.goNamed(
            'chat-detail',
            pathParameters: {'id': requestId},
            queryParameters: {
              if (deliveryId != null && deliveryId.isNotEmpty)
                'deliveryId': deliveryId,
            },
          );
        },
        onCancelled: () => Navigator.of(sheetContext).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<OfferAcceptCubit>(
      create: (_) => OfferAcceptCubit(
        repository: repo,
        requestId: requestId,
        offerId: offer.id,
        initialState: initialState,
      ),
      child: _OfferAcceptView(
        offer: offer,
        onConfirmed: onConfirmed,
        onCancelled: onCancelled,
      ),
    );
  }
}

class _OfferAcceptView extends StatelessWidget {
  const _OfferAcceptView({
    required this.offer,
    this.onConfirmed,
    this.onCancelled,
  });

  final Offer offer;
  final void Function(OfferAcceptResult result)? onConfirmed;
  final VoidCallback? onCancelled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final feeFormatted = MoneyFormat.format(
      offer.fee,
      currency: offer.currency,
    );
    final jeeberDisplayName =
        displayNameOrNull(offer.jeeberName) ?? l10n.offersCardJeeberFallback;
    return BlocConsumer<OfferAcceptCubit, OfferAcceptState>(
      listenWhen: (prev, next) =>
          prev.status != next.status &&
          next.status == OfferAcceptStatus.succeeded,
      listener: (context, state) {
        onConfirmed?.call(state.result ?? OfferAcceptResult.empty);
      },
      builder: (context, state) {
        return PopScope(
          canPop: !state.isSubmitting,
          child: Semantics(
            identifier: 'offer_accept_sheet',
            explicitChildNodes: true,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  Spacing.xLarge,
                  Spacing.small,
                  Spacing.xLarge,
                  Spacing.xLarge,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SheetDragHandle(),
                    const SizedBox(height: Spacing.large),
                    Semantics(
                      identifier: 'offer_accept_jeeber_name',
                      child: Text(
                        l10n.offerAcceptTitle(jeeberDisplayName),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'offer_accept_price_label',
                      child: Text(
                        l10n.offersCardFee(feeFormatted, offer.currency),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'offer_accept_other_offers_note',
                      child: Text(
                        l10n.chatOfferAcceptOnlyOne,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (state.status == OfferAcceptStatus.failed &&
                        state.error != null) ...[
                      const SizedBox(height: Spacing.medium),
                      Semantics(
                        identifier: 'offer_accept_error',
                        liveRegion: true,
                        child: Container(
                          key: const Key('offer-accept-error'),
                          padding: const EdgeInsets.all(Spacing.small),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: OmdsBorderRadius.small,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: Spacing.small),
                              Expanded(
                                child: Text(
                                  _failureCopy(l10n, state.error!),
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: Spacing.twoXLarge),
                    Semantics(
                      identifier: 'offer_accept_confirm_cta',
                      container: true,
                      button: true,
                      label: l10n.chatOfferAccept,
                      onTap: state.isSubmitting
                          ? null
                          : () => context.read<OfferAcceptCubit>().confirm(),
                      child: ExcludeSemantics(
                        child: OmdsLoadingButton(
                          key: const Key('offer-accept-confirm-cta'),
                          text: state.isSubmitting
                              ? l10n.chatOfferAccepting
                              : l10n.chatOfferAccept,
                          isLoading: state.isSubmitting,
                          onTap: () =>
                              context.read<OfferAcceptCubit>().confirm(),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          borderRadius: OmdsBorderRadius.uiSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'offer_accept_cancel_cta',
                      container: true,
                      button: true,
                      label: l10n.actionCancel,
                      onTap: state.isSubmitting ? null : onCancelled,
                      child: ExcludeSemantics(
                        child: OmdsPrimaryButton(
                          key: const Key('offer-accept-cancel-cta'),
                          text: l10n.actionCancel,
                          variant: OmdsButtonVariant.outlined,
                          isEnabled: !state.isSubmitting,
                          onTap: () => onCancelled?.call(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _failureCopy(AppLocalizations l10n, OffersFailure failure) {
    switch (failure) {
      case OffersFailure.network:
        return l10n.offersErrorNetwork;
      case OffersFailure.requestNotOpen:
        return l10n.offersErrorRequestNotOpen;
      case OffersFailure.offerNotPending:
        return l10n.offersErrorOfferNotPending;
      case OffersFailure.jeeberAtCapacity:
        return l10n.offersErrorJeeberAtCapacity;
      case OffersFailure.rateLimited:
      case OffersFailure.unknown:
        return l10n.offersErrorGeneric;
    }
  }
}

class _SheetDragHandle extends StatelessWidget {
  const _SheetDragHandle();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/client_offers/offer_accept_sheet_preview_test.dart
// ===========================================================================

// Widget previews for [OfferAcceptSheet] — run with
// `flutter widget-preview start`.
//
// JM-029 `offer-accept-confirm` is the D11/D71 comprehension gate: the one
// surface between "I like this bid" and an irreversible accept that captures
// the fee and closes every losing offer. Almost everything that has gone wrong
// with it went wrong in **copy and state**, not in the accept call — a
// past-tense title (SW-14), a raw `jeeb-<hash>` where a name belongs (W6/SW-08),
// and a failed accept that silently stopped the spinner and said nothing
// (sprint-009 scenario #7). Those are exactly the things you only catch by
// looking, which is what these previews are for.
//
// **Network-free by construction.** Two seams are used and neither can reach a
// gateway:
//
// * `initialState:` presets the [OfferAcceptCubit]'s state, so the submitting
//   and failed states are reached without driving `confirm()` at all.
// * `repository:` takes [_OfferAcceptSheetCannedRepository], a local fake with
//   no transport of any kind, so the Confirm button in the canvas resolves
//   against canned data instead of falling through to DI /
//   [FakeOffersRepository].
//
// Fixture data is lifted from `test/features/client_offers/offer_accept_sheet_test.dart`
// and `..._tense_test.dart` — the Kamal Hajj / `offer-001` / $6.00 offer and the
// `jeeb-e1a35ea8a520` synthetic handle — so the preview and the widget tests
// stay directly comparable.
//
// **What the matrix shows that a widget test does not.**
//
// * *EN 200% text* — **this is the one that finds something.** The sheet's
//   [Column] has no scroll fallback (same shape as
//   `ConfirmDeliveryActionSheet`), and `showModalBottomSheet(isScrollControlled:
//   true)` grants height, it does not add scrolling. Measured heights of the
//   sheet at 390 pt wide: idle **328 → 564** pt from 1.0 to 2.0 text; with the
//   BR-10 capacity banner **468 → 924** pt, i.e. a hard
//   `RenderFlex overflowed by 160 pixels` against an 844 pt phone, and by
//   **516 pt** on a 320×568 one. What overflows is the bottom of the stack: the
//   Confirm and Cancel CTAs. See the note on
//   [offerAcceptSheetFailedAtCapacity].
// * *AR RTL dark* — the fee is the one string that must NOT mirror. It is
//   wrapped in a U+2066/U+2069 LTR isolate by `MoneyFormat`, so `$6.00` has to
//   stay `$6.00` and never render as `6.00$`. The rest of the sheet mirrors on
//   its own (`EdgeInsetsDirectional` padding; the banner's [Row] takes its
//   direction from the ambient [Directionality]), and the dark palette is
//   comfortable throughout — the two roles worth a number are the fee/handle
//   `primary` on `surface` at **10.85:1** and the banner's `onErrorContainer`
//   on `errorContainer` at **7.24:1**.
//
// Measurements above come from `flutter test`, whose substituted test font is
// wider and taller than the production Inter face, so treat them as an upper
// bound on the real device — except the 320 pt overflow, which is far past any
// font-metric slack.

/// Phone width, with room for the idle stack (drag handle → title → fee → D71
/// note → two 48 pt CTAs), measured at 328 pt.
///
/// Deliberately NOT sized to fit the matrix's 200%-text rendering, unlike
/// `ConfirmDeliveryActionSheet`'s box: that rendering is 564 pt and there is no
/// phone-shaped box that would contain it *and* the error states. The stripes it
/// paints in the canvas are the widget's problem, not the canvas's.
const Size _offerAcceptSheetBox = Size(390, 400);

/// The same stack plus the inline error banner — 408 pt for the one-line
/// request-closed copy, 468 pt for the three-line BR-10 capacity copy.
const Size _offerAcceptSheetErrorBox = Size(390, 500);

/// A repository with no transport at all.
///
/// The sheet resolves its repository as "the explicit one, else the
/// DI-registered `OffersRepository`, else a `FakeOffersRepository`". Passing
/// this explicitly closes that chain: a preview must never depend on whether
/// the canvas happened to build the DI graph, and `FakeOffersRepository` —
/// while itself in-memory — is production code with a randomised seed and a
/// wall-clock drip feed, which is not what a preview fixture should be.
///
/// `fetchOffers` is never called by this sheet (the review list owns the read);
/// it is implemented only to satisfy the interface.
class _OfferAcceptSheetCannedRepository implements OffersRepository {
  const _OfferAcceptSheetCannedRepository({this.failure});

  /// When set, `acceptOffer` throws this instead of succeeding — so tapping
  /// Confirm in the canvas reaches the inline error banner for real.
  final OffersFailure? failure;

  @override
  Future<OffersSnapshot> fetchOffers(String requestId) async =>
      const OffersSnapshot(
        offers: <Offer>[],
        windowExpiresAt: null,
        requestIsOpen: true,
      );

  @override
  Future<OfferAcceptResult> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    final OffersFailure? f = failure;
    if (f != null) throw OffersRepositoryException(f);
    return const OfferAcceptResult(
      conversationId: 'conv-preview-accepted',
      deliveryId: 'dlv-preview-001',
    );
  }
}

/// The offer under confirmation. Defaults reproduce the fixture the JM-029
/// widget tests use.
Offer _offerAcceptSheetOffer({
  String jeeberName = 'Kamal Hajj',
  double fee = 6.0,
  String currency = 'USD',
}) =>
    Offer(
      id: 'offer-001',
      jeeberId: 'user-jeeber-002',
      jeeberName: jeeberName,
      fee: fee,
      currency: currency,
      etaMinutes: 20,
      vehicle: JeeberVehicle.scooter,
      rating: 4.8,
      ratingCount: 42,
      // Fixed, never `DateTime.now()`: a preview that changes between two
      // renders is a preview you cannot diff.
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
///
/// Mirrors `_sheetHost` in `lib/devtool/catalog/entries/batch_02_entries.dart`
/// so the catalog and the canvas frame the same widget the same way. The sheet
/// is *content*, not a route: it renders a bare [Column] and relies on its host
/// for the scrim and the rounded top corners.
Widget _offerAcceptSheetHosted(
  Offer offer, {
  OfferAcceptState? initialState,
  OffersFailure? failure,
}) =>
    Align(
      alignment: Alignment.bottomCenter,
      child: OfferAcceptSheet(
        offer: offer,
        requestId: 'req-client-001-offers',
        repository: _OfferAcceptSheetCannedRepository(failure: failure),
        initialState: initialState,
        // No-ops on purpose. Production pops the sheet and navigates to
        // order-chat; neither belongs in a canvas.
        onConfirmed: (OfferAcceptResult _) {},
        onCancelled: () {},
      ),
    );

/// The default reading: a real Jeeber name, a small USD fee, nothing in flight.
///
/// The title must be a **question** — "Accept Kamal Hajj's offer?" — and it is
/// the SW-14 regression that makes this worth looking at rather than assuming.
/// The slot used to borrow `chatSystemOfferAcceptedNamed` ("{name}'s offer was
/// accepted"), a chat system message written to narrate an accept that had
/// already happened, so the sheet reported a decision the customer had not made
/// yet while the button below it was still asking them to make it. If this ever
/// renders past tense again, the copy has regressed.
@JeebPreview(
  group: 'client_offers',
  name: 'Idle · named Jeeber',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetIdle() =>
    _offerAcceptSheetHosted(_offerAcceptSheetOffer());

/// The accept POST is in flight — the B-01 accept-exactly-ONE lock, made
/// visible.
///
/// While `isSubmitting` the sheet is deliberately non-dismissible
/// (`PopScope(canPop: false)` plus `enableDrag: false` on the route) and both
/// CTAs go inert, because the hole this closed was a user bailing mid-POST and
/// going back to accept a SECOND offer.
///
/// Two things this rendering shows that no assertion in the test file does.
///
/// **The spinner is the ONLY in-flight signal, and it is silent.** `text:` is
/// set to `chatOfferAccepting` ("Accepting…" / "جاري القبول…") while submitting,
/// but `OmdsLoadingButton` renders `OmdsButtonLoading` *instead of* `text`
/// whenever `isLoading` — so that string is translated in both ARBs and never
/// appears on screen. The surrounding `Semantics` keeps `label:
/// l10n.chatOfferAccept` unconditionally and the child is `ExcludeSemantics`, so
/// a screen reader announces a plain "Accept Offer" button that does nothing:
/// the B-01 lock is visible but not audible.
///
/// **The swap must not resize the button.** It is animated, so a height change
/// across label→spinner reads as a jump. The indicator itself is `onPrimary`
/// over `primary` dimmed to 60% — 3.26:1 dark / 4.70:1 light, i.e. it clears
/// WCAG 1.4.11's 3:1 non-text floor but not by much in dark.
@JeebPreview(
  group: 'client_offers',
  name: 'Submitting · B-01 lock',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetSubmitting() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(),
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.submitting,
      ),
    );

/// sprint-009 scenario #7: the accept race the customer actually loses.
///
/// Another accept closed the auction first, so the gateway answers 409
/// `request_not_open`. The pre-fix sheet only listened for success — the spinner
/// simply stopped and nothing was said — which is the single worst outcome on a
/// surface whose whole job is comprehension. The inline banner is the fix, and
/// the CTAs stay live underneath it: Confirm is retryable, Cancel returns to the
/// review list, which reloads and shows the closed banner.
@JeebPreview(
  group: 'client_offers',
  name: 'Failed · request closed (409)',
  size: _offerAcceptSheetErrorBox,
)
Widget offerAcceptSheetFailedRequestClosed() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(),
      failure: OffersFailure.requestNotOpen,
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.requestNotOpen,
      ),
    );

/// BR-10 `too-many-active-deliveries`, and the longest error copy the sheet can
/// show.
///
/// This is the distinct-copy half of fix/offer-accept-409-mislabel: the winning
/// Jeeber is already at their concurrent-delivery cap, so the OFFER is still
/// pending upstream and the sheet must NOT say "this offer is no longer
/// available". It says "…Choose another offer." instead — 75 characters set next
/// to a fixed-size [Icon] in a plain [Row], and the longest string this widget
/// can be asked to lay out.
///
/// **This state is where the 200%-text rendering breaks, and the break is real.**
/// The sheet measures 468 pt at 1.0 and 924 pt at 2.0; on an 844 pt phone that
/// is `A RenderFlex overflowed by 160 pixels on the bottom` (80 in AR, whose
/// copy is shorter), and on a 320×568 phone it is 516 pixels. The [Column] has
/// no scroll fallback and `showModalBottomSheet` does not add one, so what is
/// clipped is the bottom of the stack — **both CTAs**. A customer at large text
/// who loses the accept race is shown an error they can neither retry nor
/// dismiss.
@JeebPreview(
  group: 'client_offers',
  name: 'Failed · Jeeber at capacity',
  size: _offerAcceptSheetErrorBox,
)
Widget offerAcceptSheetFailedAtCapacity() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(),
      failure: OffersFailure.jeeberAtCapacity,
      initialState: const OfferAcceptState(
        status: OfferAcceptStatus.failed,
        error: OffersFailure.jeeberAtCapacity,
      ),
    );

/// W6/SW-08 regression guard: a phone-only Jeeber has no real name, only a
/// synthetic handle (`jeeb-<hash>`).
///
/// The title runs it through `displayNameOrNull` and falls back to
/// `offersCardJeeberFallback` — "New Jeeber" / "جِيبر جديد". If this preview ever
/// renders "Accept jeeb-e1a35ea8a520's offer?", the suppression has broken on
/// the one screen where the customer is being asked to trust a stranger with
/// their money.
@JeebPreview(
  group: 'client_offers',
  name: 'Synthetic handle suppressed',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetSyntheticHandle() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(jeeberName: 'jeeb-e1a35ea8a520'),
    );

/// The content ceiling: the longest plausible name against the longest plausible
/// fee.
///
/// A six-figure LBP quote is not hypothetical — LBP is a live currency here and
/// `MoneyFormat` groups it as `LBP 4,500,000.00`, which is 17 characters set in
/// `headlineSmall` and bold. Paired with a name that wraps the title, this is
/// where the sheet is widest and tallest at once: 384 pt at 1.0 text, and
/// **836 pt at 200%** — eight pixels short of an 844 pt phone, with no error
/// banner shown. That is the margin the state above spends.
///
/// The AR RTL rendering is the load-bearing one: the fee carries a U+2066 LTR
/// isolate precisely so the amount does not reorder under RTL, and a long Latin
/// name inside an Arabic question sentence is the classic bidi-reorder case.
@JeebPreview(
  group: 'client_offers',
  name: 'Long name · LBP fee',
  size: _offerAcceptSheetErrorBox,
)
Widget offerAcceptSheetLongContent() => _offerAcceptSheetHosted(
      _offerAcceptSheetOffer(
        jeeberName: 'Abdulrahman Al-Muhandis Al-Trabulsi',
        fee: 4500000,
        currency: 'LBP',
      ),
    );
