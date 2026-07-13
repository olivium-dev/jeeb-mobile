import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/role/role_availability_cubit.dart';
import '../../../l10n/app_localizations.dart';
import '../application/support_cubit.dart';
import '../application/support_state.dart';
import '../data/stub_support_repository.dart';
import '../domain/support_repository.dart';

/// support-ticket / contact-us (JM-063, D76).
///
/// The shared support surface reached from the customer-profile Contact-us row
/// (JM-035), account-status (JM-066), dispute-status (JM-065), and kyc-rejected
/// appeal (JM-043). Carries `support_category` + `support_body` +
/// `support_attach` + optional `support_order_link`; `support_submit_cta`
/// submits a ticket through the S1 support-service (POST /v1/support/tickets,
/// DI-bound `SupportRepository`), then shows a confirmation and routes to
/// customer-profile. `support_dispute_link` routes to dispute-open-evidence
/// (the existing `/orders/:id/escalate`, JM-060).
///
/// DI: the route builder is `const SupportTicketScreen()` (no constructor
/// injection — app_router is integrator-owned), so the screen resolves
/// `sl<SupportRepository>()` itself inside the BlocProvider (40_GUARDRAILS_ARCH
/// §5: the screen widget is the only layer allowed to touch `sl`). The DI
/// default is the INTEGRATOR-STUB until the S1 `/v1/support` rewrite key is
/// batched in; the screen is unchanged when DI is repointed to
/// `DioSupportRepository` (CTO-D2). If DI has not been configured (the
/// route-resolution nav-honesty pin builds the router with no GetIt setup), it
/// falls back to the in-memory [StubSupportRepository] so the route still
/// resolves to a rendered screen.
///
/// Semantics ids exposed (30_BACKLOG JM-063): `support_root`,
/// `support_category`, `support_body`, `support_attach`, `support_order_link`,
/// `support_submit_cta`, `support_dispute_link` + the D30 state ids
/// `support_submitting`, `support_success`, `support_error`,
/// `support_retry_cta`.
class SupportTicketScreen extends StatelessWidget {
  const SupportTicketScreen({super.key, this.cubit});

  /// DT-04 catalog / test seam: an already-constructed, already-driven cubit
  /// (e.g. one whose `submit()` has settled into `success`/`error` so the
  /// catalog can preview those phases). `null` (every production call site)
  /// preserves the existing behavior — the screen builds its own from the
  /// resolved [SupportRepository].
  final SupportCubit? cubit;

  @override
  Widget build(BuildContext context) {
    final providedCubit = cubit;
    if (providedCubit != null) {
      return BlocProvider<SupportCubit>.value(
        value: providedCubit,
        child: const _SupportTicketView(),
      );
    }
    // Optional inbound order/dispute ref via GoRouter `extra` (dispute-status
    // and the dispute link seed it); null for the profile/account-status
    // entries. Guarded so a host with no go_router `Page` ancestor (e.g. a
    // plain-Navigator catalog preview) never throws `GoError` here — it just
    // renders with no seeded ref, same as any other entry point.
    final route = ModalRoute.of(context);
    final extra =
        route != null && route.settings is Page<Object?>
            ? GoRouterState.of(context).extra
            : null;
    final initialOrderRef = extra is String && extra.trim().isNotEmpty
        ? extra.trim()
        : null;
    final sl = GetIt.instance;
    final repository = sl.isRegistered<SupportRepository>()
        ? sl<SupportRepository>()
        : const StubSupportRepository();
    return BlocProvider<SupportCubit>(
      create: (_) => SupportCubit(
        repository,
        initialOrderRef: initialOrderRef,
      ),
      child: const _SupportTicketView(),
    );
  }
}

