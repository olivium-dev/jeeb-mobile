import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/transcription_cubit.dart';
import '../transcription_screen.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';

class TranscriptionStatusBanner extends StatelessWidget {
  const TranscriptionStatusBanner({
    super.key,
    required this.state,
    this.onRetry,
  });

  final TranscriptionState state;

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
    // workaround. Failed keeps the M3 error pair.
    final roles = context.jeebRoles;
    final container =
        isFailed ? colorScheme.errorContainer : roles.infoContainer;
    final onContainer = isFailed
        ? colorScheme.onErrorContainer
        : roles.onInfoContainer;
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
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// Canvas box for a banner with no Retry button: phone width, three body lines,
/// with room for the 200%-text rendering to grow into.
const Size _transcriptionStatusBannerBox = Size(390, 240);

/// Canvas box for the failed states that DO render Retry. The button adds
/// `Spacing.small` + a 48dp tap target below an already three-line body, and
const Size _transcriptionStatusBannerWithRetryBox = Size(390, 320);

/// Post-upload, pre-transcript: exactly what `seedFromClip` emits for a clip
/// whose `transcript` is null/empty, and what `confirmEdit('')` falls back to.
const TranscriptionState _transcriptionStatusBannerQueuedState =
    TranscriptionState(
  status: TranscriptionStatus.queued,
  audioPath: 'audio-1',
  audioDuration: Duration(seconds: 3),
);

/// The state `markFailed(failure)` leaves behind. Note it KEEPS the audio: the
/// user can still replay the recording and type a manual description, which is
TranscriptionState _transcriptionStatusBannerFailedState(
  TranscriptionFailure failure,
) =>
    TranscriptionState(
      status: TranscriptionStatus.failed,
      failure: failure,
      audioPath: 'audio-1',
      audioDuration: const Duration(seconds: 4),
    );

/// Mirrors the production surround: `TranscriptionScreen` renders the banner as
/// a `ListView` child under `EdgeInsets.all(Spacing.medium)`. Padding the
Widget _transcriptionStatusBannerHosted(
  TranscriptionState state, {
  VoidCallback? onRetry,
}) =>
    Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: TranscriptionStatusBanner(state: state, onRetry: onRetry),
    );

/// The common non-happy path: the upload landed but the transcript has not.
/// This is the only state that uses the semantic **info** role pair
@JeebPreview(
  group: 'transcription',
  name: 'Queued',
  size: _transcriptionStatusBannerBox,
)
Widget transcriptionStatusBannerQueued() =>
    _transcriptionStatusBannerHosted(_transcriptionStatusBannerQueuedState);

/// Contract guard, made visible: a retry handler on a QUEUED state must not
/// produce a Retry button.
@JeebPreview(
  group: 'transcription',
  name: 'Queued · retry ignored',
  size: _transcriptionStatusBannerBox,
)
Widget transcriptionStatusBannerQueuedRetryIgnored() =>
    _transcriptionStatusBannerHosted(
      _transcriptionStatusBannerQueuedState,
      onRetry: () {},
    );

/// `markFailed(TranscriptionFailure.network)` — the reason
/// `test/transcription_screen_test.dart` pins, and the one a user on a weak
@JeebPreview(
  group: 'transcription',
  name: 'Failed · network',
  size: _transcriptionStatusBannerWithRetryBox,
)
Widget transcriptionStatusBannerFailedNetwork() =>
    _transcriptionStatusBannerHosted(
      _transcriptionStatusBannerFailedState(TranscriptionFailure.network),
      onRetry: () {},
    );

/// Layout ceiling: the longest copy the banner can hold, plus a button — and
/// the state that already exposes a live overflow.
@JeebPreview(
  group: 'transcription',
  name: 'Failed · payload too large',
  size: _transcriptionStatusBannerWithRetryBox,
)
Widget transcriptionStatusBannerFailedPayloadTooLarge() =>
    _transcriptionStatusBannerHosted(
      _transcriptionStatusBannerFailedState(
        TranscriptionFailure.payloadTooLarge,
      ),
      onRetry: () {},
    );

/// How the SCREEN actually builds it today: `TranscriptionStatusBanner(state:
/// state)` with no `onRetry` (`transcription_screen.dart:141`), so the Retry
@JeebPreview(
  group: 'transcription',
  name: 'Failed · generic, no retry',
  size: _transcriptionStatusBannerBox,
)
Widget transcriptionStatusBannerFailedGenericNoRetry() =>
    _transcriptionStatusBannerHosted(
      _transcriptionStatusBannerFailedState(TranscriptionFailure.generic),
    );

/// The defensive fall-through: `status == failed` while `failure` is still
/// `none`.
@JeebPreview(
  group: 'transcription',
  name: 'Failed · unclassified',
  size: _transcriptionStatusBannerWithRetryBox,
)
Widget transcriptionStatusBannerFailedUnclassified() =>
    _transcriptionStatusBannerHosted(
      _transcriptionStatusBannerFailedState(TranscriptionFailure.none),
      onRetry: () {},
    );
