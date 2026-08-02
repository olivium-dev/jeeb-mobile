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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests:
// test/previews/transcription/transcription_status_banner_preview_test.dart
// ===========================================================================
//
// Widget previews for [TranscriptionStatusBanner] — run with
// `flutter widget-preview start`.
//
// The banner is a pure function of one value object: it takes a
// [TranscriptionState] plus an optional retry callback and renders a card. No
// cubit, no repository, no recorder, no audio player — so every state below is
// a hand-built [TranscriptionState] literal and these previews are
// network-free by construction, not just by the guard in [jeebPreviewHost].
// Each doc comment names the `TranscriptionCubit` call that reaches the state
// in production, so the fixture stays traceable without building the cubit.
//
// `TranscriptionScreen` mounts this banner only while
// `status != TranscriptionStatus.ready`, so the previews cover the two
// statuses a user can actually see — `queued` and `failed` — and every branch
// of `_bannerBody`, which is where the copy (and therefore the layout height)
// forks. Fixture values match `test/transcription_screen_test.dart`: clip
// `audio-1`, 3–4s.
//
// The previews exist so the *visual* half of that contract is reviewable
// without recording a voice note: the info-role vs error-role container
// pairing in dark mode, RTL mirroring of the icon → title/body → Retry stack,
// and how a three-line body plus a button behave at 200% text.

/// Canvas box for a banner with no Retry button: phone width, three body lines,
/// with room for the 200%-text rendering to grow into.
const Size _transcriptionStatusBannerBox = Size(390, 240);

/// Canvas box for the failed states that DO render Retry. The button adds
/// `Spacing.small` + a 48dp tap target below an already three-line body, and
/// doubles again at 200% text; a 240px box would clip the evidence.
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
/// why the failed banner never blocks the screen.
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
/// preview identically keeps the reviewed width honest — a bare banner reads a
/// full 32dp wider than it is ever drawn in the app, which is exactly the
/// margin that decides whether the body wraps to three lines or four.
Widget _transcriptionStatusBannerHosted(
  TranscriptionState state, {
  VoidCallback? onRetry,
}) =>
    Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: TranscriptionStatusBanner(state: state, onRetry: onRetry),
    );

/// The common non-happy path: the upload landed but the transcript has not.
///
/// This is the only state that uses the semantic **info** role pair
/// (`infoContainer` / `onInfoContainer`) rather than the M3 error pair — the
/// widget comment records that it replaced a navy `secondaryContainer` +
/// `onPrimary` contrast workaround, so the AR RTL **dark** rendering is the one
/// to read: it is where a regressed role pair goes illegible first.
///
/// No Retry here by design — the job is already queued, so retrying it would
/// duplicate work rather than unblock the user; the nudge is to type instead.
@JeebPreview(
  group: 'transcription',
  name: 'Queued',
  size: _transcriptionStatusBannerBox,
)
Widget transcriptionStatusBannerQueued() =>
    _transcriptionStatusBannerHosted(_transcriptionStatusBannerQueuedState);

/// Contract guard, made visible: a retry handler on a QUEUED state must not
/// produce a Retry button.
///
/// `build` gates the button on `isFailed && onRetry != null`, so a caller that
/// wires `onRetry` unconditionally — the obvious way to write the screen — must
/// still render this card identically to `Queued`. If a Retry button ever
/// appears here, the gate has been loosened to `onRetry != null` and users can
/// re-fire a transcription that is already running.
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
/// connection hits most.
///
/// The full failed shape: error container, `Icons.error_outline`, a two-line
/// body and the outlined Retry button under it. This is the tallest thing the
/// banner can be at 1x text, and the state to review when judging whether the
/// button still has a 48dp tap target after the body wraps.
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
///
/// The payload-too-large body is the longest of the four strings in both EN and
/// AR, so at 200% text it decides the widget's real height budget. Read the AR
/// RTL rendering first: the Arabic Retry label overflows `OMDSOutlinedButton`'s
/// inner `Row(mainAxisSize: min)`, which never wraps its `Text` — 17px over at
/// 320pt/1.15x, 184px over at 320pt/2.0x, still 114px over at 390pt/2.0x, while
/// English is clean at every width/scale probed. The tripwire lives in
/// `test/previews/transcription/transcription_status_banner_preview_test.dart`.
/// This is exactly what the AR RTL and 200%-text renderings of the matrix are
/// for — the EN light rendering looks fine long after those two have broken.
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
/// affordance the class doc advertises never renders in the shipped flow.
///
/// Kept as its own preview because the generic copy still ends "…or retry",
/// and this card is where that mismatch is visible: an error banner that tells
/// the user to retry while offering nothing to tap.
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
///
/// `markFailed` always sets a reason, but `copyWith` lets any other caller flip
/// the status alone, and `_bannerBody` folds `none` in with `generic` rather
/// than throwing. This preview is the proof that such a state renders a real
/// message rather than an empty body — an unlabelled error card is worse than a
/// vague one.
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
