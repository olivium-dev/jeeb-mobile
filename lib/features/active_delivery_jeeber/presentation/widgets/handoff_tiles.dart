import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_radii.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/active_delivery_cubit.dart';
import '../../domain/jeeber_delivery.dart';
import '../active_delivery_jeeber_l10n.dart';
import '../active_delivery_muted_ink.dart';

/// Tile height — the board's `height: 86` (`18-active-delivery-jeeber.html`
/// `tpl 1069`). Named, not inlined: `Sizes` has no 86 rung (nearest is 88), and
/// the design gate does not scan `Container(height:)`, so this keeps the
/// design-exact px greppable instead of silently drifting to a token.
const double _kTileHeight = 86;

/// Glyph size inside a tile — the board's `22` (`tpl 1070/1074`). `Sizes` has
/// no 22 rung (20 / 24 bracket it).
const double _kTileGlyphSize = 22;

/// Evidence-tile corner radius — MIDNIGHT measures ~15, which snaps to `md`.
const double _kTileRadius = JeebRadii.md;

/// Ring stroke of an inline wait mark — the frozen kit's own in-button value
/// (`jeeb_cta_button`, `jeeb_chat_composer`).
const double _kMarkStroke = 2;

/// Test handle for the proof-photo upload mark: the tile's `Semantics` sits
/// above an `ExcludeSemantics`, so an `identifier:` here would be dropped.
const Key kProofPhotoUploadingKey = Key('mark_delivered_proof_photo.uploading');

/// Dash length / gap of the note tile's 1.5px dashed frame (`tpl 1073`).
const double _kDashLength = 5;
const double _kDashGap = 4;

/// Border width of the note tile's dashed frame (`tpl 1073`).
const double _kDashStroke = 1.5;

/// The two h86 evidence tiles inside the handoff card — proof photo (D3) and
/// the optional jeeber note (`18-active-delivery-jeeber.html` `tpl 1068-1075`).
///
/// Replaces the old 180px photo placeholder + always-open text field: on the
/// board both are compact tiles, and the note only becomes an editor once the
/// jeeber asks for one.
///
/// Stateful for one reason: the note tile latches open. A jeeber who has
/// started typing must never have the field collapse under them because the
/// delivery row re-rendered (a push refresh lands on this screen constantly).
class HandoffTiles extends StatefulWidget {
  const HandoffTiles({
    super.key,
    required this.delivery,
    required this.proofPhotoStatus,
    required this.onCaptureProof,
    required this.onNoteChanged,
    required this.l10n,
    required this.copy,
    this.proofPhotoBytes,
  });

  final JeeberDelivery delivery;
  final ProofPhotoStatus proofPhotoStatus;

  /// JEBV4-200: the just-captured bytes, preferred over the stamped
  /// `evidenceUrl` so the jeeber sees the real photo, not a CDN round-trip.
  final Uint8List? proofPhotoBytes;
  final VoidCallback onCaptureProof;
  final ValueChanged<String> onNoteChanged;
  final AppLocalizations l10n;
  final ActiveDeliveryJeeberL10n copy;

  @override
  State<HandoffTiles> createState() => _HandoffTilesState();
}

class _HandoffTilesState extends State<HandoffTiles> {
  bool _noteExpanded = false;

  @override
  Widget build(BuildContext context) {
    // `mark_delivered_note_field` spans the tile AND the editor it opens, so
    // the identifier is emitted in both states and a driver that taps it can
    // then type into the field it revealed. `explicitChildNodes` keeps
    // `mark_delivered_proof_photo` a separately addressable child node.
    return Semantics(
      identifier: 'mark_delivered_note_field',
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _ProofPhotoTile(
                  delivery: widget.delivery,
                  status: widget.proofPhotoStatus,
                  bytes: widget.proofPhotoBytes,
                  onCapture: widget.onCaptureProof,
                  l10n: widget.l10n,
                  copy: widget.copy,
                ),
              ),
              // The board's 10px gap; 12 is the rung.
              const SizedBox(width: Spacing.small),
              Expanded(
                child: _NoteTile(
                  expanded: _noteExpanded,
                  label: widget.copy.noteTile,
                  onTap: _expandNote,
                ),
              ),
            ],
          ),
          if (_noteExpanded) ...[
            const SizedBox(height: Spacing.small),
            OmdsTextField(
              labelText: widget.copy.noteTile,
              hintText: widget.l10n.offerSubmissionNoteHint,
              maxLines: 3,
              maxLength: 280,
              autofocus: true,
              onChanged: widget.onNoteChanged,
            ),
          ],
        ],
      ),
    );
  }

  void _expandNote() {
    if (_noteExpanded) return;
    setState(() => _noteExpanded = true);
  }
}

