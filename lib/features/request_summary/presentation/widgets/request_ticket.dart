import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// `show Bidi` — intl also exports a TextDirection that would shadow Flutter's.
import 'package:intl/intl.dart' show Bidi;
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_color_roles.dart';
import '../../../../core/theme/jeeb_semantic_colors.dart';
import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_outlined_card.dart';
import '../../../../core/widgets/jeeb/jeeb_tier_chip.dart';
import '../../../../core/widgets/jeeb/jeeb_waveform.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../tier_selection/domain/tier.dart';
import '../../../transcription/domain/audioplayers_transcript_audio_player.dart';
import '../../../transcription/domain/transcript_audio_player.dart';
import '../../domain/request_draft.dart';

/// Corner radius of the ticket outline (board `dc-tpl 575`: 20px).
const double _ticketRadius = 20;

/// Ø42 play disc — the board's `dc-tpl 578`. No Sizes token lands on 42.
const double _discDiameter = 42;

/// The play/pause glyph inside the disc (`dc-tpl 579`: 18px).
const double _discGlyphSize = 18;

/// Route rail metrics (`dc-tpl 603-607`). None of these have OMDS tokens: the
/// rail is a 10px ring with a 3px stroke, a 2px connector that must clear 22px
/// even when both address lines are short, and a 14px drop-off pin.
const double _railRingDiameter = 10;
const double _railRingStroke = 3;
const double _railConnectorWidth = 2;
const double _railConnectorMinHeight = 22;
const double _railPinSize = 14;

/// Ring + 4px gap + connector floor + 4px gap + pin, so the rail never
/// collapses below the shape the board draws.
const double _railMinHeight =
    _railRingDiameter +
    Spacing.twoXSmall +
    _railConnectorMinHeight +
    Spacing.twoXSmall +
    _railPinSize;

/// The photo thumbnail glyph (`dc-tpl 617`: 18px).
const double _photoGlyphSize = 18;

/// How far the mode badge overhangs the ticket's top edge (`dc-tpl 577`).
const double _badgeOverhang = -9;

/// The single outlined "ticket" that carries the whole request review.
///
/// Replaces the previous six-card `ListView`: one card, one outline, dividers
/// between the rows that actually have data. Every row below the transcript
/// block is conditional — on the live voice path (transcription → summary) the
/// draft carries only a description and an audio id, so the ticket is short by
/// design.
class RequestTicket extends StatelessWidget {
  const RequestTicket({required this.draft, super.key, this.audioPlayer});

  final RequestDraft draft;

  /// Test override for the replay band's player. Production leaves it null and
  /// the band builds the `audioplayers` adapter itself, so no DI/router wiring
  /// is needed for playback to work.
  final TranscriptAudioPlayer? audioPlayer;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    // Two distinct conditions, deliberately: the badge only asks "was this
    // dictated?", the replay band additionally needs a playable local file.
    final bool isVoice = draft.audioUrl != null || draft.audioLocalPath != null;
    final String? localPath = draft.audioLocalPath;

    // The router seeds `description` and `transcription` with the same string,
    // so rendering both verbatim would print the sentence twice.
    final String? rawTranscription = draft.transcription?.trim();
    final String headline = (rawTranscription?.isNotEmpty ?? false)
        ? rawTranscription!
        : draft.description.trim();
    final String sub = draft.description.trim();
    final bool showSub = sub.isNotEmpty && sub != headline;

    final bool hasRoute =
        draft.pickupAddress != null || draft.dropoffAddress != null;

    // Every editor sits on the route we came from on both live producers, so
    // the links pop rather than push a second, divergent create flow.
    final bool canEdit = context.canPop();

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        JeebOutlinedCard.grouped(
          radius: _ticketRadius,
          children: <Widget>[
            _HeadBlock(
              localAudioPath: localPath,
              audioDurationMs: draft.audioDurationMs,
              audioPlayer: audioPlayer,
              headline: headline,
              sub: showSub ? sub : null,
              onEdit: canEdit ? () => _popToEditor(context) : null,
            ),
            if (draft.tierName != null)
              _TierRow(
                tierId: draft.tierId,
                tierName: draft.tierName!,
                onChange: canEdit ? () => _popToEditor(context) : null,
              ),
            if (hasRoute)
              _RouteTimeline(
                pickup: draft.pickupAddress,
                dropoff: draft.dropoffAddress,
                onChange: canEdit ? () => _popToEditor(context) : null,
              ),
            if (draft.photoUrls.isNotEmpty)
              _PhotosRow(count: draft.photoUrls.length),
          ],
        ),
        PositionedDirectional(
          start: Spacing.medium,
          top: _badgeOverhang,
          child: _ModeBadge(
            label: isVoice
                ? l10n.requestSummaryBadgeVoice
                : l10n.requestSummaryBadgeTyped,
          ),
        ),
      ],
    );
  }

  static void _popToEditor(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    }
  }
}

