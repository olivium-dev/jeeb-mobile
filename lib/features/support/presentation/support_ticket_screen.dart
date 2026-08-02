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

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _supportTicketScreenPhoneBox = Size(390, 844);

/// The narrowest viewport the app supports.
const Size _supportTicketScreenCompactBox = Size(320, 568);

/// The caption each preview is pinned by.
/// Public because the render test's `expectedText` map is the reason they
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
/// No category, no details, no reference, no attachments — and a disabled
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
/// `payment` is filtered out of the list for anyone without the `jeeber` role,
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
/// The two extra options are "Earnings" (the `payment` category, wearing the
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
/// Every chip carries the plural counter rather than a name, so the row reads
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
/// The whole form is replaced by a centred spinner and one line, so the draft
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
/// `SupportCubit` holds the `ticketId` the repository returned;
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
/// "Your report will be retried automatically" — nothing queues, persists or
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
/// `_ErrorView._message` folds `unauthorized` in with `unknown`, so this card
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
/// Six categories with the longest label selected, a UUID-shaped order
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
/// The form scrolls, so a short device costs reach rather than layout — but the
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
