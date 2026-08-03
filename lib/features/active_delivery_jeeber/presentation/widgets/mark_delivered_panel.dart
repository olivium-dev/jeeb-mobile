import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_accent_frame_card.dart';
import '../../../../core/widgets/jeeb/jeeb_code_cells.dart';
import '../../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/active_delivery_cubit.dart';
import '../../domain/jeeber_delivery.dart';
import '../../domain/jeeber_delivery_status.dart';
import '../active_delivery_jeeber_l10n.dart';
import '../active_delivery_muted_ink.dart';
import 'handoff_tiles.dart';

/// Card radius — the board's `border-radius: 18` (`tpl 1066`). Both card
/// primitives take a radius; 18 is the value 18 and 24 share.
const double _kHandoffCardRadius = 18;

/// CTA height — the board's `height: 54` (`tpl 1083`). `JeebCtaButton`'s
/// primary default is 56; this screen's pill is two px shorter.
const double _kHandoffCtaHeight = 54;

/// The handoff panel shown while the delivery is being handed over (JM-051
/// AC1/AC2) — `18-active-delivery-jeeber.html` `tpl 1066-1083`.
///
/// One card, two frames: an outlined card at `InTransit`, and the accent-framed
/// card at `AtDoor`. Orange is spent here and nowhere else on this screen (R5)
/// — the frame is what says "this is the live step, do it now".
///
/// Surfaces:
///   - `mark_delivered_proof_photo` / `mark_delivered_note_field` — the two h86
///     evidence tiles (see [HandoffTiles]).
///   - `mark_delivered_cta` — P6/B1: it walks the forward ladder only as far as
///     `AtDoor` and then raises the door OTP. It does NOT drive
///     `AtDoor → Done` — the frozen SM opens that edge for `otp_verified` alone.
///   - `mark_delivered_otp_input` + `mark_delivered_otp_submit` — the door-code
///     block that replaces the CTA once [otpRequired].
///
/// The two phases now live inside the SAME card, which is how the board unifies
/// them without collapsing the two-phase gate `push_landing_test` pins.
///
/// The cash line is NOT here any more — it re-homed onto the drop-off card,
/// where the address it qualifies actually is.
///
/// Dumb widget: data in via constructor, events out via callbacks
/// (40_GUARDRAILS_ARCH §1 — no `sl`/`context.go` here).
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

  /// JEBV4-200: the just-captured proof-photo bytes, rendered from memory so the
  /// jeeber sees the actual image (the stamped `evidenceUrl` is an opaque CDN
  /// `object_ref` the gateway resolves later on the customer receipt).
  final Uint8List? proofPhotoBytes;
  final bool isMarking;
  final VoidCallback onCaptureProof;
  final ValueChanged<String> onNoteChanged;
  final VoidCallback onMarkDelivered;
  final AppLocalizations l10n;

  /// iter6 close-tail: the recipient OTP is required to complete `AtDoor → Done`.
  final bool otpRequired;

  /// True while a submitted door OTP is verifying.
  final bool isVerifyingOtp;

  /// Inline error under the door-OTP field (wrong code / locked / network).
  final String? otpError;

  /// Submits the typed recipient OTP. Non-null whenever [otpRequired] is wired.
  final ValueChanged<String>? onSubmitOtp;

  @override
  Widget build(BuildContext context) {
    final copy = ActiveDeliveryJeeberL10n.of(context);
    final atDoor = delivery.status == JeeberDeliveryStatus.atDoor;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(copy.handoffTitle, style: context.jeebText.cardTitle),
        // The board's `margin-top: 10` on the tile row.
        const SizedBox(height: Spacing.xSmall),
        HandoffTiles(
          delivery: delivery,
          proofPhotoStatus: proofPhotoStatus,
          proofPhotoBytes: proofPhotoBytes,
          onCaptureProof: onCaptureProof,
          onNoteChanged: onNoteChanged,
          l10n: l10n,
          copy: copy,
        ),
        const SizedBox(height: Spacing.small),
        // iter6 close-tail: when the gateway demands the recipient OTP, swap the
        // "Complete Delivery" CTA for the door-OTP entry that finishes the job.
        if (otpRequired)
          _DoorOtpEntry(
            isVerifying: isVerifyingOtp,
            errorText: otpError,
            onSubmit: onSubmitOtp,
            copy: copy,
          )
        else
          _MarkDeliveredCta(
            isMarking: isMarking,
            onTap: onMarkDelivered,
            l10n: l10n,
          ),
      ],
    );
    if (atDoor) {
      return JeebAccentFrameCard(
        radius: _kHandoffCardRadius,
        padding: const EdgeInsets.all(Spacing.medium),
        child: content,
      );
    }
    return JeebOutlinedCard(
      radius: _kHandoffCardRadius,
      padding: const EdgeInsets.all(Spacing.medium),
      child: content,
    );
  }
}

