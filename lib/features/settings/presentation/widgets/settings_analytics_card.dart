import 'dart:async';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/analytics/clarity/application/clarity_controller.dart';
import '../../../../core/analytics/clarity/data/microsoft_clarity_adapter.dart';
import '../../../../core/analytics/clarity/domain/clarity_consent.dart';
import '../../../../core/analytics/clarity/domain/clarity_consent_store.dart';
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_list_row.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_section_label.dart';
import '../../../../l10n/app_localizations.dart';
import 'notification_toggle_track.dart';

class SettingsAnalyticsCard extends StatefulWidget {
  const SettingsAnalyticsCard({super.key, required this.controller});

  static const String sectionIdentifier = 'settings_analytics_section';
  static const String toggleIdentifier = 'settings_analytics_toggle';
  static const String dialogIdentifier = 'settings_analytics_disclosure';

  final ClarityController controller;

  @override
  State<SettingsAnalyticsCard> createState() => _SettingsAnalyticsCardState();
}

class _SettingsAnalyticsCardState extends State<SettingsAnalyticsCard> {
  bool _dialogOpen = false;
  bool _mutationFailed = false;

  Future<void> _toggle() async {
    if (widget.controller.isGranted) {
      final succeeded = await widget.controller.revoke();
      if (mounted) setState(() => _mutationFailed = !succeeded);
      return;
    }
    if (_dialogOpen) return;
    _dialogOpen = true;
    final l10n = AppLocalizations.of(context);
    var canPop = false;
    final allowed = await Navigator.of(context).push<bool>(
      DialogRoute<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => PopScope(
            canPop: canPop,
            child: OmdsConfirmationDialog(
              identifier: SettingsAnalyticsCard.dialogIdentifier,
              title: l10n.clarityDisclosureTitle,
              content: l10n.clarityDisclosureBody,
              confirmText: l10n.clarityAllow,
              cancelText: l10n.clarityDontAllow,
              barrierDismissible: false,
              onConfirm: () => setDialogState(() => canPop = true),
              onCancel: () => setDialogState(() => canPop = true),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    _dialogOpen = false;
    final succeeded = allowed == true
        ? await widget.controller.grant()
        : await widget.controller.deny();
    if (mounted) setState(() => _mutationFailed = !succeeded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final selected = widget.controller.isGranted;
        return Semantics(
          identifier: SettingsAnalyticsCard.sectionIdentifier,
          container: true,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JeebSectionLabel(l10n.claritySettingsSection),
              const SizedBox(height: Spacing.xSmall),
              JeebOutlinedCard.grouped(
                children: [
                  Semantics(
                    identifier: SettingsAnalyticsCard.toggleIdentifier,
                    toggled: selected,
                    button: true,
                    container: true,
                    child: JeebListRow(
                      key: const Key('settings-row-analytics'),
                      title: l10n.claritySettingsTitle,
                      subtitle: _mutationFailed
                          ? l10n.clarityUpdateFailed
                          : l10n.claritySettingsSubtitle,
                      titleStyle: context.jeebText.body.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      padding: JeebOutlinedCard.defaultPadding,
                      trailing: NotificationToggleTrack(value: selected),
                      onTap: () => unawaited(_toggle()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for previews.

const Size _settingsAnalyticsCardPreviewSize = Size(390, 180);

final class _SettingsAnalyticsCardPreviewStore implements ClarityConsentStore {
  const _SettingsAnalyticsCardPreviewStore();

  @override
  Future<ClarityConsent> read() async => ClarityConsent.unknown;

  @override
  Future<bool> write(ClarityConsent consent) async => true;

  @override
  Future<bool> clear() async => true;
}

final class _SettingsAnalyticsCardPreview extends StatefulWidget {
  const _SettingsAnalyticsCardPreview();

  @override
  State<_SettingsAnalyticsCardPreview> createState() =>
      _SettingsAnalyticsCardPreviewState();
}

final class _SettingsAnalyticsCardPreviewState
    extends State<_SettingsAnalyticsCardPreview> {
  late final ClarityController _controller = ClarityController(
    available: false,
    consentStore: const _SettingsAnalyticsCardPreviewStore(),
    analytics: const MicrosoftClarityAdapter(projectId: 'preview-disabled'),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Spacing.medium),
    child: SettingsAnalyticsCard(controller: _controller),
  );
}

@JeebPreview(
  group: 'settings',
  name: 'Analytics · consent off',
  size: _settingsAnalyticsCardPreviewSize,
  matrix: true,
)
Widget settingsAnalyticsCardConsentOff() =>
    const _SettingsAnalyticsCardPreview();
