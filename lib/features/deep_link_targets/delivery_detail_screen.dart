import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/router/root_aware_back_scope.dart';
import '../../l10n/app_localizations.dart';

/// Client order-detail action hub (B-P0).
///
/// Single destination reached from the order list
/// (`order_history_screen.dart` → `context.push('/orders/:id')`) AND from
/// delivery push notifications. It exposes every per-order action so the
/// otherwise-orphaned child routes are reachable:
///   - `/orders/:id/tracking`  — live tracking
///   - `chat-detail` (named)   — order conversation
///   - `/orders/:id/otp`       — handover OTP confirmation
///   - `/orders/:id/cancel`    — destructive cancellation
///   - `/orders/:id/feedback`  — post-delivery rating (canonical surface)
///   - `/orders/:id/escalate`  — report an issue
///
/// Status-gating note: this hub has no delivery-status cubit yet, so all
/// CTAs render unconditionally. Each target defends its own empty/invalid
/// state, so this is acceptable until a status cubit is wired (future
/// ticket). Rating is standardized on `/feedback` (RatingScreen); the frozen
/// `/orders/:id/rate` (JEB-137) and the blind `/orders/:id/mutual-rate`
/// routes are intentionally NOT linked here (mutual-rate orphaned-by-design,
/// to be reconciled with /feedback in a product follow-up).
class DeliveryDetailScreen extends StatefulWidget {
  const DeliveryDetailScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<DeliveryDetailScreen> createState() => _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends State<DeliveryDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // BACK-nav defect fix: reached in-app via `context.push('/orders/:id')` (has
    // a parent) BUT also as the stack ROOT from a delivery push-notification /
    // deep link (`GoRouter.go('/orders/:id')`). The root-aware scope pops to the
    // parent when there is one and otherwise lands on Home instead of exiting.
    return RootAwareBackScope(
      fallbackLocation: '/',
      child: Scaffold(
        appBar: OMDSAppBar(
          title: l10n.deliveryDetailsTitle,
          showBackButton: true,
        ),
        body: ListView(
          key: const Key('delivery-detail-list'),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
          children: _buildChildren(context, l10n),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(BuildContext context, AppLocalizations l10n) {
    return [
      const SizedBox(height: Spacing.medium),
      for (final action in _actions(l10n, widget.deliveryId))
        _ActionRow(action: action),
      const SizedBox(height: Spacing.medium),
      _CancelButton(deliveryId: widget.deliveryId),
    ];
  }

  List<_DeliveryAction> _actions(AppLocalizations l10n, String id) {
    return [
      _DeliveryAction(
        semanticsId: 'order-detail-track',
        title: l10n.trackingTitle,
        leadingIcon: Icons.location_on_outlined,
        onTap: (c) => c.push('/orders/$id/tracking'),
      ),
      _DeliveryAction(
        semanticsId: 'order-detail-chat',
        title: l10n.deliveryActionContact,
        leadingIcon: Icons.chat_bubble_outline,
        onTap: (c) =>
            c.pushNamed('chat-detail', pathParameters: {'id': id}),
      ),
      _DeliveryAction(
        semanticsId: 'order-detail-otp',
        title: l10n.otpVerifyButton,
        leadingIcon: Icons.lock_outline,
        onTap: (c) => c.push('/orders/$id/otp'),
      ),
      _DeliveryAction(
        semanticsId: 'order-detail-rate',
        title: l10n.ratingPromptTitle,
        leadingIcon: Icons.star_outline,
        onTap: (c) => c.push('/orders/$id/feedback'),
      ),
      _DeliveryAction(
        semanticsId: 'order-detail-escalate',
        title: l10n.escalateTitle,
        leadingIcon: Icons.report_problem_outlined,
        onTap: (c) => c.push('/orders/$id/escalate'),
      ),
    ];
  }
}

/// Declarative descriptor for one tappable order action.
class _DeliveryAction {
  const _DeliveryAction({
    required this.semanticsId,
    required this.title,
    required this.leadingIcon,
    required this.onTap,
  });

  final String semanticsId;
  final String title;
  final IconData leadingIcon;
  final void Function(BuildContext) onTap;
}

/// A single OMDS settings row wrapped with a QA-targetable Semantics id.
class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final _DeliveryAction action;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: action.semanticsId,
      button: true,
      child: OmdsSettingsRow(
        key: Key(action.semanticsId),
        title: action.title,
        leadingIcon: action.leadingIcon,
        onTap: () => action.onTap(context),
      ),
    );
  }
}

/// Destructive cancel action rendered as an outlined primary button to
/// visually separate it from the navigational rows above.
class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.deliveryId});

  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'order-detail-cancel',
      button: true,
      child: OmdsPrimaryButton(
        key: const Key('order-detail-cancel'),
        text: l10n.deliveryActionCancel,
        variant: OmdsButtonVariant.outlined,
        onTap: () => context.push('/orders/$deliveryId/cancel'),
      ),
    );
  }
}
