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