/// iter6 close-tail: the door-OTP entry surfaced when `AtDoor → Done` returns
/// `otp_required`. The recipient gives the jeeber the 4-digit code; the jeeber
/// types it and submits to complete the delivery to Done. The cells come from
/// `JeebCodeCells.input52`, which wraps `OmdsOtpInput` so the per-cell editable
/// ids `mark_delivered_otp_input_0..3` keep coming from OMDS (RC-7).
class _DoorOtpEntry extends StatefulWidget {
  const _DoorOtpEntry({
    required this.isVerifying,
    required this.errorText,
    required this.onSubmit,
    required this.copy,
  });

  final bool isVerifying;
  final String? errorText;
  final ValueChanged<String>? onSubmit;
  final ActiveDeliveryJeeberL10n copy;

  @override
  State<_DoorOtpEntry> createState() => _DoorOtpEntryState();
}

class _DoorOtpEntryState extends State<_DoorOtpEntry> {
  String _code = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedText = jeebMutedInk(context);
    final hasError = widget.errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // One prompt line replaces the old title + instruction pair: the card
        // heading already says what this card is for.
        Text(
          widget.copy.doorCodePrompt,
          style: context.jeebText.bodySmall.copyWith(color: mutedText),
        ),
        // The board's `margin-top: 9` on the cell row.
        const SizedBox(height: Spacing.xSmall),
        Semantics(
          identifier: 'mark_delivered_otp_input',
          container: true,
          child: JeebCodeCells.input52(
            key: const Key('markDelivered.otpInput'),
            cellIdentifier: 'mark_delivered_otp_input',
            hasError: hasError,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (_) => _submit(),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: Spacing.xSmall),
          Text(
            widget.errorText!,
            style: context.jeebText.caption.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        // The board's `margin-top: 14` above the pill.
        const SizedBox(height: Spacing.small),
        Semantics(
          identifier: 'mark_delivered_otp_submit',
          container: true,
          child: JeebCtaButton.primary(
            key: const Key('markDelivered.otpSubmit'),
            label: widget.copy.otpSubmit,
            isLoading: widget.isVerifying,
            isEnabled: _code.length == 4 && !widget.isVerifying,
            height: _kHandoffCtaHeight,
            onTap: _submit,
          ),
        ),
      ],
    );
  }

  void _submit() {
    final onSubmit = widget.onSubmit;
    if (onSubmit == null || widget.isVerifying) return;
    onSubmit(_code);
  }
}

/// `mark_delivered_cta` — the primary "Mark as delivered" CTA. The Semantics
/// node owns the tap + spinner state (same proven shape as the chat confirm
/// sheet's `confirm_delivery_confirm_button`).
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
        child: JeebCtaButton.primary(
          label: label,
          isLoading: isMarking,
          height: _kHandoffCtaHeight,
          onTap: onTap,
        ),
      ),
    );
  }
}
