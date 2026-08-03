import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
  required String url,
  required String closeLabel,
}) {
  return showGeneralDialog<void>(
    context: context,
    // Colors.black is banned by the token gate; the scheme's scrim is the
    // semantic role for exactly this overlay.
    barrierColor: Theme.of(context).colorScheme.scrim,
    barrierDismissible: true,
    barrierLabel: closeLabel,
    pageBuilder: (_, _, _) =>
        _ProofPhotoViewer(url: url, closeLabel: closeLabel),
  );
}

class _ProofPhotoViewer extends StatelessWidget {
  const _ProofPhotoViewer({required this.url, required this.closeLabel});

  final String url;
  final String closeLabel;

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
                child: OmdsCachedImage(url: url, fit: BoxFit.contain),
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
                        color: colorScheme.onPrimary,
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
