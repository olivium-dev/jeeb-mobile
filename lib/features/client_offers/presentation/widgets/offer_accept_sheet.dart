import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/formatting/friendly_reference.dart';
import '../../../../core/formatting/money_format.dart';
import '../../../../core/theme/jeeb_scrim.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      barrierColor: JeebScrim.barrier(context),
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
    final semantics = theme.extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
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
                        style: context.jeebText.titleProminent.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    Semantics(
                      identifier: 'offer_accept_price_label',
                      child: Text(
                        l10n.offersCardFee(feeFormatted, offer.currency),
                        textAlign: TextAlign.center,
                        // Money is white w800, the same rung `offer_card`
                        // draws — the orange is spent on the act, not the fact.
                        style: context.jeebText.price.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.small),
                    Semantics(
                      identifier: 'offer_accept_other_offers_note',
                      child: Text(
                        l10n.chatOfferAcceptOnlyOne,
                        textAlign: TextAlign.center,
                        style: context.jeebText.body.copyWith(
                          color: semantics.mutedText,
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
                      // The accent fill is board-legitimate here: this sheet
                      // exists only to perform the one orange act.
                      child: ExcludeSemantics(
                        child: JeebCtaButton.accent(
                          key: const Key('offer-accept-confirm-cta'),
                          label: state.isSubmitting
                              ? l10n.chatOfferAccepting
                              : l10n.chatOfferAccept,
                          isLoading: state.isSubmitting,
                          onTap: () =>
                              context.read<OfferAcceptCubit>().confirm(),
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
                        child: JeebCtaButton(
                          key: const Key('offer-accept-cancel-cta'),
                          label: l10n.actionCancel,
                          variant: JeebCtaVariant.outline,
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
    // Inert chrome takes the .22 glass rung, never the accent — the shared
    // grabber decision (settings sign-out sheet, confirm-delivery sheet).
    final semantics = Theme.of(context).extension<JeebSemanticColors>() ??
        JeebSemanticColors.midnight();
    return Center(
      child: Container(
        width: Spacing.twoXLarge,
        height: Spacing.twoXSmall,
        decoration: BoxDecoration(
          color: semantics.glassBorderVivid,
          borderRadius: OmdsBorderRadius.pill,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

// Widget previews for [OfferAcceptSheet] — run with

/// Phone width, with room for the idle stack (drag handle → title → fee → D71
/// note → two 48 pt CTAs), measured at 328 pt.
const Size _offerAcceptSheetBox = Size(390, 400);

/// The same stack plus the inline error banner — 408 pt for the one-line
/// request-closed copy, 468 pt for the three-line BR-10 capacity copy.
const Size _offerAcceptSheetErrorBox = Size(390, 500);

/// A repository with no transport at all.
/// The sheet resolves its repository as "the explicit one, else the
/// DI-registered `OffersRepository`, else a `FakeOffersRepository`". Passing
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
      submittedAt: DateTime(2026, 6, 18, 9, 12),
    );

/// Mounts the sheet the way `showModalBottomSheet` presents it — bottom-anchored
/// content on the surface colour — without needing a [Navigator] to push onto.
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
        onConfirmed: (OfferAcceptResult _) {},
        onCancelled: () {},
      ),
    );

/// The default reading: a real Jeeber name, a small USD fee, nothing in flight.
/// The title must be a **question** — "Accept Kamal Hajj's offer?" — and it is
@JeebPreview(
  group: 'client_offers',
  name: 'Idle · named Jeeber',
  size: _offerAcceptSheetBox,
)
Widget offerAcceptSheetIdle() =>
    _offerAcceptSheetHosted(_offerAcceptSheetOffer());

/// The accept POST is in flight — the B-01 accept-exactly-ONE lock, made
/// visible.
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
/// Another accept closed the auction first, so the gateway answers 409
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
