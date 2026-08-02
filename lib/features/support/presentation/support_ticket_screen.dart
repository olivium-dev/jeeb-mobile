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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/support_ticket_screen_fixtures.dart';

class SupportTicketScreen extends StatelessWidget {
  const SupportTicketScreen({super.key, this.cubit});

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
          _DisputeLink(orderRef: state.orderRef),
          _SubmitButton(canSubmit: state.canSubmit),
        ],
      ),
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({required this.selected});
  final SupportCategory? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'support_category',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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

class _BodyField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'support_body',
      textField: true,
      container: true,
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
      child: OmdsTextField(
        labelText: l10n.ordersTitle,
        controller: _controller,
        prefixIcon: const Icon(Icons.receipt_long_outlined),
        onChanged: (v) => context.read<SupportCubit>().setOrderRef(v),
      ),
    );
  }
}

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
        Text(l10n.escalatePhotoLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: Spacing.small),
        if (paths.isNotEmpty)
          Wrap(
            spacing: Spacing.xSmall,
            children: paths.indexed
                .map(
                  (e) => Semantics(
                    identifier: 'support_attach_item_${e.$1}',
                    container: true,
                    button: true,
                    child: OmdsChip(
                      label: l10n.escalatePhotoAttached(e.$1 + 1),
                      isSelected: true,
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

  void _pickAttachment(BuildContext context) {
    context.read<SupportCubit>().addAttachment(
          'support_attach_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
  }
}

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
            Text(l10n.escalateSubmitting),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationView extends StatelessWidget {
  const _ConfirmationView();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
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
            OmdsErrorState(message: _message(l10n, failure)),
            const SizedBox(height: Spacing.large),
            Semantics(
              identifier: 'support_retry_cta',
              button: true,
              container: true,
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/support/support_ticket_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so five things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so each card shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes a background and the
//    `SafeArea`. That is the same nesting the Screen Catalog produces. The box
//    is therefore a real device ([_supportTicketScreenPhoneBox], 390x844, plus
//    the 320x568 [_supportTicketScreenCompactBox]) rather than the harness
//    default 390x200 — a scrolling form with a pinned two-row action bar cannot
//    be judged in a 200 pt strip. The width is pinned in the TREE as well as in
//    `size:`, so the render tests measure the same phone instead of the 800 pt
//    test surface.
//
// 2. Every card is frozen with `TickerMode(enabled: false)`. The submitting
//    state is an `OmdsLoadingState`, i.e. an indeterminate
//    `CircularProgressIndicator` that schedules frames forever, and
//    `pumpAndSettle` waits for frames to STOP being scheduled. Muting the
//    tickers paints a deterministic `t = 0` frame and lets the suite settle.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy — see
//    [SupportTicketScreenCaptions]. Six of these previews render byte-identical
//    copy: the form's own strings are fixed, the details a user "typed" never
//    reaches the field (finding 1 below), and the only thing that varies is
//    which radio is filled, what the order-reference field holds and how many
//    attachment chips there are. A suite that pinned screen copy would pass
//    with six previews wired to the same fixture. The render test's
//    `preview specifics` group then asserts the real state behind every
//    caption, so the caption is never the whole proof.
//
// 4. The states come from
//    `lib/devtool/catalog/fixtures/support_ticket_screen_fixtures.dart`, shared
//    with the Screen Catalog entry
//    (`devtool/catalog/entries/batch_11_entries.dart`), which used to own four
//    private fake repositories and build its cubits inline. Every preview
//    drives the shipped `cubit:` seam with a cubit built on a LOCAL fake, so
//    nothing here resolves `GetIt`, reads `GoRouterState.extra` or constructs a
//    Dio — these are network-free by construction rather than by the guard in
//    [jeebPreviewHost].
//
// 5. Two previews wrap the screen in a [RoleAvailabilityCubit], because
//    `_CategoryField._visibleCategories` shows six categories to a jeeber and
//    four to everyone else. Without the cubit the ambient read returns null and
//    the card shows the client's four — which is the right default for most of
//    these previews and the wrong one for the two that are about the other
//    branch.
//
// The one thing NOT reproduced is a router. `support_dispute_link` calls
// `context.push('/orders/<ref>/escalate')` and the confirmation's Done button
// calls `context.pop()`/`goNamed`, so both are inert here. They are still
// rendered, because whether they are OFFERED in a given state is most of what
// these cards are for.
//
// ## What these previews exposed in the screen
//
//  * **The details field cannot show the text the ticket will be submitted
//    with.** `_BodyField` builds an `OmdsTextField` with an `onChanged` and no
//    `controller` — and `OmdsTextField` has no `initialValue`, it passes
//    `controller` straight to `TextField` — so the widget owns an empty
//    internal controller that nothing can seed. `Form · ready to submit` is the
//    catalog's own designed state and it renders an EMPTY details box above a
//    live Submit button. The same gap eats real user input on the error path:
//    `retryFromError()` only flips the phase back to `inputting`, the
//    `BlocBuilder` swaps `_ErrorView` for a fresh `_SupportForm`, and the body
//    the user typed is gone from the screen while `SupportState.body` still
//    holds it. Submit stays enabled and re-sends text the user can no longer
//    see or correct. `_OrderLinkField` does NOT lose its value in the same
//    round trip — it is a `StatefulWidget` whose controller is seeded from
//    `state.orderRef` — so the two fields on one form behave differently.
//    Pinned by `Error · network` in the render test.
//  * **The one required field is labelled "(optional)".** `canSubmit` is
//    `category != null && body.trim().isNotEmpty`, so the ticket cannot be
//    submitted without a body — but `_BodyField` labels it with
//    `escalateCommentLabel`, "Additional details (optional)". Nothing else on
//    the form says what is missing, and the disabled Submit gives no reason.
//  * **A selected category can be invisible, and Submit stays enabled.**
//    `_CategoryField._visibleCategories` filters `payment` and `kycAppeal` out
//    for anyone without the `jeeber` role, while `SupportCubit` holds whatever
//    it was given. `Form · selected category is hidden` seeds `payment` on a
//    client — the catalog's own `Error — network failure` state does exactly
//    this — and the result is a form with no radio filled and a live CTA.
//  * **Four of the six category labels are borrowed from other screens.**
//    `_CategoryTile._label` maps `account` to `customerProfileSectionSupport`
//    ("Support" — the same string as the section heading directly above the
//    list), `payment` to `navEarnings` ("Earnings", a jeeber nav label),
//    `delivery` to `navDelivery` and `dispute` to `disputeStatusSupportCta`
//    ("Contact support" — the app-bar title of THIS screen). So a client sees
//    "Contact support" over a heading "Support" over an option "Support", and
//    picks between "Earnings" and "Delivery" to describe a problem. Visible on
//    every form card; asserted in the render test.
//  * **The order-reference field is labelled "Your Orders".**
//    `_OrderLinkField` uses `ordersTitle`, the order-HISTORY screen's title, as
//    the label for a single reference input. Nothing on the card says what to
//    type or where to find it.
//  * **Each attachment chip claims to be the whole count.**
//    `_AttachSection` labels chip `i` with `escalatePhotoAttached(i + 1)`,
//    which is the plural "{count} of 5 attached" — so five photos read
//    "1 of 5 attached", "2 of 5 attached" … "5 of 5 attached", side by side.
//    See `Form · attachments at the 5 cap`, where the "Add photo" button also
//    disappears silently: `if (paths.length < 5)` drops it with no "5 of 5"
//    message anywhere else on the form.
//  * **The confirmation never shows the ticket reference.**
//    `SupportCubit` stores `ticketId` from the created `SupportTicket` and
//    `_ConfirmationView` renders three fixed strings and a Done button — none
//    of them the id. The copy is the escalation flow's ("Report submitted",
//    "Our team will review your case"), so a support ticket confirms itself as
//    a report and gives the user nothing to quote back.
//  * **The error page's button says "Submit" and does not submit.**
//    `_ErrorView` labels its CTA `supportSubmitCta` — "Submit" — with a refresh
//    icon, and wires it to `retryFromError()`, which only returns to the form.
//    The draft is intact in the cubit and one call away; the button that looks
//    like it will retry the POST cannot.
//  * **A 401 is indistinguishable from "something went wrong".**
//    `_ErrorView._message` folds [SupportFailure.unauthorized] in with
//    `unknown` and `null`, so an expired session reads "Couldn't submit. Please
//    try again." — see `Error · session expired`, which is pixel-identical to
//    an unclassified failure. Nothing routes to a re-authentication.
//  * **The offline copy promises an automatic retry that does not exist.**
//    `escalateErrorNetwork` reads "No internet connection. Your report will be
//    retried automatically." Nothing in `SupportCubit` queues, persists or
//    re-sends the draft; the phase goes to `error` and stays there until the
//    user acts. Visible on `Error · network`.
//  * **"Open a dispute instead" routes to a literal underscore.**
//    `_DisputeLink` substitutes `'_'` when the order field is empty and pushes
//    `/orders/_/escalate`, so the most common case — a user who has not typed a
//    reference — deep-links the escalation flow to an order id that cannot
//    exist. The link is offered unconditionally on every form card.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _supportTicketScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _supportTicketScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 3 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
final class SupportTicketScreenCaptions {
  SupportTicketScreenCaptions._();

  /// A form nobody has touched.
  static const String formEmpty = 'preview · form · nothing selected';

  /// The catalog's ready state: seeded body, empty details box.
  static const String readyToSubmit =
      'preview · form · ready to submit, details box EMPTY';

  /// A category the client role cannot see, already selected.
  static const String hiddenCategory =
      'preview · form · selected category is hidden from this role';

  /// The jeeber reading: six categories instead of four.
  static const String jeeberCategories =
      'preview · form · jeeber · all six categories';

  /// Five photos on, "Add photo" gone.
  static const String attachmentsAtCap =
      'preview · form · attachments at the 5 cap';

  /// The POST is on the wire.
  static const String submitting = 'preview · submitting · POST in flight';

  /// The ticket was created, and its id is nowhere on screen.
  static const String success = 'preview · success · no ticket reference shown';

  /// Offline, with copy promising an automatic retry.
  static const String networkError = 'preview · error · network';

  /// A 401, folded into the generic error copy.
  static const String sessionExpired = 'preview · error · session expired';

  /// Every string at its longest plausible length.
  static const String longestContent = 'preview · longest content';

  /// The same content on the narrowest supported device.
  static const String compact =
      'preview · longest content · 320x568 viewport';
}

/// Mounts the real screen on one shared designed state, framed, captioned and
/// frozen.
///
/// `TickerMode(enabled: false)` mutes the indeterminate spinner — see note 2 in
/// the section prose. The `SizedBox` pins the device width the layout is
/// designed against; height is pinned too, but a render surface shorter than
/// [box] enforces its own, so only the width is exact in tests. The screen
/// keeps its own `Scaffold`; nothing here substitutes for it.
///
/// [roles] is the only thing added ABOVE the screen: `null` means "no
/// `RoleAvailabilityCubit` in scope", which is what the ambient read resolves to
/// for a client on the live shell, and a list installs an inert cubit seeded
/// with it — no repository, no sync.
Widget _supportTicketScreenHosted(
  SupportCubit cubit,
  String caption, {
  Size box = _supportTicketScreenPhoneBox,
  List<String>? roles,
}) {
  Widget screen = SupportTicketScreen(cubit: cubit);
  if (roles != null) {
    screen = BlocProvider<RoleAvailabilityCubit>(
      create: (_) => RoleAvailabilityCubit(RoleAvailability(roles: roles)),
      child: screen,
    );
  }
  return TickerMode(
    enabled: false,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SupportTicketScreenCaption(caption: caption),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: box.width,
              height: box.height,
              child: screen,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The dev-chrome line painted above each device frame.
class _SupportTicketScreenCaption extends StatelessWidget {
  const _SupportTicketScreenCaption({required this.caption});

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
        // latin line and the 200% card does not spend a third of the device on
        // a label.
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The EMPTY state: the form as it opens from `/support`.
///
/// No category, no details, no reference, no attachments — and a disabled
/// Submit that says nothing about which of the two required fields is missing.
/// The four client-visible categories are all here, including the one labelled
/// "Support" directly under a heading also reading "Support".
///
/// Matrixed because this is the whole chrome of the screen at once: a column of
/// `ListTile` radios, a five-line text area, a prefixed field and a pinned
/// two-row action bar. AR has to mirror the radios, the prefix icon and the
/// bottom bar together, and 200% is where the action bar and the scroll view
/// start competing for the last 200 pt of the device.
@JeebPreview(
  group: 'support',
  name: 'Form · empty',
  size: _supportTicketScreenPhoneBox,
  matrix: true,
)
Widget supportTicketScreenFormEmpty() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.emptyForm,
      SupportTicketScreenCaptions.formEmpty,
    );

/// The catalog's "Form — ready to submit": a category picked, a body typed,
/// `canSubmit == true`.
///
/// And the details box is EMPTY. `_BodyField` has no controller and
/// `OmdsTextField` has no `initialValue`, so the text this ticket will be
/// submitted with cannot be rendered — the live Submit button is the only
/// evidence on the card that a body exists at all.
@JeebPreview(
  group: 'support',
  name: 'Form · ready to submit',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenReadyToSubmit() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.readyToSubmit,
      SupportTicketScreenCaptions.readyToSubmit,
    );

/// A category the signed-in role is not allowed to see, already selected.
///
/// `payment` is filtered out of the list for anyone without the `jeeber` role,
/// so no radio is filled — yet the cubit holds it, `canSubmit` is true and
/// Submit is live. Reachable from a restored draft, from a deep link, and from
/// the Screen Catalog's own `Error — network failure` state, which seeds the
/// same category.
@JeebPreview(
  group: 'support',
  name: 'Form · selected category is hidden',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenHiddenCategory() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.hiddenCategory,
      SupportTicketScreenCaptions.hiddenCategory,
    );

/// The other branch of `_visibleCategories`: a jeeber sees all six.
///
/// The two extra options are "Earnings" (the `payment` category, wearing the
/// jeeber nav label) and "Appeal via support" (`kycAppeal`, the longest label
/// in the resolver and the one selected here).
@JeebPreview(
  group: 'support',
  name: 'Form · jeeber · six categories',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenJeeberCategories() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.jeeberAppeal,
      SupportTicketScreenCaptions.jeeberCategories,
      roles: const <String>['client', 'jeeber'],
    );

/// The attachment ceiling: five photos on.
///
/// Every chip carries the plural counter rather than a name, so the row reads
/// "1 of 5 attached" … "5 of 5 attached" — five different claims about the same
/// set. The "Add photo" button has silently disappeared, and nothing replaced
/// it to say the limit is the reason.
@JeebPreview(
  group: 'support',
  name: 'Form · attachments at the 5 cap',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenAttachmentsAtCap() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.attachmentsAtCap,
      SupportTicketScreenCaptions.attachmentsAtCap,
    );

/// The POST is on the wire and nothing has come back.
///
/// The whole form is replaced by a centred spinner and one line, so the draft
/// vanishes from the screen while it is being sent; the app bar's back button
/// stays live throughout, and leaving takes the ticket with it.
@JeebPreview(
  group: 'support',
  name: 'Submitting',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenSubmitting() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.submitting,
      SupportTicketScreenCaptions.submitting,
    );

/// The ticket was created — and the card cannot say which one.
///
/// `SupportCubit` holds the `ticketId` the repository returned;
/// `_ConfirmationView` renders the escalation flow's fixed copy ("Report
/// submitted") and a Done button, so the user leaves with nothing to quote in a
/// follow-up.
@JeebPreview(
  group: 'support',
  name: 'Success · confirmation',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenSuccess() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.success,
      SupportTicketScreenCaptions.success,
    );

/// The offline failure, with the copy that promises what nothing implements.
///
/// "Your report will be retried automatically" — nothing queues, persists or
/// re-sends the draft. The one affordance is a button labelled "Submit" that
/// calls `retryFromError()`, which returns to the form; the render test taps it
/// and pins what comes back: the order reference restored, the body gone, and
/// Submit still enabled over a details box the user can no longer read.
@JeebPreview(
  group: 'support',
  name: 'Error · network',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenNetworkError() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.networkError,
      SupportTicketScreenCaptions.networkError,
    );

/// A 401/403 — the session expired while the form was open.
///
/// `_ErrorView._message` folds `unauthorized` in with `unknown`, so this card
/// is pixel-identical to an unclassified failure: "Couldn't submit. Please try
/// again." over a button that cannot recover a session.
@JeebPreview(
  group: 'support',
  name: 'Error · session expired',
  size: _supportTicketScreenPhoneBox,
)
Widget supportTicketScreenSessionExpired() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.sessionExpired,
      SupportTicketScreenCaptions.sessionExpired,
    );

/// Every axis at its ceiling at once, on a jeeber account.
///
/// Six categories with the longest label selected, a UUID-shaped order
/// reference in a field labelled "Your Orders", five counter-labelled chips
/// wrapping onto two rows, and a 380-character body that — the point again —
/// does not reach a single pixel.
///
/// Matrixed because the EN-light reading stays plausible long after AR and 200%
/// have run out of room: the chips wrap to three rows in Arabic and the pinned
/// action bar takes half the device at 200%.
@JeebPreview(
  group: 'support',
  name: 'Longest content',
  size: _supportTicketScreenPhoneBox,
  matrix: true,
)
Widget supportTicketScreenLongestContent() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.longestContent,
      SupportTicketScreenCaptions.longestContent,
      roles: const <String>['client', 'jeeber'],
    );

/// The same ceiling on the narrowest viewport the app supports.
///
/// The form scrolls, so a short device costs reach rather than layout — but the
/// two-row action bar (`_DisputeLink` at 56 pt plus `_SubmitButton`) is pinned
/// outside the scroll view and takes a fixed bite out of 568 pt before the
/// first category is drawn.
@JeebPreview(
  group: 'support',
  name: 'Longest content · compact 320x568',
  size: _supportTicketScreenCompactBox,
)
Widget supportTicketScreenCompact() => _supportTicketScreenHosted(
      SupportTicketScreenPreviewFixtures.longestContent,
      SupportTicketScreenCaptions.compact,
      box: _supportTicketScreenCompactBox,
      roles: const <String>['client', 'jeeber'],
    );