/// The navy pill that straddles the ticket's top edge.
class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: OmdsBorderRadius.pill,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xSmall,
          vertical: Spacing.twoXSmall,
        ),
        child: Text(
          // Uppercasing is EN-effective only; Arabic has no case and passes
          // through unchanged.
          label.toUpperCase(),
          style: context.jeebText.badge.copyWith(color: scheme.onPrimary),
        ),
      ),
    );
  }
}

/// Replay band + transcript, kept as ONE grouped child so the card's dividers
/// land where the board draws them (below the transcript, not below the band).
class _HeadBlock extends StatelessWidget {
  const _HeadBlock({
    required this.headline,
    required this.localAudioPath,
    required this.audioDurationMs,
    required this.audioPlayer,
    required this.sub,
    required this.onEdit,
  });

  final String headline;
  final String? sub;
  final String? localAudioPath;
  final int? audioDurationMs;
  final TranscriptAudioPlayer? audioPlayer;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (localAudioPath != null)
          _VoiceReplayBand(
            audioPath: localAudioPath!,
            durationMs: audioDurationMs,
            audioPlayer: audioPlayer,
          ),
        _TranscriptBlock(headline: headline, sub: sub, onEdit: onEdit),
      ],
    );
  }
}

/// Grey top band: play disc, waveform mark, duration read-out.
class _VoiceReplayBand extends StatefulWidget {
  const _VoiceReplayBand({
    required this.audioPath,
    required this.durationMs,
    required this.audioPlayer,
  });

  final String audioPath;
  final int? durationMs;
  final TranscriptAudioPlayer? audioPlayer;

  @override
  State<_VoiceReplayBand> createState() => _VoiceReplayBandState();
}

class _VoiceReplayBandState extends State<_VoiceReplayBand> {
  // Lazy: constructing the adapter touches no platform channel until play().
  late final TranscriptAudioPlayer _player =
      widget.audioPlayer ?? AudioPlayersTranscriptAudioPlayer();

  // The recorder writes to a temp file that can be reaped between screens; a
  // missing file disables the disc instead of crashing on play.
  late final bool _fileExists = File(widget.audioPath).existsSync();

