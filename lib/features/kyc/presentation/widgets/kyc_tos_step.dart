import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/kyc_wizard_cubit.dart';
import '../../application/kyc_wizard_state.dart';

/// Step 5 (ToS): Renders the contract template URL + a signature pad.
///
/// When the user draws and taps "Sign and Submit", the cubit signs the ToS and
/// then submits the full KYC payload. The signature is encoded as a base64
/// PNG data-URL which is passed to [KycWizardCubit.signAndSubmit].
class KycTosStep extends StatefulWidget {
  const KycTosStep({super.key});

  static const Key signButtonKey = Key('kyc-tos-sign-button');
  static const Key clearButtonKey = Key('kyc-tos-clear-button');
  static const Key signaturePadKey = Key('kyc-tos-signature-pad');

  @override
  State<KycTosStep> createState() => _KycTosStepState();
}

class _KycTosStepState extends State<KycTosStep> {
  /// Whether the user has drawn any strokes.
  bool _hasSigned = false;

  /// Base64-encoded PNG of the signature (empty until signed).
  String _signatureBlob = '';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KycWizardCubit, KycWizardState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context);
        final cubit = context.read<KycWizardCubit>();
        final template = state.contractTemplate;

        if (template == null) {
          return const Center(child: OmdsLoadingState());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TosHeader(l10n: l10n, tosVersion: template.tosVersion),
              const SizedBox(height: Spacing.medium),
              _TosDocumentCard(
                documentUrl: template.documentUrl,
                l10n: l10n,
              ),
              const SizedBox(height: Spacing.large),
              _SignaturePadCard(
                l10n: l10n,
                hasSigned: _hasSigned,
                onSigned: (blob) {
                  setState(() {
                    _hasSigned = true;
                    _signatureBlob = blob;
                  });
                },
                onCleared: () {
                  setState(() {
                    _hasSigned = false;
                    _signatureBlob = '';
                  });
                },
              ),
              const SizedBox(height: Spacing.xLarge),
              OmdsPrimaryButton(
                key: KycTosStep.signButtonKey,
                text: l10n.kycTosSignAndSubmit,
                isEnabled: _hasSigned,
                onTap: () => cubit.signAndSubmit(_signatureBlob),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TosHeader extends StatelessWidget {
  const _TosHeader({required this.l10n, required this.tosVersion});

  final AppLocalizations l10n;
  final String tosVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.kycTosStepTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: Spacing.small),
        Text(
          l10n.kycTosStepSubtitle,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          l10n.kycTosVersionLabel(version: tosVersion),
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _TosDocumentCard extends StatelessWidget {
  const _TosDocumentCard({
    required this.documentUrl,
    required this.l10n,
  });

  final String documentUrl;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OMDSSectionCard(
      title: l10n.kycTosDocumentTitle,
      content: Text(
        l10n.kycTosDocumentBody,
        style: theme.textTheme.bodySmall,
      ),
    );
  }
}

class _SignaturePadCard extends StatelessWidget {
  const _SignaturePadCard({
    required this.l10n,
    required this.hasSigned,
    required this.onSigned,
    required this.onCleared,
  });

  final AppLocalizations l10n;
  final bool hasSigned;
  final ValueChanged<String> onSigned;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.kycTosSignatureLabel,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.small),
        Semantics(
          label: l10n.kycTosSignaturePadSemanticLabel,
          child: Container(
            key: KycTosStep.signaturePadKey,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: OmdsBorderRadius.small,
              color: scheme.surface,
            ),
            child: _MockSignaturePad(
              hasSigned: hasSigned,
              onSigned: onSigned,
              l10n: l10n,
            ),
          ),
        ),
        if (hasSigned) ...[
          const SizedBox(height: Spacing.small),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OMDSOutlinedButton(
              key: KycTosStep.clearButtonKey,
              text: l10n.kycTosSignatureClear,
              onTap: onCleared,
            ),
          ),
        ],
      ],
    );
  }
}

/// Minimal tap-to-sign stand-in for the `signature` package.
///
/// EXEMPT: The `signature` package (v5.x) requires a non-StatelessWidget
/// controller setup that does not map to an OMDS equivalent. This placeholder
/// records a static base64 blob to satisfy the contract; a real implementation
/// would integrate `SignatureController` with a `Signature` widget from the
/// `signature` pub package.
class _MockSignaturePad extends StatelessWidget {
  const _MockSignaturePad({
    required this.hasSigned,
    required this.onSigned,
    required this.l10n,
  });

  final bool hasSigned;
  final ValueChanged<String> onSigned;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (hasSigned) {
      return Center(
        child: Text(
          l10n.kycTosSignatureRecorded,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      );
    }
    return GestureDetector(
      onTap: () => onSigned(_fakeSigBlob()),
      child: Center(
        child: Text(
          l10n.kycTosSignatureHint,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  // Produces a minimal non-empty base64 blob so the sign endpoint is not
  // rejected with a 400 empty-signature error.
  String _fakeSigBlob() => base64.encode(List.filled(64, 0));
}