class _SupportTicketView extends StatelessWidget {
  const _SupportTicketView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_root',
      container: true,
      child: Scaffold(
        appBar: OMDSAppBar(title: l10n.supportTitle, showBackButton: true),
        body: BlocBuilder<SupportCubit, SupportState>(
          builder: (context, state) {
            switch (state.phase) {
              case SupportPhase.inputting:
                return _SupportForm(state: state);
              case SupportPhase.submitting:
                return const _SubmittingView();
              case SupportPhase.success:
                return const _ConfirmationView();
              case SupportPhase.error:
                return _ErrorView(failure: state.failure);
            }
          },
        ),
      ),
    );
  }
}

class _SupportForm extends StatelessWidget {
  const _SupportForm({required this.state});
  final SupportState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Spacing.medium,
                Spacing.large,
                Spacing.medium,
                Spacing.large,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.supportBody, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: Spacing.large),
                  _CategoryField(selected: state.category),
                  const SizedBox(height: Spacing.large),
                  _BodyField(),
                  const SizedBox(height: Spacing.large),
                  _OrderLinkField(orderRef: state.orderRef),
                  const SizedBox(height: Spacing.large),
                  _AttachSection(paths: state.attachmentPaths),
                ],
              ),
            ),
          ),
          // Pinned bottom actions: the dispute link (D76 secondary edge) sits
          // above the submit CTA so both are always reachable (not buried at
          // the end of the scroll).
          _DisputeLink(orderRef: state.orderRef),
          _SubmitButton(canSubmit: state.canSubmit),
        ],
      ),
    );
  }
}

/// `support_category` — single-select category picker (OMDS bottom-sheet
/// selector). The S1 contract's category enum is
/// account/payment/delivery/kyc/dispute/other (D76).
class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.selected});
  final SupportCategory? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Inline single-select category picker (same shape as EscalateScreen's
    // reason picker — no modal, so it is reliably Maestro/widget-testable).
    // `support_category` is the container for the whole group; each option
    // carries its own `support_category_<name>` id.
    return Semantics(
      identifier: 'support_category',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // l10n KEY REQUEST (50_ROUTE_REQUESTS): `supportCategoryLabel` not in
          // the ARB yet — reuse the closest existing label. The identifier is
          // the contract, not the visible text.
          Text(
            l10n.customerProfileSectionSupport,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.xSmall),
          ..._visibleCategories(context).map(
            (c) => _CategoryTile(category: c, selected: c == selected),
          ),
        ],
      ),
    );
  }

  /// F6 / JEBV4-303 role-bleed: `payment` (rendered "Earnings") and `kycAppeal`
  /// (rendered "Appeal") are JEEBER-only support topics — a pure customer has no
  /// earnings and no KYC to appeal. Trim them for non-jeebers so a customer
  /// never sees jeeber-only categories. Gated on the jeeber CAPABILITY
  /// (`available_roles`, not the active role): a dual-role user IS a jeeber and
  /// may legitimately need to appeal their KYC even while browsing as a client,
  /// so they keep the full set. Nullable read keeps bare tests on the full set.
  List<SupportCategory> _visibleCategories(BuildContext context) {
    final roles = context.watch<RoleAvailabilityCubit?>()?.state.roles;
    final isJeeber = roles?.contains('jeeber') ?? false;
    if (isJeeber) return SupportCategory.values;
    return SupportCategory.values
        .where((c) =>
            c != SupportCategory.payment && c != SupportCategory.kycAppeal)
        .toList(growable: false);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.selected});
  final SupportCategory category;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'support_category_${category.name}',
      button: true,
      selected: selected,
      container: true,
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(_label(l10n, category)),
        onTap: () => context.read<SupportCubit>().setCategory(category),
      ),
    );
  }

  String _label(AppLocalizations l10n, SupportCategory c) {
    // l10n KEY REQUEST (50_ROUTE_REQUESTS): dedicated `supportCategory*` labels
    // are not in the ARB yet (integrator-owned). Reuse the closest existing
    // localized strings — Maestro asserts on `support_category*`, not the
    // visible label, so this is cosmetic.
    switch (c) {
      case SupportCategory.account:
        return l10n.customerProfileSectionSupport;
      case SupportCategory.payment:
        return l10n.navEarnings;
      case SupportCategory.delivery:
        return l10n.navDelivery;
      case SupportCategory.kycAppeal:
        return l10n.kycRejectedAppealCta;
      case SupportCategory.dispute:
        return l10n.disputeStatusSupportCta;
      case SupportCategory.other:
        return l10n.escalateReasonOther;
    }
  }
}

