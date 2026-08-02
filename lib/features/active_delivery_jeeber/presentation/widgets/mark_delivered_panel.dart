import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/active_delivery_cubit.dart';
import '../../domain/jeeber_delivery.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
// `Uint8List` already arrives with `dart:typed_data` above.
import 'dart:convert';
import '../../../../core/previews/jeeb_preview.dart';
import '../../domain/jeeber_delivery_status.dart';

/// The mark-delivered panel shown at `AtDoor` (JM-051 AC1/AC2).
///
/// Surfaces:
///   - `mark_delivered_proof_photo` — proof-of-delivery photo capture (D3).
///   - optional Jeeber note.
///   - `mark_delivered_cash_note` — "customer confirms receipt + pays cash" (D11).
///   - `mark_delivered_cta` — "Complete Delivery"; P6/B1: it walks the forward
///     ladder only as far as `AtDoor` and then raises the door OTP. It does
///     NOT drive `AtDoor → Done` — the frozen SM opens that edge for
///     `otp_verified` alone.
///
/// When [otpRequired] the panel swaps its "Complete Delivery" CTA for a
/// door-OTP entry (`mark_delivered_otp_input`) + `mark_delivered_otp_submit` —
/// the recipient gives the jeeber the code, the jeeber enters it, and the
/// delivery completes to Done via the verify path, which then chains to
/// `feedback-rate-delivery` (D56).
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
        // iter6 close-tail: when the gateway demands the recipient OTP, swap the
        // "Complete Delivery" CTA for the door-OTP entry that finishes the job.
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

/// iter6 close-tail: the door-OTP entry surfaced when `AtDoor → Done` returns
/// `otp_required`. The recipient gives the jeeber the 4-digit code; the jeeber
/// types it and submits to complete the delivery to Done. Mirrors the proven
/// `otp_handover_input` shape (per-cell editable ids) so a UI driver can fill
/// each cell.
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

/// `mark_delivered_proof_photo` — tap-to-capture proof photo (D3). Renders the
/// uploaded thumbnail once captured; otherwise a tappable dashed placeholder.
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

  /// The just-captured bytes (JEBV4-200) — preferred over the stamped
  /// `evidenceUrl` for the local thumbnail so the jeeber sees the real photo.
  final Uint8List? bytes;
  final VoidCallback onCapture;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploading = status == ProofPhotoStatus.uploading;
    final captured =
        status == ProofPhotoStatus.captured && delivery.hasProofPhoto;
    // JEBV4-200: the camera capture is wired to the cubit's real-bytes CDN
    // upload via [onCapture]; the captured frame renders from memory below.
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

/// Optional Jeeber note (JM-051 AC1).
class _NoteField extends StatelessWidget {
  const _NoteField({required this.onChanged, required this.l10n});

  final ValueChanged<String> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    // Identifier on a wrapping node so Maestro can locate the optional note;
    // the field owns its own editable semantics underneath.
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

/// `mark_delivered_cash_note` — "customer confirms receipt + pays cash" (D11).
class _CashNote extends StatelessWidget {
  const _CashNote({required this.delivery, required this.l10n});

