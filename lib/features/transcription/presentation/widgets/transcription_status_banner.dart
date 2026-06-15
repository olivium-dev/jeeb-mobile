import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

/// Inline banner shown above the text panel when the transcription is not the
/// happy-path `ready` text: either `queued` (audio saved, transcription
/// pending) or `failed` (the call errored). Both nudge the user to type their
/// request; the failed banner additionally surfaces a Retry affordance.
class TranscriptionStatusBanner extends StatelessWidget {
  const TranscriptionStatusBanner({
    super.key,
    required this.state,
    this.onRetry,
  });

  final TranscriptionState state;

  /// Optional retry handler (failed state). When null no retry button shows —
  /// the manual-entry fallback is always available regardless.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFailed = state.status == TranscriptionStatus.failed;
    return _BannerSurface(
      isFailed: isFailed,
      title: isFailed ? l10n.transcriptionFailedTitle : l10n.transcriptionQueuedTitle,
      body: _bannerBody(l10n, isFailed),
      retry: isFailed && onRetry != null
          ? _RetryButton(label: l10n.transcriptionRetry, onTap: onRetry!)
          : null,
    );
  }

  String _bannerBody(AppLocalizations l10n, bool isFailed) {
    if (!isFailed) return l10n.transcriptionQueuedBody;
    switch (state.failure) {
      case TranscriptionFailure.network:
        return l10n.transcriptionFailedNetwork;
      case TranscriptionFailure.payloadTooLarge:
        return l10n.transcriptionFailedPayloadTooLarge;
      case TranscriptionFailure.generic:
      case TranscriptionFailure.none:
        return l10n.transcriptionFailedGeneric;
    }
  }
}

class _BannerSurface extends StatelessWidget {
  const _BannerSurface({
    required this.isFailed,
    required this.title,
    required this.body,
    this.retry,
  });

  final bool isFailed;
  final String title;
  final String body;
  final Widget? retry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final container =
        isFailed ? colorScheme.errorContainer : colorScheme.secondaryContainer;
    // The queued container resolves to deep navy in the Jeeb scheme, so its
    // on-color must be the high-contrast on-navy token (`onPrimary`, white)
    // rather than `onSecondaryContainer` (muted purple #777FC0, ~3:1 on navy
    // — fails WCAG 2.2 AA for body text). The failed container is a light
    // error tint, so it keeps its M3-paired `onErrorContainer`.
    final onContainer = isFailed
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimary;
    return Semantics(
      container: true,
      label: '$title. $body',
      child: Container(
        padding: const EdgeInsets.all(Spacing.medium),
        decoration: BoxDecoration(
          color: container,
          borderRadius: OmdsBorderRadius.medium,
        ),
        child: _BannerContent(
          icon: isFailed ? Icons.error_outline : Icons.schedule,
          color: onContainer,
          title: title,
          body: body,
          retry: retry,
        ),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.retry,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final Widget? retry;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: Sizes.large),
        const SizedBox(width: Spacing.small),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: textTheme.titleSmall?.copyWith(color: color)),
              const SizedBox(height: Spacing.xSmall),
              Text(body, style: textTheme.bodySmall?.copyWith(color: color)),
              if (retry != null) ...[
                const SizedBox(height: Spacing.small),
                retry!,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: TranscriptionKeys.retryButton,
      button: true,
      child: OMDSOutlinedButton(text: label, onTap: onTap),
    );
  }
}