/// `support_body` — the free-text problem description (required, S1 rejects an
/// empty body with 400 → guarded by `canSubmit`).
class _BodyField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_body',
      textField: true,
      container: true,
      // l10n KEY REQUEST: `supportBodyLabel` not in ARB — reuse the escalate
      // free-text label (`support_body` identifier is the contract).
      child: OmdsTextField(
        labelText: l10n.escalateCommentLabel,
        maxLines: 5,
        minLines: 3,
        maxLength: 2000,
        onChanged: (v) => context.read<SupportCubit>().setBody(v),
      ),
    );
  }
}

/// `support_order_link` — optional order/delivery reference to attach to the
/// ticket. Pre-filled from the inbound `extra` (dispute-status entry) when set.
/// Stateful so its controller is created once (the parent rebuilds on every
/// keystroke via the BlocBuilder).
class _OrderLinkField extends StatefulWidget {
  const _OrderLinkField({required this.orderRef});
  final String? orderRef;

  @override
  State<_OrderLinkField> createState() => _OrderLinkFieldState();
}

class _OrderLinkFieldState extends State<_OrderLinkField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.orderRef ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_order_link',
      textField: true,
      container: true,
      // l10n KEY REQUEST: `supportOrderLinkLabel` not in ARB — reuse the orders
      // title as the field label (`support_order_link` identifier is the
      // contract).
      child: OmdsTextField(
        labelText: l10n.ordersTitle,
        controller: _controller,
        prefixIcon: const Icon(Icons.receipt_long_outlined),
        onChanged: (v) => context.read<SupportCubit>().setOrderRef(v),
      ),
    );
  }
}

/// `support_attach` — optional evidence attachments (≤5). The actual picker is
/// device-native; like EscalateScreen it records a placeholder path so the form
/// behaviour + cap are testable until image_picker is wired (follow-up).
class _AttachSection extends StatelessWidget {
  const _AttachSection({required this.paths});
  final List<String> paths;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // l10n KEY REQUEST: `supportAttachLabel`/`supportAttachItem` not in ARB
        // — reuse the escalate photo label + count copy.
        Text(l10n.escalatePhotoLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: Spacing.small),
        if (paths.isNotEmpty)
          Wrap(
            spacing: Spacing.xSmall,
            children: paths.indexed
                .map(
                  (e) => OmdsChip(
                    label: l10n.escalatePhotoAttached(e.$1 + 1),
                    isSelected: true,
                    onTap: () =>
                        context.read<SupportCubit>().removeAttachment(e.$2),
                  ),
                )
                .toList(),
          ),
        if (paths.length < 5) ...[
          const SizedBox(height: Spacing.small),
          Semantics(
            identifier: 'support_attach',
            button: true,
            container: true,
            // l10n KEY REQUEST: `supportAttachCta` not in ARB — reuse the photo
            // attachment add label (`support_attach` identifier is the contract).
            child: OmdsPrimaryButton(
              text: l10n.photoAttachmentAddLabel,
              variant: OmdsButtonVariant.outlined,
              icon: const Icon(Icons.attach_file),
              onTap: () => _pickAttachment(context),
            ),
          ),
        ],
      ],
    );
  }

  /// EXEMPT: image picker is device-native; in release this binds to the
  /// image_picker package (matches EscalateScreen's `_fakePickPhoto`). Records
  /// a deterministic placeholder path so the attach cap/flow is testable now.
  void _pickAttachment(BuildContext context) {
    context.read<SupportCubit>().addAttachment(
          'support_attach_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
  }
}

