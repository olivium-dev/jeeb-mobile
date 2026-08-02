import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../kyc/domain/kyc_gateway.dart';
import '../../kyc/domain/kyc_submission.dart';
import '../application/kyc_rejected_cubit.dart';
import '../application/kyc_rejected_state.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/kyc_rejected_screen_fixtures.dart';

/// Wiring (30_BACKLOG JM-043 · 42_GUARDRAILS_MOCK): the structured rejection
class KycRejectedScreen extends StatelessWidget {
  const KycRejectedScreen({super.key, this.gateway});

  final KycGateway? gateway;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<KycRejectedCubit>(
      create: (_) => KycRejectedCubit(gateway ?? _resolveGateway())..load(),
      child: const _KycRejectedView(),
    );
  }

  KycGateway _resolveGateway() {
    if (sl.isRegistered<KycGateway>()) return sl<KycGateway>();
    return FakeKycGateway();
  }
}

class _KycRejectedView extends StatelessWidget {
  const _KycRejectedView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_rejected_root',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.kycRejectedTitle,
          showBackButton: true,
          onBackPressed: () => context.canPop()
              ? context.pop()
              : context.goNamed('customer-profile'),
        ),
        body: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            Spacing.medium,
            Spacing.large,
            Spacing.medium,
            Spacing.xLarge,
          ),
          children: [
            Icon(Icons.error_outline_rounded,
                size: Sizes.sixXLarge, color: theme.colorScheme.error),
            const SizedBox(height: Spacing.large),
            Text(l10n.kycRejectedHeadline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: Spacing.small),
            Text(l10n.kycRejectedBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium),
            const _RejectionReasonSection(),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'kyc_rejected_appeal_cta',
              button: true,
              container: true,
              child: OmdsPrimaryButton(
                text: l10n.kycRejectedAppealCta,
                onTap: () => context.goNamed('support-ticket'),
              ),
            ),
            const SizedBox(height: Spacing.small),
            Semantics(
              identifier: 'kyc_rejected_back_cta',
              button: true,
              container: true,
              child: TextButton(
                onPressed: () => context.goNamed('customer-profile'),
                child: Text(l10n.kycRejectedBackCta),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _RejectionReasonSection extends StatelessWidget {
  const _RejectionReasonSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KycRejectedCubit, KycRejectedState>(
      builder: (context, state) {
        final reason = state.rejectionReason;
        if (reason == null) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: Spacing.large),
          child: _RejectionReasonNotice(reason: reason),
        );
      },
    );
  }
}

class _RejectionReasonNotice extends StatelessWidget {
  const _RejectionReasonNotice({required this.reason});

  final KycRejectionReason reason;

  String _label(AppLocalizations l10n) {
    switch (reason) {
      case KycRejectionReason.idUnreadable:
        return l10n.kycRejectionReasonIdUnreadable;
      case KycRejectionReason.selfieMismatch:
        return l10n.kycRejectionReasonSelfieMismatch;
      case KycRejectionReason.expired:
        return l10n.kycRejectionReasonExpired;
      case KycRejectionReason.other:
        return l10n.kycRejectionReasonOther;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'kyc_rejected_reason',
      container: true,
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                _label(l10n),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _kycRejectedScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _kycRejectedScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they exist
final class KycRejectedScreenCaptions {
  KycRejectedScreenCaptions._();

  /// Rejected with a structured cause: the ID photos could not be read.
  static const String idUnreadable = 'preview · reason · ID unreadable';

  /// Rejected with a structured cause: the selfie did not match.
  static const String selfieMismatch = 'preview · reason · selfie mismatch';

  /// Rejected with a structured cause: the document had expired.
  static const String expired = 'preview · reason · document expired';

  /// Rejected with the catch-all cause — the one that says "resubmit".
  static const String otherReason = 'preview · reason · other/generic';

  /// Rejected, no structured cause on the wire.
  static const String noStructuredReason =
      'preview · rejected · NO structured reason';

  /// `GET /v1/kyc/status` still in flight.
  static const String statusInFlight = 'preview · loading · status in flight';

  /// `GET /v1/kyc/status` threw.
  static const String statusReadFailed = 'preview · error · status read failed';

  /// A non-rejected status that still carried a reason.
  static const String resubmitRequested =
      'preview · resubmitRequested · reason dropped';

  /// The longest reason on the narrowest supported device.
  static const String compactLongest =
      'preview · longest reason · 320x568 viewport';
}

/// Mounts the real screen on one canned gateway, framed and captioned.
/// The `SizedBox` pins the device width the layout is designed against; height
Widget _kycRejectedScreenHosted(
  KycGateway gateway,
  String caption, {
  Size box = _kycRejectedScreenPhoneBox,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _KycRejectedScreenCaption(caption: caption),
      Expanded(
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: _KycRejectedScreenHost(gateway: gateway),
          ),
        ),
      ),
    ],
  );
}

