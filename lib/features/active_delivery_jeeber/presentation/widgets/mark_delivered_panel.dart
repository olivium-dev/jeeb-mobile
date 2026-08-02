import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/active_delivery_cubit.dart';
import '../../domain/jeeber_delivery.dart';

import 'dart:convert';
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/jeeber_delivery_status.dart';

class MarkDeliveredPanel extends StatelessWidget {
  const MarkDeliveredPanel({
    super.key,
    required this.delivery,
    required this.proofPhotoStatus,
    required this.isMarking,
    required this.onCaptureProof,
    this.proofPhotoBytes,
    required this.onNoteChanged,
    required this.onMarkDelivered,
    required this.l10n,
    this.otpRequired = false,
    this.isVerifyingOtp = false,
    this.otpError,
    this.onSubmitOtp,
  });

  final JeeberDelivery delivery;
  final ProofPhotoStatus proofPhotoStatus;

  final Uint8List? proofPhotoBytes;
  final bool isMarking;
  final VoidCallback onCaptureProof;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onMarkDelivered;
  final AppLocalizations l10n;

  final bool otpRequired;

  final bool isVerifyingOtp;

  final String? otpError;

  final ValueChanged<String>? onSubmitOtp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.activeDeliveryStatusDone,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.medium),
        _ProofPhoto(
          delivery: delivery,
          status: proofPhotoStatus,
          bytes: proofPhotoBytes,
          onCapture: onCaptureProof,
          l10n: l10n,
        ),
        const SizedBox(height: Spacing.medium),
        _NoteField(onChanged: onNoteChanged, l10n: l10n),
        const SizedBox(height: Spacing.medium),
        _CashNote(delivery: delivery, l10n: l10n),
        const SizedBox(height: Spacing.large),
        if (otpRequired)
          _DoorOtpEntry(
            isVerifying: isVerifyingOtp,
            errorText: otpError,
            onSubmit: onSubmitOtp,
            l10n: l10n,
          )
        else
          _MarkDeliveredCta(
            isMarking: isMarking,
            onTap: onMarkDelivered,
            l10n: l10n,
          ),
      ],
    );
  }
}

class _DoorOtpEntry extends StatefulWidget {
  const _DoorOtpEntry({
    required this.isVerifying,
    required this.errorText,
    required this.onSubmit,
    required this.l10n,
  });

  final bool isVerifying;
  final String? errorText;
  final ValueChanged<String>? onSubmit;
  final AppLocalizations l10n;

  @override
  State<_DoorOtpEntry> createState() => _DoorOtpEntryState();
}

class _DoorOtpEntryState extends State<_DoorOtpEntry> {
  String _code = '';

  void _submit() {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null || widget.isVerifying) return;
    onSubmit(_code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.l10n.activeDeliveryOtpTitle,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.xSmall),
        Text(
          widget.l10n.activeDeliveryOtpInstruction,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.medium),
        Semantics(
          identifier: 'mark_delivered_otp_input',
          container: true,
          child: OmdsOtpInput(
            key: const Key('markDelivered.otpInput'),
            length: 4,
            identifier: 'mark_delivered_otp_input',
            hasError: hasError,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (_) => _submit(),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: Spacing.small),
          Text(
            widget.errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: Spacing.large),
        Semantics(
          identifier: 'mark_delivered_otp_submit',
          container: true,
          child: OmdsLoadingButton(
            key: const Key('markDelivered.otpSubmit'),
            text: widget.l10n.activeDeliveryOtpSubmit,
            isLoading: widget.isVerifying,
            isEnabled: _code.length == 4 && !widget.isVerifying,
            onTap: _submit,
          ),
        ),
      ],
    );
  }
}

class _ProofPhoto extends StatelessWidget {
  const _ProofPhoto({
    required this.delivery,
    required this.status,
    required this.bytes,
    required this.onCapture,
    required this.l10n,
  });

  final JeeberDelivery delivery;
  final ProofPhotoStatus status;

