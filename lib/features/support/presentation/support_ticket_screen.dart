import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/role/role_availability_cubit.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../core/widgets/jeeb/jeeb_select_chip.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/support_cubit.dart';
import '../application/support_state.dart';
import '../data/stub_support_repository.dart';
import '../domain/support_repository.dart';

/// Token sheet §5: the 24 screen gutter, 16 above the first block. The docked
/// footer owns the bottom edge, so the scroll body only clears it.
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.large,
);

/// The empty-family subject for the two non-form phases. A submitted ticket is
/// a wait on a human reply, and `radar` is the ratified waiting composite.
const JeebEmptyStateVariant _kEmptyVariant = JeebEmptyStateVariant.radar;

/// E2's three ring discs are jeebers coming into range; no jeeber is involved
/// in a support ticket, and inventing three initials would be fabrication.
const List<JeebEmptyMedallion> _kNoMedallions = <JeebEmptyMedallion>[];

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
/// MIDNIGHT M3-30 — the board never drew this screen. Nearest tile is **R22
/// settings**: the only board tile that draws a stacked *labelled control form*
/// (uppercase periwinkle band headers over control groups, one lit frame, the
/// dim-red edge at the bottom), and it sits on the same customer-profile chain
/// this screen is reached from. The already-shipped R22 derivation for a field
/// stack — M3-26 password-security — is followed rather than re-derived:
/// `content` field with R22's single `topEnd` orange glow and NO periwinkle
/// wash, transparent scaffold, in-body [JeebTopBar], [JeebSectionLabel] + 8
/// over each group and 20 between bands, OMDS text fields left alone (the kit
/// has no input primitive). R22 is board-still, so `animateDecor: false`.
///
/// The three non-form phases take the empty family (see [_kEmptyVariant]),
/// which is how the sibling dispute form (M3-02 escalate) already discharges
/// them. Same flow, same copy, same identifiers, same navigation.
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
        backgroundColor: Colors.transparent,
        body: JeebMidnightField(
          variant: JeebFieldVariant.content,
          // R22's only radial (`480px 380px at 88% -6%`); it declares no
          // periwinkle wash, and nothing on that tile animates.
          glowPlacement: JeebFieldGlowPlacement.topEnd,
          animateDecor: false,
          child: SafeArea(
            child: Column(
              children: [
                // The header is an in-body row, not a Material app bar, so it
                // renders identically in every phase.
                JeebTopBar.back(
                  identifier: 'support_back',
                  title: l10n.supportTitle,
                ),
                Expanded(
                  child: BlocBuilder<SupportCubit, SupportState>(
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
              ],
            ),
          ),
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: _kBodyPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.supportBody,
                  // `onSurfaceVariant` IS the Midnight muted-ink role (#8A93D8).
                  style: context.jeebText.body.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.large),
                _CategoryField(selected: state.category),
                const SizedBox(height: Spacing.large),
                const _BodyField(),
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
        // the end of the scroll). Both live inside the kit's docked footer —
        // passed as one stack under `child:` rather than via `below:`, which
        // would swap the two and move the dispute edge under the CTA.
        JeebCtaFooter.single(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DisputeLink(orderRef: state.orderRef),
              const SizedBox(height: Spacing.small),
              _SubmitButton(canSubmit: state.canSubmit),
            ],
          ),
        ),
      ],
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
    // Inline single-select category picker (same shape as EscalateScreen's
    // reason picker — no modal, so it is reliably Maestro/widget-testable).
    // `support_category` is the container for the whole group; each option
    // carries its own `support_category_<name>` id.
    //
    // redesign-2026-08: the same options, the same single-select, rendered as
    // the board's pill group instead of a radio list — every option stays
    // visible (a Wrap, never a scroller that hides a pill from the finder).
    return Semantics(
      identifier: 'support_category',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // l10n KEY REQUEST (50_ROUTE_REQUESTS): `supportCategoryLabel` not in
          // the ARB yet — reuse the closest existing label. The identifier is
          // the contract, not the visible text.
          JeebSectionLabel(l10n.customerProfileSectionSupport),
          const SizedBox(height: Spacing.xSmall),
          Wrap(
            spacing: Spacing.xSmall,
            runSpacing: Spacing.xSmall,
            children: <Widget>[
              for (final c in _visibleCategories(context))
                _CategoryTile(category: c, selected: c == selected),
            ],
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
    return Semantics(
      identifier: 'support_category_${category.name}',
      button: true,
      selected: selected,
      container: true,
      // Selection is a fill swap (navy + white w700), never a leading radio:
      // the kit pill is the board's single-select mark. The chip adds no
      // Semantics node of its own, so the frozen id above stays the only one.
      child: JeebSelectChip(
        role: JeebChipRole.filter,
        label: _label(l10n, category),
        selected: selected,
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
  const _BodyField();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_body',
      textField: true,
      container: true,
      // l10n KEY REQUEST: `supportBodyLabel` not in ARB — reuse the escalate
      // free-text label (`support_body` identifier is the contract).
      //
      // The kit has no input primitive; OmdsTextField already reads the Wave-0
      // theme, so it stays — swapping it would be churn, not migration
      // (same call the redesigned profile-edit screen makes).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // l10n KEY REQUEST: `supportAttachLabel`/`supportAttachItem` not in ARB
        // — reuse the escalate photo label + count copy.
        JeebSectionLabel(l10n.escalatePhotoLabel),
        const SizedBox(height: Spacing.xSmall),
        if (paths.isNotEmpty)
          Wrap(
            spacing: Spacing.xSmall,
            runSpacing: Spacing.xSmall,
            children: paths.indexed
                .map(
                  (e) => Semantics(
                    // Positional id — the attachment path is a device-native
                    // placeholder with no stable backend id (precedent:
                    // diag_session_row_$index). Tap removes the attachment.
                    identifier: 'support_attach_item_${e.$1}',
                    container: true,
                    button: true,
                    child: JeebSelectChip(
                      role: JeebChipRole.inlineAction,
                      label: l10n.escalatePhotoAttached(e.$1 + 1),
                      selected: true,
                      onTap: () =>
                          context.read<SupportCubit>().removeAttachment(e.$2),
                    ),
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
            child: JeebCtaButton.outline(
              label: l10n.photoAttachmentAddLabel,
              leadingIcon: Icons.attach_file,
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
    return Semantics(
      identifier: 'support_dispute_link',
      button: true,
      container: true,
      // The secondary edge is a text affordance, not a second pill (the board
      // never stacks two filled CTAs). `expand` keeps the full-width tap target
      // so the Semantics-node centre always hits it (Maestro taps node centre);
      // the glyph is the filled variant (R10).
      child: JeebCtaButton.text(
        label: l10n.supportDisputeLink,
        leadingIcon: Icons.report,
        expand: true,
        onTap: () => context.push('/orders/$id/escalate'),
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
    return Semantics(
      identifier: 'support_submit_cta',
      button: true,
      container: true,
      child: JeebCtaButton(
        label: l10n.supportSubmitCta,
        isEnabled: canSubmit,
        onTap: () => context.read<SupportCubit>().submit(),
      ),
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // `support_submitting` re-homed onto the kit block; the OMDS spinner it
    // replaces defaulted to `colorScheme.primary`, i.e. orange under Midnight.
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: JeebEmptyStateStatus.loading,
          variant: _kEmptyVariant,
          medallions: _kNoMedallions,
          // l10n KEY REQUEST: `supportSubmitting` not in ARB — reuse escalate.
          headline: l10n.escalateSubmitting,
          identifier: 'support_submitting',
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
              // A settled outcome takes the §2 success role, never `primary` —
              // which IS #D73B00 under Midnight (R21's completed check).
              Icon(
                Icons.check_circle,
                size: Sizes.sixXLarge,
                color: context.jeebRoles.success,
              ),
              const SizedBox(height: Spacing.large),
              // l10n KEY REQUEST: `supportConfirmation*` not in ARB — reuse the
              // escalate confirmation copy (same "we received it" semantics).
              Text(
                l10n.escalateConfirmationTitle,
                style: context.jeebText.h1.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.escalateConfirmationBody,
                style: context.jeebText.body.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xLarge),
              // JM-063 AC2 asserts `support_confirmation_back_cta`; the legacy
              // id is `support_success_done_cta` — nest both. Pop if possible
              // (so an entry pushed from the Profile tab returns there), else
              // go to profile.
              Semantics(
                identifier: 'support_confirmation_back_cta',
                button: true,
                container: true,
                explicitChildNodes: true,
                child: Semantics(
                  identifier: 'support_success_done_cta',
                  button: true,
                  container: true,
                  // `expand: false` is inert under loose width (the kit centres
                  // inside its box); full width is what every sibling ships.
                  child: JeebCtaButton(
                    label: l10n.escalateConfirmationDone,
                    expand: false,
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
    // `support_error` re-homed onto the kit block, which draws the same
    // illustration danger-tinted; the OMDS error slab it replaces is gone.
    return Center(
      child: SingleChildScrollView(
        child: JeebEmptyState(
          status: JeebEmptyStateStatus.error,
          variant: _kEmptyVariant,
          medallions: _kNoMedallions,
          headline: _message(l10n, failure),
          identifier: 'support_error',
          action: Semantics(
            identifier: 'support_retry_cta',
            button: true,
            container: true,
            // retryLabel: no dedicated `supportRetryCta` ARB key yet
            // (50_ROUTE_REQUESTS) — reuse the submit label for the action.
            child: JeebCtaButton.outline(
              label: l10n.supportSubmitCta,
              leadingIcon: Icons.refresh,
              expand: false,
              onTap: () => context.read<SupportCubit>().retryFromError(),
            ),
          ),
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
