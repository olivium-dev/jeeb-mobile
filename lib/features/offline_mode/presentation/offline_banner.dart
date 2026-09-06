import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../core/theme/jeeb_color_roles.dart';
import '../../../l10n/app_localizations.dart';
import '../application/offline_cubit.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  /// True while the notice occupies the top inset, so the host can stop the
  /// content below reserving that same status-bar gap a second time.
  static bool showsFor(OfflineState state) =>
      state.status != ConnectivityStatus.online && !state.bannerDismissed;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineCubit, OfflineState>(
      builder: (context, state) {
        if (!showsFor(state)) return const SizedBox.shrink();
        return const SafeArea(bottom: false, child: _OfflineMaterialBanner());
      },
    );
  }
}

class _OfflineMaterialBanner extends StatelessWidget {
  const _OfflineMaterialBanner();

  @override
  Widget build(BuildContext context) {
    final roles = context.jeebRoles;
    final l10n = AppLocalizations.of(context);
    // MaterialBanner wraps itself in Semantics only when animated (banner.dart
    // 430-453), so this inline use emitted no node at all.
    return Semantics(
      identifier: 'offline_banner',
      label: l10n.offlineBannerMessage,
      liveRegion: true,
      container: true,
      explicitChildNodes: true,
      child: MaterialBanner(
        content: Text(
          l10n.offlineBannerMessage,
          style: TextStyle(color: roles.onWarningContainer),
        ),
        leading: Icon(
          Icons.cloud_off,
          color: roles.onWarningContainer,
        ),
        backgroundColor: roles.warningContainer,
        actions: <Widget>[
          Semantics(
            identifier: 'offline_banner_dismiss_cta',
            container: true,
            button: true,
            child: OmdsPrimaryButton(
              text: l10n.commonDismiss,
              variant: OmdsButtonVariant.text,
              textColor: roles.onWarningContainer,
              onTap: () => context.read<OfflineCubit>().dismissBanner(),
            ),
          ),
        ],
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// A typical phone — the width the banner is reviewed and asserted against.
const double _offlineBannerPhoneWidth = 390;

/// Phone width, with room for the banner plus the fixture caption beneath it.
const Size _offlineBannerBannerBox = Size(_offlineBannerPhoneWidth, 200);

/// Same width, short: in the collapsed states there is nothing but the caption
/// to show, and a tall box would imply the banner left a gap behind.
const Size _offlineBannerCollapsedBox = Size(_offlineBannerPhoneWidth, 110);

/// Keyed by [caption], which is unique per preview.
/// Not cosmetic: [BlocProvider]'s `create` runs ONCE per element, so a render
Widget _offlineBannerHosted({
  required String caption,
  required OfflineCubit Function() episode,
}) {
  return BlocProvider<OfflineCubit>(
    key: ValueKey<String>(caption),
    create: (BuildContext _) => episode(),
    child: _OfflineBannerStage(caption: caption),
  );
}

/// Mounts [OfflineBanner] the way a page does — pinned to phone width, at the
/// top of the content, with something underneath it.
/// The caption is preview scaffolding, not part of the widget: it spells out
class _OfflineBannerStage extends StatelessWidget {
  const _OfflineBannerStage({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: SizedBox(
        width: _offlineBannerPhoneWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const OfflineBanner(),
            ColoredBox(
              color: colors.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(Spacing.medium),
                child: Text(
                  caption,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The state the widget exists for: the connection dropped and the user has not
/// dismissed the notice yet.
@JeebPreview(
  group: 'offline_mode',
  name: 'Offline · banner shown',
  size: _offlineBannerBannerBox,
  matrix: true,
)
Widget offlineBannerOffline() => _offlineBannerHosted(
      caption: 'setOffline() · banner armed',
      episode: () => OfflineCubit()..setOffline(),
    );

/// Offline with work waiting: three edits made since the connection dropped.
/// It renders identically to [offlineBannerOffline], and that identity IS the
@JeebPreview(
  group: 'offline_mode',
  name: 'Offline · writes queued',
  size: _offlineBannerBannerBox,
)
Widget offlineBannerPendingSync() => _offlineBannerHosted(
      caption: 'setOffline() + three queued writes',
      episode: () => OfflineCubit()
        ..setOffline()
        ..enqueuePendingSync()
        ..enqueuePendingSync()
        ..enqueuePendingSync(),
    );

/// JEBV4-13, first half: DISMISS has to actually dismiss.
/// The action used to be `onTap: () {}` — a dead CTA of the atlas P1 #18 class
@JeebPreview(
  group: 'offline_mode',
  name: 'Dismissed this episode',
  size: _offlineBannerCollapsedBox,
)
Widget offlineBannerDismissed() => _offlineBannerHosted(
      caption: 'setOffline() + dismissBanner() · hidden for this episode',
      episode: () => OfflineCubit()
        ..setOffline()
        ..dismissBanner(),
    );

/// JEBV4-13, second half: one dismissal must not silence the NEXT outage.
/// Seeded through the whole episode the app makes — offline, dismiss, back
@JeebPreview(
  group: 'offline_mode',
  name: 'Re-armed by a new outage',
  size: _offlineBannerBannerBox,
)
Widget offlineBannerReArmed() => _offlineBannerHosted(
      caption: 'offline → dismiss → online → offline again',
      episode: () => OfflineCubit()
        ..setOffline()
        ..dismissBanner()
        ..setOnline()
        ..setOffline(),
    );

/// The state the widget is in for almost all of its life: connected.
/// It must be invisible AND cost nothing — `SizedBox.shrink()`, not an empty
@JeebPreview(
  group: 'offline_mode',
  name: 'Online · collapsed',
  size: _offlineBannerCollapsedBox,
)
Widget offlineBannerOnline() => _offlineBannerHosted(
      caption: 'OfflineCubit() · online, nothing to report',
      episode: OfflineCubit.new,
    );