  final Uint8List? bytes;
  final VoidCallback onCapture;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploading = status == ProofPhotoStatus.uploading;
    final captured =
        status == ProofPhotoStatus.captured && delivery.hasProofPhoto;
    return Semantics(
      identifier: 'mark_delivered_proof_photo',
      button: true,
      image: true,
      label: l10n.receiptProofPhotoLabel,
      enabled: !uploading,
      onTap: uploading ? null : onCapture,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: uploading ? null : onCapture,
          child: ClipRRect(
            borderRadius: OmdsBorderRadius.medium,
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: captured
                  ? (bytes != null
                      ? Image.memory(
                          bytes!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : OmdsCachedImage(
                          url: delivery.proofPhotoUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ))
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: uploading
                          ? const OmdsLoadingState()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: Sizes.twoXLarge,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(height: Spacing.xSmall),
                                Text(
                                  l10n.escalatePhotoLabel,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  const _NoteField({required this.onChanged, required this.l10n});

  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'mark_delivered_note_field',
      child: OmdsTextField(
        labelText: l10n.offerSubmissionNoteLabel,
        hintText: l10n.offerSubmissionNoteHint,
        maxLines: 3,
        maxLength: 280,
        onChanged: onChanged,
      ),
    );
  }
}

class _CashNote extends StatelessWidget {
  const _CashNote({required this.delivery, required this.l10n});

  final JeeberDelivery delivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = delivery.amountText ?? '';
    final party = delivery.clientName ?? l10n.activeDeliveryDropOffLabel;
    return Semantics(
      identifier: 'mark_delivered_cash_note',
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: Row(
          children: [
            Icon(
              Icons.payments_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                l10n.receiptCashToJeeber(amount, party),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkDeliveredCta extends StatelessWidget {
  const _MarkDeliveredCta({
    required this.isMarking,
    required this.onTap,
    required this.l10n,
  });

  final bool isMarking;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final enabled = !isMarking;
    final label = l10n.activeDeliveryMarkDone;
    return Semantics(
      identifier: 'mark_delivered_cta',
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: OmdsLoadingButton(
          text: label,
          isLoading: isMarking,
          onTap: onTap,
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================

const double _markDeliveredPanelPhoneWidth = 390;

const Size _markDeliveredPanelBox = Size(_markDeliveredPanelPhoneWidth, 560);

const Size _markDeliveredPanelOtpBox = Size(_markDeliveredPanelPhoneWidth, 800);

final Uint8List _markDeliveredPanelProofBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAF0lEQVR42mO4bs2g'
  'bZUOIREsIMmAUwYAiXsO8RYSvosAAAAASUVORK5CYII=',
);

JeeberDelivery _markDeliveredPanelDelivery({
  String? clientName,
  String? amountText,
  String? proofPhotoUrl,
}) {
  return JeeberDelivery(
    id: 'delivery-golden',
    status: JeeberDeliveryStatus.atDoor,
    dropOff: const DropOffAddress(
      label: '12 Market Street',
      detail: 'Second floor',
      lat: 33.8938,
      lng: 35.5018,
    ),
    clientName: clientName,
    amountText: amountText,
    proofPhotoUrl: proofPhotoUrl,
  );
}

Widget _markDeliveredPanelHosted({
  required ProofPhotoStatus proofPhotoStatus,
  required JeeberDelivery delivery,
  Uint8List? proofPhotoBytes,
  bool isMarking = false,
  bool otpRequired = false,
  bool isVerifyingOtp = false,
  String? otpError,
}) {
  return TickerMode(
    enabled: false,
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _markDeliveredPanelPhoneWidth,
        child: ListView(
          padding: const EdgeInsets.all(Spacing.medium),
          children: <Widget>[
            Builder(
              builder: (BuildContext context) => MarkDeliveredPanel(
                delivery: delivery,
                proofPhotoStatus: proofPhotoStatus,
                proofPhotoBytes: proofPhotoBytes,
                isMarking: isMarking,
                onCaptureProof: () {},
                onNoteChanged: (_) {},
                onMarkDelivered: () {},
                otpRequired: otpRequired,
                isVerifyingOtp: isVerifyingOtp,
                otpError: otpError,
                onSubmitOtp: (_) {},
                l10n: AppLocalizations.of(context),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Awaiting proof · CTA armed',
  size: _markDeliveredPanelBox,
  matrix: true,
)
Widget markDeliveredPanelAwaitingProof() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.none,
      delivery: _markDeliveredPanelDelivery(
        clientName: 'Layla Haddad',
        amountText: '10.00 USD',
      ),
    );

@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Proof uploading · slot inert',
  size: _markDeliveredPanelBox,
)
Widget markDeliveredPanelUploadingProof() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.uploading,
      proofPhotoBytes: _markDeliveredPanelProofBytes,
      delivery: _markDeliveredPanelDelivery(
        clientName: 'Karim Mansour',
        amountText: '24.50 USD',
      ),
    );

@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Proof captured · thumbnail',
  size: _markDeliveredPanelBox,
)
Widget markDeliveredPanelProofCaptured() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.captured,
      proofPhotoBytes: _markDeliveredPanelProofBytes,
      delivery: _markDeliveredPanelDelivery(
        clientName: 'Rita Aoun',
        amountText: '7.00 USD',
        proofPhotoUrl: 'cdn://jeeb/evidence/delivery-golden.jpg',
      ),
    );

@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Upload failed · looks empty',
  size: _markDeliveredPanelBox,
)
Widget markDeliveredPanelUploadFailed() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.failed,
      proofPhotoBytes: _markDeliveredPanelProofBytes,
      delivery: _markDeliveredPanelDelivery(
        clientName: 'Georges Khoury',
        amountText: '18.00 USD',
      ),
    );

@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Cash details missing',
  size: _markDeliveredPanelBox,
)
Widget markDeliveredPanelCashDetailsMissing() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.none,
      delivery: _markDeliveredPanelDelivery(),
    );

@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Door OTP · wrong code',
  size: _markDeliveredPanelOtpBox,
  matrix: true,
)
Widget markDeliveredPanelDoorOtpWrongCode() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.captured,
      proofPhotoBytes: _markDeliveredPanelProofBytes,
      delivery: _markDeliveredPanelDelivery(
        clientName: 'Nour Abou Zeid',
        amountText: '32.00 USD',
        proofPhotoUrl: 'cdn://jeeb/evidence/delivery-golden.jpg',
      ),
      otpRequired: true,
      otpError: 'Incorrect code — ask the recipient and try again',
    );