/// The dev-chrome line painted above each device frame.
class _KycRejectedScreenCaption extends StatelessWidget {
  const _KycRejectedScreenCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // Dev chrome: LTR and unscaled, so the AR card still reads it as one
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The two destinations this screen has, stubbed.
/// The real targets are `support-ticket` (JM-063, `/support`, D76) and
/// `customer-profile`; here they only have to exist so a tap lands somewhere and
class _KycRejectedScreenStandIn extends StatelessWidget {
  const _KycRejectedScreenStandIn(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('preview stand-in')),
      body: Center(
        child: Text(
          // Forced LTR: diagnostic, not shipped copy, and a latin route name
          label,
          textDirection: TextDirection.ltr,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [KycRejectedScreen] so its three exits work.
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt on every frame would drop the navigation state.
class _KycRejectedScreenHost extends StatefulWidget {
  const _KycRejectedScreenHost({required this.gateway});

  final KycGateway gateway;

  @override
  State<_KycRejectedScreenHost> createState() => _KycRejectedScreenHostState();
}

class _KycRejectedScreenHostState extends State<_KycRejectedScreenHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/kyc/rejected',
    routes: <RouteBase>[
      GoRoute(
        path: '/kyc/rejected',
        name: 'kyc-rejected',
        builder: (_, _) => KycRejectedScreen(gateway: widget.gateway),
      ),
      GoRoute(
        path: '/support',
        name: 'support-ticket',
        builder: (_, _) =>
            const _KycRejectedScreenStandIn('support-ticket (JM-063)'),
      ),
      GoRoute(
        path: '/customer-profile',
        name: 'customer-profile',
        builder: (_, _) =>
            const _KycRejectedScreenStandIn('customer-profile (JM-043 exit)'),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);
}

/// The reference reading: the catalog's `Reason — ID unreadable`.
/// The only state where every element of the surface is present at once — the
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · ID unreadable',
  size: _kycRejectedScreenPhoneBox,
  matrix: true,
)
Widget kycRejectedScreenIdUnreadable() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.idUnreadable(),
      KycRejectedScreenCaptions.idUnreadable,
    );

/// The catalog's `Reason — selfie mismatch`.
/// Read the notice copy, not the layout: "Retake the selfie in better lighting."
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · selfie mismatch',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenSelfieMismatch() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.selfieMismatch(),
      KycRejectedScreenCaptions.selfieMismatch,
    );

/// The catalog's `Reason — document expired`.
/// The shortest of the four causes, and the other instruction the user cannot
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · document expired',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenExpired() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.expired(),
      KycRejectedScreenCaptions.expired,
    );

/// The catalog's `Reason — other/generic`, and the D52 finding made visible.
/// `kycRejectionReasonOther` reads "Please review your details and resubmit." on
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Reason · other/generic',
  size: _kycRejectedScreenPhoneBox,
  matrix: true,
)
Widget kycRejectedScreenOtherReason() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.other(),
      KycRejectedScreenCaptions.otherReason,
    );

/// Rejected, with NO structured cause — the closest thing this screen has to an
/// empty state.
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Rejected · no structured reason',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenNoStructuredReason() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.rejectedWithoutReason(),
      KycRejectedScreenCaptions.noStructuredReason,
    );

/// Cold entry, held open by a status read that never lands.
/// `KycRejectedCubit.load()` emits `loading` from the screen's `BlocProvider`
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Loading · status in flight',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenStatusInFlight() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.pending(),
      KycRejectedScreenCaptions.statusInFlight,
    );

/// `GET /v1/kyc/status` threw — the cubit's `error` branch.
/// `KycRejectedCubit` catches everything and emits `KycRejectedStatus.error`,
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Error · status read failed',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenStatusReadFailed() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.failing(),
      KycRejectedScreenCaptions.statusReadFailed,
    );

/// A `resubmitRequested` submission, reason and all, rendered as FINAL.
/// The tri-state third path (E19/Q-040/SM-6) is ACTIONABLE — the jeeber re-opens
@JeebPreview(
  group: 'kyc_rejected',
  name: 'resubmitRequested · reason dropped',
  size: _kycRejectedScreenPhoneBox,
)
Widget kycRejectedScreenResubmitRequested() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.resubmitRequestedWithReason(),
      KycRejectedScreenCaptions.resubmitRequested,
    );

/// The layout ceiling: the longest reason on the narrowest supported device.
/// There is no free server text on this screen — the cause is a closed enum, so
@JeebPreview(
  group: 'kyc_rejected',
  name: 'Longest reason · compact viewport',
  size: _kycRejectedScreenCompactBox,
)
Widget kycRejectedScreenCompactLongest() => _kycRejectedScreenHosted(
      KycRejectedScreenFixtures.idUnreadable(),
      KycRejectedScreenCaptions.compactLongest,
      box: _kycRejectedScreenCompactBox,
    );