  bool _isPlaying = false;

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.pause();
      if (!mounted) return;
      setState(() => _isPlaying = false);
      return;
    }
    setState(() => _isPlaying = true);
    await _player.play(
      widget.audioPath,
      onPosition: (_) {},
      onCompleted: () {
        if (!mounted) return;
        setState(() => _isPlaying = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;
    final int? durationMs = widget.durationMs;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: OmdsBorderRadius.large.topLeft),
      child: ColoredBox(
        color: scheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Row(
            children: <Widget>[
              Semantics(
                identifier: 'request_summary_voice_play',
                button: true,
                enabled: _fileExists,
                label: _isPlaying
                    ? l10n.transcriptionPauseAudio
                    : l10n.transcriptionPlayAudio,
                child: SizedBox.square(
                  dimension: _discDiameter,
                  child: Material(
                    color: _fileExists
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.45),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _fileExists ? _toggle : null,
                      child: Icon(
                        _isPlaying ? Icons.pause : Icons.play_arrow,
                        size: _discGlyphSize,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Spacing.small),
              const Expanded(child: JeebWaveform.cardMark()),
              if (durationMs != null) ...<Widget>[
                const SizedBox(width: Spacing.small),
                // A clip length never reorders in Arabic.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    _formatClipLength(durationMs),
                    style: context.jeebText.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: mutedInk,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _formatClipLength(int durationMs) {
  final int totalSeconds = (durationMs / 1000).round();
  final int minutes = totalSeconds ~/ 60;
  final String seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// The dictated sentence plus its typed detail line and the Edit link.
class _TranscriptBlock extends StatelessWidget {
  const _TranscriptBlock({
    required this.headline,
    required this.sub,
    required this.onEdit,
  });

  final String headline;
  final String? sub;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;
    final String? subLine = sub;
    final bool hasMetaRow = subLine != null || onEdit != null;

    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // The user's own sentence sets its own direction: an Arabic dictation
          // must read RTL even while the app chrome is English.
          Directionality(
            textDirection: Bidi.detectRtlDirectionality(headline)
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Text(
              headline,
              textAlign: TextAlign.start,
              style: context.jeebText.titleProminent.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
          if (hasMetaRow) ...<Widget>[
            const SizedBox(height: Spacing.twoXSmall),
            Row(
              children: <Widget>[
                if (subLine != null)
                  Expanded(
                    child: Text(
                      subLine,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.jeebText.bodySmall.copyWith(
                        color: mutedInk,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                if (onEdit != null)
                  _TicketLink(
                    label: l10n.requestSummaryEdit,
                    identifier: 'request_summary_edit_description',
                    onTap: onEdit!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Tier pill + SLA line + Change link.
class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tierId,
    required this.tierName,
    required this.onChange,
  });

  final String? tierId;
  final String tierName;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;

    // The draft carries a raw gateway slug; rendering it verbatim was a live
    // i18n leak. Resolve to the catalog copy when we recognise it and fall back
    // to the raw label when we do not, so an unknown tier stays visible.
    final TierId? resolved = _resolveTier(tierId, tierName);
    final String label = resolved == null
        ? tierName
        : _tierTitle(l10n, resolved);
    final String? sla = resolved == null ? null : _tierSpeed(l10n, resolved);

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.small,
        Spacing.medium,
        Spacing.small,
      ),
      child: Row(
        children: <Widget>[
          if (resolved == null)
            JeebTierChip.meta(label: label)
          else
            JeebTierChip(tier: JeebTier.fromId(resolved.name), label: label),
          const SizedBox(width: Spacing.xSmall),
          if (sla != null)
            Expanded(
              child: Text(
                sla,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.jeebText.bodySmall.copyWith(color: mutedInk),
              ),
            )
          else
            const Spacer(),
          if (onChange != null)
            _TicketLink(
              label: l10n.requestSummaryChange,
              identifier: 'request_summary_change_tier',
              onTap: onChange!,
            ),
        ],
      ),
    );
  }
}

TierId? _resolveTier(String? tierId, String tierName) {
  for (final String candidate in <String>[tierId ?? '', tierName]) {
    final String needle = candidate.toLowerCase().trim();
    if (needle.isEmpty) continue;
    for (final TierId tier in TierId.values) {
      if (tier.name.toLowerCase() == needle) return tier;
    }
  }
  return null;
}

String _tierTitle(AppLocalizations l10n, TierId tier) {
  switch (tier) {
    case TierId.flash:
      return l10n.tierFlashTitle;
    case TierId.express:
      return l10n.tierExpressTitle;
    case TierId.standard:
      return l10n.tierStandardTitle;
    case TierId.onTheWay:
      return l10n.tierOnTheWayTitle;
    case TierId.eco:
      return l10n.tierEcoTitle;
  }
}

String _tierSpeed(AppLocalizations l10n, TierId tier) {
  switch (tier) {
    case TierId.flash:
      return l10n.tierFlashSpeed;
    case TierId.express:
      return l10n.tierExpressSpeed;
    case TierId.standard:
      return l10n.tierStandardSpeed;
    case TierId.onTheWay:
      return l10n.tierOnTheWaySpeed;
    case TierId.eco:
      return l10n.tierEcoSpeed;
  }
}

/// Pickup → drop-off, drawn as a rail so the two stops read as one journey.
class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
    required this.pickup,
    required this.dropoff,
    required this.onChange,
  });

  final String? pickup;
  final String? dropoff;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? pickupAddress = pickup;
    final String? dropoffAddress = dropoff;

    return Padding(
      padding: const EdgeInsets.all(Spacing.medium),
      child: ConstrainedBox(
        // The rail is the shape that makes two addresses read as one journey,
        // so it keeps the board's 22px connector even if both lines are short.
        constraints: BoxConstraints(
          minHeight: pickupAddress != null && dropoffAddress != null
              ? _railMinHeight
              : 0,
        ),
        // `stretch` is what lets the rail's connector flex to the address
        // block's height, but it hands children the incoming max height — and
        // that is infinite inside the scroll view. IntrinsicHeight bounds it.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _RouteRail(
                hasPickup: pickupAddress != null,
                hasDropoff: dropoffAddress != null,
              ),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (pickupAddress != null)
                      _RouteStop(
                        label: l10n.requestSummarySectionPickup,
                        value: pickupAddress,
                      ),
                    if (pickupAddress != null && dropoffAddress != null)
                      const SizedBox(height: Spacing.small),
                    if (dropoffAddress != null)
                      _RouteStop(
                        label: l10n.requestSummarySectionDropoff,
                        value: dropoffAddress,
                      ),
                  ],
                ),
              ),
              if (onChange != null)
                Center(
                  child: _TicketLink(
                    label: l10n.requestSummaryChange,
                    identifier: 'request_summary_change_route',
                    onTap: onChange!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteRail extends StatelessWidget {
  const _RouteRail({required this.hasPickup, required this.hasDropoff});

  final bool hasPickup;
  final bool hasDropoff;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      // The ring's optical centre sits on the "Pickup" label, not above it.
      padding: const EdgeInsetsDirectional.only(top: Spacing.twoXSmall),
      child: Column(
        children: <Widget>[
          if (hasPickup)
            SizedBox.square(
              dimension: _railRingDiameter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.primary,
                    width: _railRingStroke,
                  ),
                ),
              ),
            ),
          if (hasPickup && hasDropoff)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: Spacing.twoXSmall,
                ),
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: const SizedBox(
                    width: _railConnectorWidth,
                    height: double.infinity,
                  ),
                ),
              ),
            ),
          if (hasDropoff)
            Icon(Icons.location_on, size: _railPinSize, color: scheme.error),
        ],
      ),
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: context.jeebText.bodySmall.copyWith(color: mutedInk),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.jeebText.cardTitle.copyWith(color: scheme.onSurface),
        ),
      ],
    );
  }
}

