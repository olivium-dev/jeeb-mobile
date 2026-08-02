/// Widget previews for [TranscriptionStatusBanner] — run with
/// `flutter widget-preview start`.
///
/// The banner is a pure function of one value object: it takes a
/// [TranscriptionState] plus an optional retry callback and renders a card. No
/// cubit, no repository, no recorder, no audio player — so every state below is
/// a hand-built [TranscriptionState] literal and these previews are
/// network-free by construction, not just by the guard in [jeebPreviewHost].
/// Each doc comment names the `TranscriptionCubit` call that reaches the state
/// in production, so the fixture stays traceable without building the cubit.
///
/// `TranscriptionScreen` mounts this banner only while
/// `status != TranscriptionStatus.ready`, so the previews cover the two
/// statuses a user can actually see — `queued` and `failed` — and every branch
/// of `_bannerBody`, which is where the copy (and therefore the layout height)
/// forks. Fixture values match `test/transcription_screen_test.dart`: clip
/// `audio-1`, 3–4s.
///
/// The previews exist so the *visual* half of that contract is reviewable
/// without recording a voice note: the info-role vs error-role container
/// pairing in dark mode, RTL mirroring of the icon → title/body → Retry stack,
/// and how a three-line body plus a button behave at 200% text.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/transcription/application/transcription_cubit.dart';
import '../../features/transcription/presentation/widgets/transcription_status_banner.dart';
import '../harness/jeeb_preview.dart';

/// Canvas box for a banner with no Retry button: phone width, three body lines,
/// with room for the 200%-text rendering to grow into.
const Size _bannerBox = Size(390, 240);

/// Canvas box for the failed states that DO render Retry. The button adds
/// `Spacing.small` + a 48dp tap target below an already three-line body, and
/// doubles again at 200% text; a 240px box would clip the evidence.
const Size _bannerWithRetryBox = Size(390, 320);

/// Post-upload, pre-transcript: exactly what `seedFromClip` emits for a clip
/// whose `transcript` is null/empty, and what `confirmEdit('')` falls back to.
const TranscriptionState _queued = TranscriptionState(
  status: TranscriptionStatus.queued,
  audioPath: 'audio-1',
  audioDuration: Duration(seconds: 3),
);

/// The state `markFailed(failure)` leaves behind. Note it KEEPS the audio: the
/// user can still replay the recording and type a manual description, which is
/// why the failed banner never blocks the screen.
TranscriptionState _failed(TranscriptionFailure failure) => TranscriptionState(
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
Widget _hosted(TranscriptionState state, {VoidCallback? onRetry}) => Padding(
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
@JeebPreview(name: 'Queued', size: _bannerBox)
Widget transcriptionStatusBannerQueued() => _hosted(_queued);

/// Contract guard, made visible: a retry handler on a QUEUED state must not
/// produce a Retry button.
///
/// `build` gates the button on `isFailed && onRetry != null`, so a caller that
/// wires `onRetry` unconditionally — the obvious way to write the screen — must
/// still render this card identically to `Queued`. If a Retry button ever
/// appears here, the gate has been loosened to `onRetry != null` and users can
/// re-fire a transcription that is already running.
@JeebPreview(name: 'Queued · retry ignored', size: _bannerBox)
Widget transcriptionStatusBannerQueuedRetryIgnored() =>
    _hosted(_queued, onRetry: () {});

/// `markFailed(TranscriptionFailure.network)` — the reason
/// `test/transcription_screen_test.dart` pins, and the one a user on a weak
/// connection hits most.
///
/// The full failed shape: error container, `Icons.error_outline`, a two-line
/// body and the outlined Retry button under it. This is the tallest thing the
/// banner can be at 1x text, and the state to review when judging whether the
/// button still has a 48dp tap target after the body wraps.
@JeebPreview(name: 'Failed · network', size: _bannerWithRetryBox)
Widget transcriptionStatusBannerFailedNetwork() =>
    _hosted(_failed(TranscriptionFailure.network), onRetry: () {});

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
@JeebPreview(name: 'Failed · payload too large', size: _bannerWithRetryBox)
Widget transcriptionStatusBannerFailedPayloadTooLarge() =>
    _hosted(_failed(TranscriptionFailure.payloadTooLarge), onRetry: () {});

/// How the SCREEN actually builds it today: `TranscriptionStatusBanner(state:
/// state)` with no `onRetry` (`transcription_screen.dart:141`), so the Retry
/// affordance the class doc advertises never renders in the shipped flow.
///
/// Kept as its own preview because the generic copy still ends "…or retry",
/// and this card is where that mismatch is visible: an error banner that tells
/// the user to retry while offering nothing to tap.
@JeebPreview(name: 'Failed · generic, no retry', size: _bannerBox)
Widget transcriptionStatusBannerFailedGenericNoRetry() =>
    _hosted(_failed(TranscriptionFailure.generic));

/// The defensive fall-through: `status == failed` while `failure` is still
/// `none`.
///
/// `markFailed` always sets a reason, but `copyWith` lets any other caller flip
/// the status alone, and `_bannerBody` folds `none` in with `generic` rather
/// than throwing. This preview is the proof that such a state renders a real
/// message rather than an empty body — an unlabelled error card is worse than a
/// vague one.
@JeebPreview(name: 'Failed · unclassified', size: _bannerWithRetryBox)
Widget transcriptionStatusBannerFailedUnclassified() =>
    _hosted(_failed(TranscriptionFailure.none), onRetry: () {});