/// `mark_delivered_proof_photo` — the tap-to-capture proof tile (D3).
///
/// Three states: empty (camera glyph + label), uploading (spinner), captured
/// (the photo behind the r12 clip + a check beside the label). The captured
/// thumbnail is kept even though the board only draws the empty state — losing
/// it would regress JEBV4-200, where the jeeber could not see what they shot.
class _ProofPhotoTile extends StatelessWidget {
  const _ProofPhotoTile({
    required this.delivery,
    required this.status,
    required this.bytes,
    required this.onCapture,
    required this.l10n,
    required this.copy,
  });

  final JeeberDelivery delivery;
  final ProofPhotoStatus status;
  final Uint8List? bytes;
  final VoidCallback onCapture;
  final AppLocalizations l10n;
  final ActiveDeliveryJeeberL10n copy;

  @override
  Widget build(BuildContext context) {
    final glass = jeebGlass(context);
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
            borderRadius: BorderRadius.circular(_kTileRadius),
            child: Container(
              height: _kTileHeight,
              color: glass.glassFillEmphasis,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (captured) _thumbnail(),
                  Center(
                    child: uploading
                        ? _uploadingMark(context)
                        : _label(context, captured: captured),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail() {
    final data = bytes;
    if (data != null) {
      return Image.memory(data, fit: BoxFit.cover);
    }
    return OmdsCachedImage(url: delivery.proofPhotoUrl!, fit: BoxFit.cover);
  }

  /// The wait mark takes the camera glyph's own slot — same Ø22, same muted
  /// ink. `OmdsLoadingState` left the ring untinted, i.e. `primary` = orange.
  Widget _uploadingMark(BuildContext context) {
    return SizedBox.square(
      key: kProofPhotoUploadingKey,
      dimension: _kTileGlyphSize,
      child: CircularProgressIndicator(
        strokeWidth: _kMarkStroke,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _label(BuildContext context, {required bool captured}) {
    final colorScheme = Theme.of(context).colorScheme;
    // MIDNIGHT: the tile's label is white in both states and the "done" signal
    // is the GREEN check (`onSuccessContainer`, measured) — never orange.
    final style = context.jeebText.caption.copyWith(
      fontWeight: FontWeight.w700,
      color: colorScheme.onSurface,
    );
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            copy.proofPhotoTile,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (captured) ...[
          const SizedBox(width: Spacing.twoXSmall),
          Icon(
            Icons.check,
            size: Sizes.medium,
            color: context.jeebRoles.onSuccessContainer,
          ),
        ],
      ],
    );
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!captured) ...[
          Icon(
            Icons.photo_camera,
            size: _kTileGlyphSize,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: Spacing.twoXSmall),
        ],
        text,
      ],
    );
    if (!captured) return column;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.scrim.withValues(alpha: _kScrimOpacity),
        borderRadius: BorderRadius.circular(JeebRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xSmall,
          vertical: Spacing.twoXSmall,
        ),
        child: column,
      ),
    );
  }
}

/// Scrim behind the caption once the tile shows a photo.
const double _kScrimOpacity = 0.55;

/// The optional-note tile: a dashed r12 cell that opens the editor (`tpl 1073`).
class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.expanded,
    required this.label,
    required this.onTap,
  });

  final bool expanded;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final glass = jeebGlass(context);
    // Board: the closed tile is entirely periwinkle; opening it promotes the
    // ink to white. Orange stays on the panel frame and the CTA.
    final ink = expanded ? colorScheme.onSurface : glass.mutedText;
    final body = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The board's glyph is a bare `+`, not a notes rule.
          Icon(Icons.add, size: _kTileGlyphSize, color: ink),
          const SizedBox(height: Spacing.twoXSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.xSmall),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.jeebText.caption.copyWith(color: ink),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      identifier: 'mark_delivered_note_tile',
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            height: _kTileHeight,
            // Open: the tile becomes a filled cell like its neighbour. Closed:
            // a dashed outline, which is the board's "nothing here yet" mark.
            child: expanded
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: glass.glassFillEmphasis,
                      borderRadius: BorderRadius.circular(_kTileRadius),
                    ),
                    child: body,
                  )
                : CustomPaint(
                    // §8 puts dashed drop-zone borders at white .30–.35; the
                    // ladder tops out at `glassBorderVivid` (.22) — clamped.
                    painter: _DashedBorderPainter(
                      color: glass.glassBorderVivid,
                    ),
                    child: body,
                  ),
          ),
        ),
      ),
    );
  }
}

/// 1.5px dashed r12 rounded rect. Hand-painted because the design system has
/// no dashed border and this lane may not add a package.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = _kDashStroke
      ..style = PaintingStyle.stroke;
    const inset = _kDashStroke / 2;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        inset,
        inset,
        size.width - _kDashStroke,
        size.height - _kDashStroke,
      ),
      const Radius.circular(_kTileRadius),
    );
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _kDashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + _kDashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
