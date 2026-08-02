import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/formatting/money_format.dart';
import '../../../l10n/app_localizations.dart';
import '../application/delivery_receipt_cubit.dart';
import '../application/delivery_receipt_state.dart';
import '../data/dio_delivery_receipt_repository.dart';
import '../data/fake_delivery_receipt_repository.dart';
import '../domain/delivery_receipt.dart';
import '../domain/delivery_receipt_repository.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/delivery_receipt_screen_fixtures.dart';

class DeliveryReceiptScreen extends StatelessWidget {
  const DeliveryReceiptScreen({
    super.key,
    required this.deliveryId,
    this.repository,
  });

  final String deliveryId;

  final DeliveryReceiptRepository? repository;

  DeliveryReceiptRepository _resolveRepository() {
    final explicit = repository;
    if (explicit != null) return explicit;
    if (sl.isRegistered<DeliveryReceiptRepository>()) {
      return sl<DeliveryReceiptRepository>();
    }
    if (sl.isRegistered<Dio>()) {
      return DioDeliveryReceiptRepository(sl<Dio>());
    }
    return FakeDeliveryReceiptRepository();
  }

  @override
  Widget build(BuildContext context) {
    final repo = _resolveRepository();
    return BlocProvider<DeliveryReceiptCubit>(
      create: (_) => DeliveryReceiptCubit(
        repository: repo,
        deliveryId: deliveryId,
      )..load(),
      child: const _DeliveryReceiptView(),
    );
  }
}

class _DeliveryReceiptView extends StatelessWidget {
  const _DeliveryReceiptView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(
        title: l10n.receiptTitle,
        showBackButton: false,
        centerTitle: false,
      ),
      body: Semantics(
        identifier: 'receipt_prompt',
        explicitChildNodes: true,
        child: BlocConsumer<DeliveryReceiptCubit, DeliveryReceiptState>(
          listenWhen: (prev, next) =>
              prev.confirmStatus != next.confirmStatus &&
              next.confirmStatus == ReceiptConfirmStatus.succeeded,
          listener: (context, state) {
            final id = state.receipt?.deliveryId;
            if (id != null && id.isNotEmpty) {
              context.goNamed(
                'mutual-rating',
                pathParameters: <String, String>{'id': id},
              );
            }
          },
          builder: (context, state) {
            switch (state.status) {
              case DeliveryReceiptStatus.initial:
              case DeliveryReceiptStatus.loading:
                return const OmdsLoadingState();
              case DeliveryReceiptStatus.failed:
                return OmdsErrorState(
                  key: const Key('receipt-load-error'),
                  message: _errorCopy(l10n, state.error),
                  retryLabel: l10n.receiptRetryAction,
                  onRetry: () =>
                      context.read<DeliveryReceiptCubit>().refresh(),
                );
              case DeliveryReceiptStatus.loaded:
                final receipt = state.receipt;
                if (receipt == null) {
                  return OmdsErrorState(
                    message: _errorCopy(l10n, DeliveryReceiptFailure.unknown),
                    retryLabel: l10n.receiptRetryAction,
                    onRetry: () =>
                        context.read<DeliveryReceiptCubit>().refresh(),
                  );
                }
                return _LoadedBody(receipt: receipt, state: state);
            }
          },
        ),
      ),
    );
  }

  static String _errorCopy(
    AppLocalizations l10n,
    DeliveryReceiptFailure? failure,
  ) {
    switch (failure) {
      case DeliveryReceiptFailure.network:
        return l10n.receiptErrorNetwork;
      case DeliveryReceiptFailure.notFound:
        return l10n.receiptErrorNotFound;
      case DeliveryReceiptFailure.transitionNotAllowed:
        return l10n.receiptErrorTransition;
      case DeliveryReceiptFailure.unknown:
      case null:
        return l10n.receiptErrorGeneric;
    }
  }
}

class _LoadedBody extends StatelessWidget {
  const _LoadedBody({required this.receipt, required this.state});

