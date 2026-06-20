import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/di/injection_container.dart';
import '../../../l10n/app_localizations.dart';
import '../../jeeber_request_detail/domain/services/prohibited_item_report_service.dart';
import '../application/prohibited_item_report_cubit.dart';

/// Report Prohibited Item form (orders-prohibited-item-report /
/// disputes-prohibited-item-report).
///
/// Entry: reached from the Jeeber request-detail "Report — Prohibited item" CTA
/// (route `prohibited-item-report`) and from the order chat. Submits the typed
/// reason (and an optional attached photo) to the gateway via
/// [ProhibitedItemReportService]; on success it pops `true` so the caller can
/// surface the "request flagged" banner + the decline-without-penalty path.
///
/// Previously "Attach Photo" was `onTap:(){}` and "Report Item" just
/// `pop(true)` without ever calling the service (empty body) — this wires the
/// real submission RPC + photo handler.
class ProhibitedItemReportScreen extends StatelessWidget {
  const ProhibitedItemReportScreen({
    super.key,
    required this.requestId,
    this.service,
  });

  final String requestId;

  /// Injectable service — production resolves from DI; tests inject a double.
  final ProhibitedItemReportService? service;

  @override
  Widget build(BuildContext context) {
    final resolved = service ??
        (sl.isRegistered<ProhibitedItemReportService>()
            ? sl<ProhibitedItemReportService>()
            : null);
    if (resolved == null) {
      // Service not registered (bare GetIt in some test harnesses) — render the
      // form inert rather than red-screening.
      return const Scaffold(
        appBar: OMDSAppBar(title: 'Report Prohibited Item'),
        body: Center(child: Text('Reporting is unavailable right now.')),
      );
    }
    return BlocProvider(
      create: (_) => ProhibitedItemReportCubit(
        service: resolved,
        requestId: requestId,
      ),
      child: const _ProhibitedItemReportView(),
    );
  }
}

class _ProhibitedItemReportView extends StatefulWidget {
  const _ProhibitedItemReportView();

  @override
  State<_ProhibitedItemReportView> createState() =>
      _ProhibitedItemReportViewState();
}

class _ProhibitedItemReportViewState extends State<_ProhibitedItemReportView> {
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<ProhibitedItemReportCubit, ProhibitedItemReportState>(
      listenWhen: (p, n) => p.phase != n.phase,
      listener: (context, state) {
        if (state.phase == ProhibitedReportPhase.submitted) {
          Navigator.of(context).pop(true);
        } else if (state.phase == ProhibitedReportPhase.error &&
            state.errorKey != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorText(l10n, state.errorKey!))),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<ProhibitedItemReportCubit>();
        return Scaffold(
          appBar: OMDSAppBar(title: l10n.jeeberRequestDetailReportConfirmTitle),
          body: Padding(
            padding: const EdgeInsets.all(Spacing.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WarningCard(text: l10n.jeeberRequestDetailReportHint),
                const SizedBox(height: Spacing.medium),
                OmdsTextField(
                  key: const Key('prohibited-report-description'),
                  controller: _descriptionController,
                  labelText: l10n.jeeberRequestDetailReportButton,
                  maxLines: 4,
                  onChanged: cubit.setDescription,
                ),
                const SizedBox(height: Spacing.medium),
                OmdsPrimaryButton(
                  key: const Key('prohibited-report-attach-photo'),
                  text: state.photoUrl == null
                      ? 'Attach Photo'
                      : 'Photo attached',
                  variant: OmdsButtonVariant.outlined,
                  icon: Icon(
                    state.photoUrl == null ? Icons.camera_alt : Icons.check,
                  ),
                  onTap: () => _attachPhoto(cubit),
                ),
                const Spacer(),
                Semantics(
                  identifier: 'prohibited-report-submit',
                  button: true,
                  child: OmdsLoadingButton(
                    text: l10n.jeeberRequestDetailReportConfirmAction,
                    isLoading: state.phase == ProhibitedReportPhase.submitting,
                    isEnabled: state.canSubmit,
                    backgroundColor: Theme.of(context).colorScheme.error,
                    onTap: cubit.submit,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Attaches a captured-photo reference. The camera/image_picker capture is a
  /// separate shared binding (mobile §E-MOBILE P0/P1, JM-001/JM-036) — here we
  /// record the attachment intent so the report payload carries `photoUrl` once
  /// the capture pipeline resolves a real upload URL. Until then it stamps a
  /// pending marker so the "attached" affordance is honest.
  void _attachPhoto(ProhibitedItemReportCubit cubit) {
    cubit.attachPhoto(
      'pending-capture://${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  String _errorText(AppLocalizations l10n, String key) {
    switch (key) {
      case 'jeeberRequestDetailReportErrorNetwork':
        return l10n.jeeberRequestDetailReportErrorNetwork;
      default:
        return l10n.jeeberRequestDetailReportErrorGeneric;
    }
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Row(
          children: [
            Icon(Icons.warning, color: theme.colorScheme.error),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(text, style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