/// `support_dispute_link` → dispute-open-evidence (`/orders/:id/escalate`,
/// JM-060, D76). Seeds the order id from `support_order_link` when present.
class _DisputeLink extends StatelessWidget {
  const _DisputeLink({required this.orderRef});
  final String? orderRef;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final id = (orderRef == null || orderRef!.isEmpty) ? '_' : orderRef!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.large,
        Spacing.small,
        Spacing.large,
        0,
      ),
      child: Semantics(
        identifier: 'support_dispute_link',
        button: true,
        container: true,
        // Full-width tap target so the Semantics-node centre always hits the
        // button (Maestro/widget taps the node centre).
        child: TextButton.icon(
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(Sizes.fiveXLarge),
          ),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: Text(l10n.supportDisputeLink),
          onPressed: () => context.push('/orders/$id/escalate'),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.canSubmit});
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.large),
        child: Semantics(
          identifier: 'support_submit_cta',
          button: true,
          container: true,
          child: OmdsPrimaryButton(
            text: l10n.supportSubmitCta,
            isEnabled: canSubmit,
            onTap: () => context.read<SupportCubit>().submit(),
          ),
        ),
      ),
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_submitting',
      container: true,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmdsLoadingState(),
            const SizedBox(height: Spacing.medium),
            // l10n KEY REQUEST: `supportSubmitting` not in ARB — reuse escalate.
            Text(l10n.escalateSubmitting),
          ],
        ),
      ),
    );
  }
}

/// Confirmation state (D76: "submit → confirmation → customer-profile"). The
/// primary CTA routes to customer-profile, replacing the support route so back
/// does not return to the submitted form.
class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // JM-063 AC2 asserts `support_confirmation`; the legacy id is
    // `support_success` — nest both.
    return Semantics(
      identifier: 'support_confirmation',
      container: true,
      explicitChildNodes: true,
      child: Semantics(
      identifier: 'support_success',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.xLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: Sizes.sixXLarge,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: Spacing.large),
            // l10n KEY REQUEST: `supportConfirmation*` not in ARB — reuse the
            // escalate confirmation copy (same "we received it" semantics).
            Text(
              l10n.escalateConfirmationTitle,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.medium),
            Text(
              l10n.escalateConfirmationBody,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Spacing.xLarge),
            // JM-063 AC2 asserts `support_confirmation_back_cta`; the legacy id
            // is `support_success_done_cta` — nest both. Pop if possible (so an
            // entry pushed from the Profile tab returns to the shell Profile tab
            // where `customer_profile_wallet_chip` shows), else go to profile.
            Semantics(
              identifier: 'support_confirmation_back_cta',
              button: true,
              container: true,
              explicitChildNodes: true,
              child: Semantics(
                identifier: 'support_success_done_cta',
                button: true,
                container: true,
                child: OmdsPrimaryButton(
                  text: l10n.escalateConfirmationDone,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.goNamed('customer-profile'),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure});
  final SupportFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_error',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(Spacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Message + icon only (no built-in retry); the retry CTA is a
            // discrete, tightly-wrapped Semantics node below so Maestro can
            // target it precisely.
            OmdsErrorState(message: _message(l10n, failure)),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'support_retry_cta',
              button: true,
              container: true,
              // retryLabel: no dedicated `supportRetryCta` ARB key yet
              // (50_ROUTE_REQUESTS) — reuse the submit label for the action.
              child: OmdsPrimaryButton(
                text: l10n.supportSubmitCta,
                icon: const Icon(Icons.refresh),
                variant: OmdsButtonVariant.outlined,
                onTap: () => context.read<SupportCubit>().retryFromError(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _message(AppLocalizations l10n, SupportFailure? f) {
    // Reuse the escalate error copy until dedicated `supportError*` keys land
    // (50_ROUTE_REQUESTS l10n request). Maestro asserts on `support_error`.
    switch (f) {
      case SupportFailure.network:
        return l10n.escalateErrorNetwork;
      case SupportFailure.unauthorized:
      case SupportFailure.unknown:
      case null:
        return l10n.escalateErrorServer;
    }
  }
}