  final DeliveryReceipt receipt;
  final DeliveryReceiptState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final confirming = state.isConfirming;
    final jeeberLabel = receipt.jeeberName.isNotEmpty
        ? receipt.jeeberName
        : l10n.receiptJeeberFallback;
    final cashText = receipt.hasKnownAmount
        ? l10n.receiptCashToJeeber(
            MoneyFormat.format(receipt.cashAmount!, currency: receipt.currency),
            jeeberLabel,
          )
        : l10n.receiptCashToJeeberNoAmount(jeeberLabel);

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.large,
        Spacing.medium,
        Spacing.xLarge,
      ),
      children: [
        Icon(
          Icons.local_shipping_outlined,
          size: Sizes.fiveXLarge,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: Spacing.medium),
        Text(
          l10n.receiptPromptHeading,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.large),
        Semantics(
          identifier: 'receipt_proof_photo',
          image: true,
          label: l10n.receiptProofPhotoLabel,
          child: ClipRRect(
            borderRadius: OmdsBorderRadius.medium,
            child: receipt.hasProofPhoto
                ? OmdsCachedImage(
                    url: receipt.proofPhotoUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: theme.colorScheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      size: Sizes.twoXLarge,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: Spacing.large),
        Semantics(
          identifier: 'receipt_cash_to_jeeber_label',
          child: Container(
            padding: const EdgeInsets.all(Spacing.medium),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: OmdsBorderRadius.medium,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: Spacing.small),
                Expanded(
                  child: Text(
                    cashText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (state.confirmStatus == ReceiptConfirmStatus.failed) ...[
          const SizedBox(height: Spacing.medium),
          Semantics(
            identifier: 'receipt_confirm_error',
            child: Text(
              _confirmErrorCopy(l10n, state.confirmError),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
        const SizedBox(height: Spacing.twoXLarge),
        Semantics(
          identifier: 'receipt_confirm_cta',
          container: true,
          button: true,
          enabled: !confirming,
          label: l10n.receiptConfirmCta,
          onTap: confirming
              ? null
              : () => context.read<DeliveryReceiptCubit>().confirmReceipt(),
          child: ExcludeSemantics(
            child: OmdsLoadingButton(
              key: const Key('receipt-confirm-cta'),
              text: l10n.receiptConfirmCta,
              isLoading: confirming,
              isEnabled: !confirming,
              onTap: () =>
                  context.read<DeliveryReceiptCubit>().confirmReceipt(),
            ),
          ),
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'receipt_not_yet_cta',
          container: true,
          button: true,
          enabled: !confirming,
          label: l10n.receiptNotYetCta,
          onTap: confirming ? null : () => _openDispute(context),
          child: ExcludeSemantics(
            child: OMDSOutlinedButton(
              key: const Key('receipt-not-yet-cta'),
              text: l10n.receiptNotYetCta,
              enabled: !confirming,
              onTap: () => _openDispute(context),
            ),
          ),
        ),
      ],
    );
  }

  void _openDispute(BuildContext context) {
    context.pushNamed(
      'escalate',
      pathParameters: <String, String>{'id': receipt.deliveryId},
    );
  }

  static String _confirmErrorCopy(
    AppLocalizations l10n,
    DeliveryReceiptFailure? failure,
  ) {
    switch (failure) {
      case DeliveryReceiptFailure.network:
        return l10n.receiptErrorNetwork;
      case DeliveryReceiptFailure.transitionNotAllowed:
        return l10n.receiptErrorTransition;
      case DeliveryReceiptFailure.notFound:
      case DeliveryReceiptFailure.unknown:
      case null:
        return l10n.receiptErrorGeneric;
    }
  }
}
// ============================== JEEB PREVIEWS ==============================
// ===========================================================================

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _deliveryReceiptScreenPhoneBox = Size(390, 844);

/// The caption each preview is pinned by.
final class DeliveryReceiptScreenCaptions {
  DeliveryReceiptScreenCaptions._();

  /// `$9.00` owed to Kamal Hajj, with the D3 proof photo.
  static const String loaded = 'preview · cash + proof photo';

  /// `GET /v1/deliveries/{id}` still in flight — the first frame of every
  /// receipt, and a state with no copy of its own at all.
  static const String loading = 'preview · fetch in flight';

  /// Run-22 P1-A: the gateway dropped `amount`.
  static const String amountUnknown = 'preview · amount absent from payload';

  /// Run-22 P1-A, the other half: the gateway sent `0`.
  static const String amountZero = 'preview · amount arrived as zero';

  /// No courier name on file.
  static const String noJeeberName = 'preview · jeeber name missing';

  /// The longest cash line the screen can produce.
  static const String longContent = 'preview · longest name + LBP amount';

  /// 404 — nothing to confirm, and no way off the screen.
  static const String notFound = 'preview · 404 dead end';

  /// The read never reached the server.
  static const String networkDown = 'preview · load failed, retryable';

  /// Loads fine; the confirm is rejected with a 422. Tap the CTA.
  static const String confirmRejected = 'preview · confirm will be rejected';
}

/// Stands in for the two surfaces this screen hands the customer off to:
class _DeliveryReceiptScreenEdgeStandIn extends StatelessWidget {
  const _DeliveryReceiptScreenEdgeStandIn({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: a diagnostic, not shipped copy.
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [DeliveryReceiptScreen] and captions the state.
class _DeliveryReceiptScreenHost extends StatefulWidget {
  const _DeliveryReceiptScreenHost({
    required this.createRepository,
    required this.caption,
  });

  /// Called once per mount, so each canvas card gets its own fake.
  final DeliveryReceiptRepository Function() createRepository;

  /// The line painted above the device frame — see note 4 in the prose.
  final String caption;

  @override
  State<_DeliveryReceiptScreenHost> createState() =>
      _DeliveryReceiptScreenHostState();
}

class _DeliveryReceiptScreenHostState
    extends State<_DeliveryReceiptScreenHost> {
  late final DeliveryReceiptRepository _repository = widget.createRepository();

  /// The three real routes this screen touches, at their real paths and names
  /// (`app_router.dart`): the prompt itself, the rating terminal the confirm
  late final GoRouter _router = GoRouter(
    initialLocation:
        '/orders/${DeliveryReceiptScreenFixtures.deliveryId}/receipt',
    routes: <RouteBase>[
      GoRoute(
        path: '/orders/:id/receipt',
        name: 'delivered-receipt',
        builder: (_, GoRouterState state) => DeliveryReceiptScreen(
          deliveryId: state.pathParameters['id'] ?? '',
          repository: _repository,
        ),
      ),
      GoRoute(
        path: '/orders/:id/mutual-rate',
        name: 'mutual-rating',
        builder: (_, _) => const _DeliveryReceiptScreenEdgeStandIn(
          label: 'mutual-rating · JM-034',
        ),
      ),
      GoRoute(
        path: '/orders/:id/escalate',
        name: 'escalate',
        builder: (_, _) => const _DeliveryReceiptScreenEdgeStandIn(
          label: 'dispute-open-evidence · JM-060',
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            widget.caption,
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(child: Router.withConfig(config: _router)),
      ],
    );
  }
}

Widget _deliveryReceiptScreenHosted(
  DeliveryReceiptRepository Function() createRepository,
  String caption,
) =>
    _DeliveryReceiptScreenHost(
      createRepository: createRepository,
      caption: caption,
    );

/// The happy path: `$9.00` owed to Kamal Hajj, with the proof-of-delivery photo
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Loaded · proof photo + 9.00 USD cash',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenLoaded() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.loaded,
      DeliveryReceiptScreenCaptions.loaded,
    );

/// `GET /v1/deliveries/{id}` still in flight — the first frame EVERY customer
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Loading · fetch in flight',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenLoading() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.pending,
      DeliveryReceiptScreenCaptions.loading,
    );

/// Run-22 P1-A regression guard, made visible: the live
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Amount unknown · gateway dropped it',
  size: _deliveryReceiptScreenPhoneBox,
  matrix: true,
)
Widget deliveryReceiptScreenAmountUnknown() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.amountUnknown,
      DeliveryReceiptScreenCaptions.amountUnknown,
    );

/// The other half of the same guard: the amount arrived as `0`.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Amount zero · never fabricate 0.00 USD',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenAmountZero() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.amountZero,
      DeliveryReceiptScreenCaptions.amountZero,
    );

/// No courier name on file: the copy falls back to the localized generic noun
@JeebPreview(
  group: 'delivery_receipt',
  name: 'No jeeber name · generic fallback',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenNoJeeberName() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.noJeeberName,
      DeliveryReceiptScreenCaptions.noJeeberName,
    );

/// The layout ceiling for the cash-on-delivery row: the longest plausible name
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Long jeeber name · LBP amount',
  size: _deliveryReceiptScreenPhoneBox,
  matrix: true,
)
Widget deliveryReceiptScreenLongContent() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.longContent,
      DeliveryReceiptScreenCaptions.longContent,
    );

/// 404 — the delivery id resolved no receipt, and this screen is a dead end.
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Error · 404 receipt not found',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenNotFound() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.notFound,
      DeliveryReceiptScreenCaptions.notFound,
    );

/// The read never reached the server — the retryable failure, and the one a
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Error · network, retry keeps failing',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenNetworkDown() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.networkDown,
      DeliveryReceiptScreenCaptions.networkDown,
    );

/// A receipt that loads perfectly and whose CONFIRM is rejected with the 422
@JeebPreview(
  group: 'delivery_receipt',
  name: 'Confirm rejected · 422 transition',
  size: _deliveryReceiptScreenPhoneBox,
)
Widget deliveryReceiptScreenConfirmRejected() => _deliveryReceiptScreenHosted(
      DeliveryReceiptScreenFixtures.confirmRejected,
      DeliveryReceiptScreenCaptions.confirmRejected,
    );
