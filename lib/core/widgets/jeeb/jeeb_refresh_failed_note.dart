import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../network/app_failure.dart';
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../previews/jeeb_preview.dart';
import 'app_failure_copy.dart';
import 'jeeb_info_note.dart';

/// The warm-failure strip: a refresh failed while rows are on screen, so the
/// notice goes above the list rather than throwing those rows away.
class JeebRefreshFailedNote extends StatelessWidget {
  const JeebRefreshFailedNote({
    super.key,
    required this.failure,
    required this.identifier,
    required this.onDismiss,
    this.onRetry,
    this.messageOverride,
  }) : assert(identifier.length > 0, 'An unfindable note is untestable');

  /// The classified refresh failure.
  final AppFailure failure;

  /// `<screen>_refresh_failed`.
  final String identifier;

  /// Clears `refreshError` on the cubit.
  final VoidCallback onDismiss;

  /// Retries the refresh; null renders dismiss only.
  final VoidCallback? onRetry;

  /// Replaces the copy family's body.
  final String? messageOverride;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final FailureCopy copy = failureCopy(l10n, failure);
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final String message = messageOverride ?? copy.body;

    // The id, the label and the liveRegion flag must sit on ONE node: an
    // announced node with no text of its own is read out as silence.
    return Semantics(
      identifier: identifier,
      label: message,
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      child: JeebInfoNote.error(
        icon: Icons.sync_problem,
        text: message,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onRetry != null)
              Semantics(
                identifier: '${identifier}_retry_cta',
                button: true,
                container: true,
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  color: scheme.onErrorContainer,
                  tooltip: l10n.actionRetry,
                  onPressed: onRetry,
                ),
              ),
            Semantics(
              identifier: '${identifier}_dismiss_cta',
              button: true,
              container: true,
              child: IconButton(
                icon: const Icon(Icons.close),
                color: scheme.onErrorContainer,
                tooltip: l10n.actionDismiss,
                onPressed: onDismiss,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for the preview
// canvas and the preview tests.

/// Phone box; the strip is one row, so the caption fits under it.
const Size _jeebRefreshFailedNoteBox = Size(390, 200);

/// Hosts [child] under a caption naming the state under review.
Widget _jeebRefreshFailedNoteHosted(String caption, Widget child) => Padding(
  padding: const EdgeInsets.all(16),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[child, const SizedBox(height: 8), Text(caption)],
  ),
);

/// The shipping case: refresh failed, rows are still on screen, both acts
/// available.
@JeebPreview(
  group: 'core',
  name: 'Retry + dismiss',
  size: _jeebRefreshFailedNoteBox,
  matrix: true,
)
Widget jeebRefreshFailedNoteRetryable() => _jeebRefreshFailedNoteHosted(
  'Retry + dismiss',
  JeebRefreshFailedNote(
    failure: const NetworkFailure(offline: true),
    identifier: 'preview_refresh_failed',
    onDismiss: () {},
    onRetry: () {},
  ),
);

/// No retry wired — dismiss only, never a dead refresh glyph.
@JeebPreview(
  group: 'core',
  name: 'Dismiss only',
  size: _jeebRefreshFailedNoteBox,
)
Widget jeebRefreshFailedNoteDismissOnly() => _jeebRefreshFailedNoteHosted(
  'Dismiss only',
  JeebRefreshFailedNote(
    failure: const ServerFailure(status: 503),
    identifier: 'preview_refresh_failed',
    onDismiss: () {},
  ),
);