/// Up to two glyph placeholders plus the count. Deliberately renders no image:
/// the draft carries gateway ids, not bytes, and the app has no image cache.
class _PhotosRow extends StatelessWidget {
  const _PhotosRow({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Color mutedInk =
        (Theme.of(context).extension<JeebSemanticColors>() ??
                JeebSemanticColors.light())
            .mutedText;
    final TextStyle overflowStyle = context.jeebText.bodySmall.copyWith(
      fontWeight: FontWeight.w700,
      color: mutedInk,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        Spacing.medium,
        Spacing.small,
        Spacing.medium,
        Spacing.small,
      ),
      child: Row(
        children: <Widget>[
          _PhotoTile(
            child: Icon(
              Icons.image_outlined,
              size: _photoGlyphSize,
              color: mutedInk,
            ),
          ),
          if (count > 1) ...<Widget>[
            const SizedBox(width: Spacing.xSmall),
            _PhotoTile(
              // A latin-digit counter never mirrors.
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text('+${count - 1}', style: overflowStyle),
              ),
            ),
          ],
          const SizedBox(width: Spacing.xSmall),
          Expanded(
            child: Text(
              l10n.requestSummaryPhotosAttached(count),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.jeebText.bodySmall.copyWith(color: mutedInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: Sizes.threeXLarge,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: OmdsBorderRadius.small,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// The rationed orange affordance: `Edit` / `Change`.
class _TicketLink extends StatelessWidget {
  const _TicketLink({
    required this.label,
    required this.identifier,
    required this.onTap,
  });

  final String label;
  final String identifier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.xSmall,
        // Vertical-only: the label's end edge must stay flush with the row's
        // 16px inset, so the tap area grows in height, never in width.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.xSmall),
          child: Text(
            label,
            style: context.jeebText.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: context.jeebRoles.accent,
            ),
          ),
        ),
      ),
    );
  }
}
