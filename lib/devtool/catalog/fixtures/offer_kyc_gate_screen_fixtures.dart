// Shared dev-only fixtures for `OfferKycGateScreen` (JM-044, D38/D67).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/kyc/domain/kyc_contract_template.dart';
import '../../../features/kyc/domain/kyc_form_schema.dart';
import '../../../features/kyc/domain/kyc_gateway.dart';
import '../../../features/kyc/domain/kyc_submission.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Base for the canned [KycGateway]s below.
/// `OfferKycGateCubit` calls exactly one method — [fetchStatus] — so the other
/// four are wired to throw rather than to return plausible-looking data: if a
abstract class OfferKycGateScreenGateway implements KycGateway {
  const OfferKycGateScreenGateway();

  Never _unused(String method) => throw UnsupportedError(
        'OfferKycGateScreen never calls KycGateway.$method — see '
        'lib/devtool/catalog/fixtures/offer_kyc_gate_screen_fixtures.dart',
      );

  @override
  Future<KycFormSchema> fetchFormSchema({String variant = 'national_id'}) =>
      _unused('fetchFormSchema');

  @override
  Future<KycContractTemplate> fetchContractTemplate() =>
      _unused('fetchContractTemplate');

  @override
  Future<KycSignStamp> signContract({
    required String templateId,
    required String tosVersion,
    required String signatureBlob,
  }) =>
      _unused('signContract');

  @override
  Future<KycSubmission> submit(KycSubmission draft) => _unused('submit');
}

/// `GET /v1/kyc/status` resolves to a submission carrying [status].
/// Drives `OfferKycGatePhase.ready` — the only phase in which
/// `_GateStatusLine` renders anything, and then only for `pending`,
class OfferKycGateScreenFakeGateway extends OfferKycGateScreenGateway {
  const OfferKycGateScreenFakeGateway({this.status = KycStatus.notSubmitted});

  /// The live decision the gate reads back.
  final KycStatus status;

  @override
  Future<KycSubmission> fetchStatus() async => KycSubmission(status: status);
}

/// A read that never lands, holding the cubit on `OfferKycGatePhase.loading`
/// for as long as the surface is open.
/// The cubit emits `loading` from its constructor and leaves it only when the
class OfferKycGateScreenPendingGateway extends OfferKycGateScreenGateway {
  const OfferKycGateScreenPendingGateway();

  @override
  Future<KycSubmission> fetchStatus() => Completer<KycSubmission>().future;
}

/// The status read fails, driving `OfferKycGatePhase.error`.
/// `OfferKycGateCubit.loadStatus` catches EVERYTHING (`catch (_)`) and degrades
/// to "no status line", so the shape of this throw is deliberately not a typed
class OfferKycGateScreenFailingGateway extends OfferKycGateScreenGateway {
  const OfferKycGateScreenFailingGateway();

  @override
  Future<KycSubmission> fetchStatus() async =>
      throw Exception('offer-kyc-gate preview: GET /v1/kyc/status failed');
}

// ─────────────────────────────────────────────────────────────────────────────

/// One simulated device window to render the screen in.
@immutable
class OfferKycGateScreenWindow {
  const OfferKycGateScreenWindow({
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  /// `jeebPreviewHost` wraps every preview in a `SafeArea`, which ZEROES
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  final double? textScale;
}

/// The named windows this screen is reviewed in.
final class OfferKycGateScreenWindows {
  OfferKycGateScreenWindows._();

  /// The reference reading: an ordinary modern phone.
  static const OfferKycGateScreenWindow phone =
      OfferKycGateScreenWindow(size: Size(390, 844));

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class), at the accessibility ceiling. A 64 pt icon, a two-line
  static const OfferKycGateScreenWindow compactLargeText =
      OfferKycGateScreenWindow(size: Size(320, 568), textScale: 2);
}

/// Where `gate_back_cta` and the app-bar arrow land: the DELIVERY tab feed.
/// Public so the render tests can pin WHICH exit was taken. The gate is entered
const String offerKycGateScreenFeedStandInLabel =
    'jeeber_feed_root · preview stand-in';

/// Where `gate_start_kyc_cta` lands: the KYC wizard (`kyc-status`).
const String offerKycGateScreenKycStandInLabel =
    'kyc_wizard_root · preview stand-in';

/// Where `gate_register_link` lands: the standalone register prompt (the W2
/// RD-1 fix — a pop-back would have re-resolved the DELIVERY tab and landed on
const String offerKycGateScreenRegisterStandInLabel =
    'delivery_register_prompt · preview stand-in';

/// A minimal, obviously-fake destination so a tap on one of the gate's three
/// exits lands somewhere legible instead of throwing or escaping into the real
/// app.
class OfferKycGateScreenStandIn extends StatelessWidget {
  const OfferKycGateScreenStandIn({required this.label, super.key});

  /// What this stand-in is playing — read by the render tests to tell the three
  /// exits apart.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: Center(
        child: Text(
          label,
          // Forced LTR: a diagnostic, not shipped copy, and a latin route name
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Hosts `OfferKycGateScreen` in one [OfferKycGateScreenWindow], with a real
/// `Router` above it so its three exits work.
/// The screen is INJECTED rather than constructed here, for two reasons: it
class OfferKycGateScreenPreviewHost extends StatefulWidget {
  const OfferKycGateScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.caption,
  });

  /// The screen under review — `OfferKycGateScreen(gateway: …)`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final OfferKycGateScreenWindow? window;

  /// Caption painted above the frame, and the string each preview is pinned by.
  /// Four of this screen's six states paint identical copy — `_GateStatusLine`
  final String? caption;

  @override
  State<OfferKycGateScreenPreviewHost> createState() =>
      _OfferKycGateScreenPreviewHostState();
}

class _OfferKycGateScreenPreviewHostState
    extends State<OfferKycGateScreenPreviewHost> {
  late final GoRouter _router = _buildRouter();

  /// The production stack: the gate is the LONE page.
  /// `jeeber_feed_tab_view` navigates with `goNamed('offer-kyc-gate')`, which
  GoRouter _buildRouter() => GoRouter(
        initialLocation: '/jeeber/offer-gate',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => const OfferKycGateScreenStandIn(
              label: offerKycGateScreenFeedStandInLabel,
            ),
          ),
          GoRoute(
            path: '/jeeber/offer-gate',
            name: 'offer-kyc-gate',
            builder: (_, _) => widget.screen,
          ),
          GoRoute(
            path: '/profile/kyc',
            name: 'kyc-status',
            builder: (_, _) => const OfferKycGateScreenStandIn(
              label: offerKycGateScreenKycStandInLabel,
            ),
          ),
          GoRoute(
            path: '/jeeber/register-prompt',
            name: 'delivery-register-prompt',
            builder: (_, _) => const OfferKycGateScreenStandIn(
              label: offerKycGateScreenRegisterStandInLabel,
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
    final Widget routed = Router.withConfig(config: _router);
    final OfferKycGateScreenWindow? window = widget.window;
    if (window == null) return routed;

    final ThemeData theme = Theme.of(context);
    final String? caption = widget.caption;
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (caption != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text(
              caption,
              // Forced LTR: a diagnostic label, not shipped copy.
              textDirection: TextDirection.ltr,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: routed),
          ),
        ),
      ],
    );

    // Unbound on both axes. The render tests pump onto 800 x 600 and the phone
    return Material(
      color: theme.colorScheme.surface,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: framed,
        ),
      ),
    );
  }
}