  final JeeberDelivery delivery;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // D11 cash-on-delivery reminder. Localized via the shared
    // `receiptCashToJeeber` ("Pay {amount} cash to {jeeber}") getter — the
    // jeeber confirms the customer pays this cash on delivery. A dedicated
    // jeeber-framed key is requested in 50_ROUTE_REQUESTS.md (JM-051).
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
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/active_delivery_jeeber/mark_delivered_panel_preview_test.dart
// ===========================================================================
//
// [MarkDeliveredPanel] is the last thing a jeeber touches before the money
// changes hands, and it is a dumb widget by design (40_GUARDRAILS_ARCH §1):
// data in through the constructor, events out through callbacks. So every
// preview below is a pure function of a [JeeberDelivery] record, a
// [ProofPhotoStatus], three bools and a nullable error string — no cubit, no
// repository, no `sl`. Network-free by construction, not merely by the guard
// inside [jeebPreviewHost].
//
// **The axes that change the panel's shape.** Two, and they are independent:
//
//   * `proofPhotoStatus` — `none` / `uploading` / `captured` / `failed` decide
//     what the 180 dp photo slot paints. Note that `captured` is not enough on
//     its own: `_ProofPhoto` renders the thumbnail only when the status is
//     `captured` AND `delivery.hasProofPhoto`, so the stamped `evidenceUrl` is
//     part of that fixture.
//   * `otpRequired` — swaps the whole "Complete Delivery" CTA for the door-OTP
//     entry (iter6 close-tail). The photo, the note and the cash line stay put
//     above the swap; only the bottom of the panel changes.
//
// **Why the ticker is off.** [_markDeliveredPanelHosted] wraps every state in
// `TickerMode(enabled: false)`. The uploading state paints [OmdsLoadingState],
// an indeterminate `CircularProgressIndicator` that never stops scheduling
// frames, and the door-OTP entry autofocuses its first cell, which starts a
// blinking text cursor — `pumpAndSettle` in the render tests would hang on
// either. A still preview wants a still spinner and a still cursor anyway.
//
// **Every state carries its own delivery.** Different amount, different
// recipient. That is not decoration: `_CashNote` is the only line in this
// panel whose text varies per fixture, so it is the one string the render test
// can use to prove that a preview renders ITS OWN state rather than a copy of
// the state above it.
//
// **What these previews were written to make visible** (all pinned in the
// render test):
//
// 1. `failed` and `none` are the SAME picture. A proof-photo upload that died
//    on the gateway drops back to the identical tappable placeholder, with no
//    error text, no retry wording and no colour change — see
//    [markDeliveredPanelUploadFailed] next to [markDeliveredPanelAwaitingProof].
// 2. The photo slot borrows `escalatePhotoLabel` — "Photos (optional, up to
//    5)" — from the escalation flow, for a slot that takes exactly ONE photo.
//    The screen-reader name is right (`receiptProofPhotoLabel`, "Proof of
//    delivery photo"); only the visible copy is borrowed.
// 3. The cash line degrades badly when the gateway sends no `amount`:
//    `_CashNote` substitutes `''` and renders "Pay  cash to Drop-off address",
//    double space and all — [markDeliveredPanelCashDetailsMissing].
// 4. The door-OTP error is NOT localized. `otpError` arrives as a hardcoded
//    English string from `ActiveDeliveryCubit._mapOtpError`, so the AR RTL
//    rendering of [markDeliveredPanelDoorOtpWrongCode] shows an Arabic title
//    over an English error.
//
// Production placement is `active_delivery_jeeber_screen.dart` (`_ReadyView`):
// the panel is a direct child of a `ListView` padded `Spacing.medium` on every
// side, with no card around it. [_markDeliveredPanelHosted] rebuilds exactly
// that frame, so the canvas shows the 358 dp of content width the panel really
// gets on a 390 dp phone — and so a state that outgrows its box scrolls the way
// production scrolls instead of painting an overflow stripe.

/// Phone width the jeeber screen is laid out for.
const double _markDeliveredPanelPhoneWidth = 390;

/// The canvas box for the CTA states: phone width, and just enough height for
/// title + 180 dp photo slot + note field + cash line + button.
///
/// The panel measures 508 dp in both EN and AR, plus the list's 2x16 dp of
/// padding. Measured through the render test on the test fallback font, whose
/// glyphs are wider than the bundled Inter — so an upper bound, not a promise
/// about the shipped font.
const Size _markDeliveredPanelBox = Size(_markDeliveredPanelPhoneWidth, 560);

/// The canvas box for the door-OTP state, which trades a 48 dp button for a
/// title + instruction + 56 dp cell row + inline error + submit: 756 dp in EN,
/// 736 in AR, plus the same 32 dp of list padding.
///
/// Sized to fit that WITHOUT scrolling, on purpose. `_DoorOtpEntry` mounts
/// [OmdsOtpInput] with its default `autoFocus: true`, so the first cell takes
/// focus as soon as the entry appears and asks the enclosing scrollable to
/// reveal it. In a box too short for the panel that request becomes a driven
/// scroll animation, and `Scrollable` blocks every pointer and semantics action
/// under it for the duration — which, with the ticker muted (see the section
/// note), is forever. A card the reviewer cannot scroll or tap is a poor
/// preview, so the box is simply big enough that nothing has to move.
const Size _markDeliveredPanelOtpBox = Size(_markDeliveredPanelPhoneWidth, 800);

/// A real 4x4 two-tone PNG (80 bytes), so the captured branch decodes an actual
/// [Image.memory] in the canvas instead of Flutter's broken-image glyph. Kept
/// inline and tiny — a preview must never read a file or a network asset.
final Uint8List _markDeliveredPanelProofBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAF0lEQVR42mO4bs2g'
  'bZUOIREsIMmAUwYAiXsO8RYSvosAAAAASUVORK5CYII=',
);

/// One delivery parked at `AtDoor` — with `InTransit`, one of the only two
/// statuses from which `_ReadyView` mounts this panel at all.
///
/// The drop-off is the fixture
/// `test/features/active_delivery_jeeber/active_delivery_jeeber_golden_test.dart`
/// uses (12 Market Street, Beirut). The panel never renders it — the address is
/// `_AddressCard`'s job one section higher — but [JeeberDelivery] requires it,
/// so it may as well be the same row the golden test seeds.
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

/// Mounts the panel in the frame `_ReadyView` gives it: a phone-width box and
/// the delivering-phase `ListView` with its `Spacing.medium` padding.
///
/// 390 − 2×16 = 358 dp of content. The `ListView` is not a detail — it is what
/// keeps the 200% rendering of the matrix scrollable instead of overflowing,
/// which is also how the real screen behaves.
///
/// Every callback is inert. In production `onCaptureProof` opens the device
/// camera, `onMarkDelivered` walks the SM-1 forward ladder over the wire and
/// `onSubmitOtp` POSTs `/v1/deliveries/{id}/otp/verify`; tapping in the canvas
/// must do none of those.
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

/// The state a jeeber lands on the moment the delivery reaches `InTransit`:
/// nothing captured, nothing in flight, the CTA armed.
///
/// This is the panel's whole vocabulary in one card, which is why it carries
/// the matrix. Three things to read in it:
///
/// * the photo slot says "Photos (optional, up to 5)" — `escalatePhotoLabel`,
///   borrowed from the escalation flow for a slot that accepts exactly one
///   photo and is the evidence stamped on the final status patch;
/// * the cash line is a `Row` of icon + `Expanded` text, i.e. the one piece
///   here that has to mirror in Arabic — the icon belongs on the RIGHT of the
///   pill in the AR RTL reading, not the left;
/// * the CTA is an `OmdsLoadingButton`, which hard-codes `height: 48` around a
///   plain `Text`. At the 200% reading "Complete Delivery" wraps to two lines
///   inside a box that does not grow, and the second line is clipped — no
///   ellipsis, no overflow stripe, no exception.
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

/// The CDN upload is on the wire: `captureProofPhoto` has the compressed bytes
/// and is streaming them through the signed-PUT proxy.
///
/// The slot swaps to a bare spinner and — the part worth checking — goes inert:
/// `_ProofPhoto` drops both the `GestureDetector`'s `onTap` and the `Semantics`
/// tap action while `uploading`, so a jeeber cannot fire a second capture over
/// the one in flight. The bytes are already in state here (the cubit emits them
/// with the `uploading` status) and are deliberately NOT shown: the slot the
/// jeeber just filled goes blank for the duration of the upload rather than
/// showing their photo behind a spinner.
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

/// Proof on file: the upload returned an `object_ref`, the cubit stamped it as
/// the delivery's `evidenceUrl` and kept the captured bytes.
///
/// JEBV4-200 is the reason both halves of that fixture are here. `bytes` takes
/// precedence over `proofPhotoUrl` so the jeeber sees the actual frame they
/// shot; the `evidenceUrl` is an opaque CDN reference the gateway resolves
/// later on the customer's receipt, and rendering it here would put a network
/// fetch inside a preview. Drop either half of the fixture and the slot falls
/// silently back to the "take a photo" placeholder — `_ProofPhoto` requires
/// `status == captured` AND `delivery.hasProofPhoto`.
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

/// The error state — and the point is that you cannot tell.
///
/// `ProofPhotoStatus.failed` is what the cubit emits when the CDN upload throws
/// (`ActiveDeliveryException`): the bytes are still in memory, the delivery has
/// no `evidenceUrl`, and the slot renders the same tappable placeholder as
/// [markDeliveredPanelAwaitingProof] — same icon, same borrowed label, same
/// colour. Nothing in this panel says the upload failed. The cubit does raise
/// `transitionError` alongside it, which the SCREEN turns into a snackbar; once
/// that snackbar times out, a jeeber who looks back at the panel sees a state
/// indistinguishable from "I have not taken the photo yet" — and the delivery
/// can still be completed with no evidence attached.
///
/// Read this card side by side with the first one. If they ever stop being the
/// same picture, the widget grew a failure affordance and the render test that
/// pins their equality should be deleted rather than relaxed.
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

/// The degraded row: `GET /v1/delivery/{id}` came back without an `amount` and
/// without a `clientName`.
///
/// Both are nullable on [JeeberDelivery] and both feed one sentence, so
/// `_CashNote` renders `l10n.receiptCashToJeeber('', l10n.activeDeliveryDropOffLabel)`
/// — "Pay  cash to Drop-off address", with the double space the empty
/// substitution leaves behind and a UI label ("Drop-off address") standing in
/// for a person's name. This is the money line on the money screen, so it is
/// worth seeing exactly how it fails: the jeeber is told to collect an
/// unspecified amount from a heading.
///
/// `_amountText` returns null for a missing `amount`, a null `value`, or any
/// shape that is neither a number nor a `{value, currency}` map, so this is not
/// a hypothetical — it is every parse the mock or the gateway does not satisfy.
@JeebPreview(
  group: 'active_delivery_jeeber',
  name: 'Cash details missing',
  size: _markDeliveredPanelBox,
)
Widget markDeliveredPanelCashDetailsMissing() => _markDeliveredPanelHosted(
      proofPhotoStatus: ProofPhotoStatus.none,
      delivery: _markDeliveredPanelDelivery(),
    );

/// iter6 close-tail: the jeeber tapped "Complete Delivery", the ladder ran up
/// to `AtDoor`, and the frozen SM refused `AtDoor → Done` without the
/// recipient's code — so the CTA is gone and the door-OTP entry has taken its
/// place. Here the first attempt came back `invalid_otp`.
///
/// The second matrix card, for two reasons.
///
/// **RTL.** This is the panel's most position-sensitive layout: four
/// [OmdsOtpInput] cells that must read right-to-left in Arabic. The cells are
/// spaced with a physical `EdgeInsets.only(left:/right:)` rather than a
/// directional one, so the AR rendering redistributes the gaps (4 / 8 / 4 dp
/// instead of an even 8 / 8 / 8) — a small thing, pinned by the render test,
/// and the kind of thing only a side-by-side reading shows.
///
/// **The error line is English in both.** `otpError` is not a localization key
/// — `ActiveDeliveryCubit._mapOtpError` returns hardcoded English
/// ("Incorrect code — ask the recipient and try again", "Too many attempts —
/// contact support", …) and this panel prints it verbatim. The AR RTL card
/// therefore shows an Arabic title and instruction over an English error, which
/// is exactly what an Arabic-speaking jeeber sees at the door today.
///
/// The submit button is correctly disabled (`_code.length == 4` is false on a
/// fresh entry), so this card also shows the disabled state of
/// `OmdsLoadingButton` — 60% alpha on the primary fill, no tap action. Its
/// `mark_delivered_otp_submit` wrapper is a bare `Semantics(container: true)`
/// though, with no `button: true` and no `identifier` on the button itself, so
/// unlike `mark_delivered_cta` it is announced as a label rather than a button.
///
/// Two behaviours this card inherits from `autoFocus: true` on [OmdsOtpInput],
/// both of which happen on the real screen the instant `otpRequired` flips:
/// the keyboard opens unasked, and the delivering-phase `ListView` scrolls
/// itself to put the cell row above it. In the canvas that means this card
/// mounts with a live text cursor in cell 1 — the ticker mute is what keeps it
/// from blinking.
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
