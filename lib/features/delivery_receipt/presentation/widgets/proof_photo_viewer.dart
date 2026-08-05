import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_scrim.dart';

/// Opens the full-screen proof-of-delivery viewer (JM-033) over the current
/// route: the photo, pinch/pan-zoomable, on a scrim, with one close affordance.
///
/// Deliberately a dialog and not a route — the viewer is a transient inspection
/// of data the receipt screen already holds, it carries no state of its own and
/// nothing deep-links to it, so it must not appear in the router or in the back
/// stack of the mandatory confirm/dispute flow.
///
/// Call it as fire-and-forget from a synchronous `onTap`; the returned future
/// completes when the dialog is dismissed and carries no result.
Future<void> showProofPhotoViewer(
  BuildContext context, {
  String? url,
  Uint8List? bytes,
  required String closeLabel,
  String unavailableText = 'Proof unavailable',
}) {
  assert(url != null || bytes != null);
  return showGeneralDialog<void>(
    context: context,
    // Was the scrim role UNDILUTED — an opaque black slab, not a dim. One
    // modal dim app-wide; a single lightbox does not earn a second rung.
    barrierColor: JeebScrim.barrier(context),
    barrierDismissible: true,
    barrierLabel: closeLabel,
    pageBuilder: (_, _, _) => _ProofPhotoViewer(
      url: url,
      bytes: bytes,
      closeLabel: closeLabel,
      unavailableText: unavailableText,
    ),
  );
}

class _ProofPhotoViewer extends StatelessWidget {
  const _ProofPhotoViewer({
    required this.url,
    required this.bytes,
    required this.closeLabel,
    required this.unavailableText,
  });

  final String? url;
  final Uint8List? bytes;
  final String closeLabel;
  final String unavailableText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier: 'receipt_proof_viewer_root',
      explicitChildNodes: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: bytes != null
                    ? Image.memory(
                        bytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) =>
                            _ProofPhotoViewerUnavailable(label: unavailableText),
                      )
                    : OmdsCachedImage(
                        url: url!,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => _ProofPhotoViewerUnavailable(
                          label: unavailableText,
                        ),
                      ),
              ),
            ),
          ),
          PositionedDirectional(
            top: MediaQuery.paddingOf(context).top + Spacing.small,
            end: Spacing.medium,
            child: Semantics(
              identifier: 'receipt_proof_viewer_close',
              button: true,
              label: closeLabel,
              onTap: () => Navigator.of(context).pop(),
              child: ExcludeSemantics(
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(Spacing.small),
                      child: Icon(
                        Icons.close,
                        size: Sizes.xLarge,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProofPhotoViewerUnavailable extends StatelessWidget {
  const _ProofPhotoViewerUnavailable({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
