import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../core/theme/jeeb_text_styles.dart';
import '../../../../core/widgets/jeeb/jeeb_avatar.dart';
import '../../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../../l10n/app_localizations.dart';

/// Chat header — the redesign-2026-08 screen-21 identity bar.
///
/// The cluster is the kit's [JeebTopBar.identity]: a Ø40 back circle, a Ø42
/// counterpart avatar, the name (16/w700) over a `★ 4.9` line, and one trailing
/// Ø40 circular action. It is still mounted as the Scaffold's `appBar` (the
/// screen's bounded-header architecture depends on the AppBar having already
/// consumed the top inset), so the bar is wrapped in a flat [Material] +
/// [SafeArea] rather than being pushed into the body.
///
/// The avatar slot is omitted when no counterpart is resolved yet, so the
/// broadcasting header stays title-only.
///
/// RTL: mirroring is kit-owned — the leading glyph resolves through
/// `DirectionalIcons.back` and the whole row is directional. The only forced
/// isolate is the rating NUMBER, so `4.9` never renders `9.4`.
///
/// Two board refusals, both re-stated here because they are load-bearing:
///   * **no presence dot** — no counterpart-presence signal exists anywhere in
///     the app (`ChatConnectionCubit` reports MY socket), and a dot that is
///     always green is a lie;
///   * **no call button** — no phone number reaches this surface, so the
///     trailing circle carries the existing dispute affordance instead.
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ChatAppBar({
    super.key,
    required this.title,
    this.avatarUrl,
    this.avatarImage,
    this.showAvatar = false,
    this.onAvatarTap,
    this.trailing,
    this.rating = 0,
  });

  /// Header title — counterpart display name or order/request id.
  final String title;

  /// Counterpart avatar URL (CDN-hosted via cdn-service). Falls back to the
  /// title initial inside the kit's circular [JeebAvatar] when null.
  final String? avatarUrl;

  /// Pre-resolved avatar image provider. Lets a caller bind a non-network
  /// source (e.g. a bundled [AssetImage] in the dev capture seam) through the
  /// same circular treatment as the production CDN path; takes precedence over
  /// [avatarUrl] when both are set. [JeebAvatar] takes a url only, so this
  /// branch keeps its own ClipOval + Image.
  final ImageProvider? avatarImage;

  /// Whether to render the leading avatar (post-approval state only).
  final bool showAvatar;

  /// Tapping the counterpart avatar opens their public profile (D-P1). The
  /// caller (chat screen) supplies a closure that branches on [RoleCubit] —
  /// pushing `/profile/delivery-man` (client viewing a jeeber) or
  /// `/profile/customer` (jeeber viewing a client) with the typed view-data
  /// extra. Null leaves the avatar non-interactive.
  final VoidCallback? onAvatarTap;

  /// The ONE trailing circular action. JM-025 AC3 passes the
  /// `order_chat_open_dispute` affordance on the accepted/active order-chat;
  /// the legacy 1:1 chat leaves it null. Replaces the old `actions:` list —
  /// the kit's trailing slot is a single [JeebTopBarAction], by design.
  final JeebTopBarAction? trailing;

  /// Counterpart rating, rendered as the `★ 4.9` subtitle line. `0` (the
  /// default, and every unresolved summary) hides the line entirely — a
  /// fabricated 0.0 would read as a terrible courier.
  final double rating;

  @override
  Size get preferredSize => const Size.fromHeight(Sizes.sevenXLarge);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: JeebTopBar.identity(
          identifier: 'chat_detail_back_button',
          leadingTooltip: l10n.chatBackA11y,
          title: title,
          // The board's subtitle reads `★ 4.9 · usually replies in 1 min`.
          // TODO(redesign-24): needs gateway reply-latency — omitted, not faked.
          subtitleSlot: rating > 0 ? _RatingLine(rating: rating) : null,
          avatar: showAvatar ? _avatarCluster(context, l10n) : null,
          // The `chat_detail_avatar` node is built here (it needs `button:` and
          // a label the kit's wrapper does not take), so the kit must not add a
          // second wrapper around it and split the node.
          onAvatarPressed: null,
          trailing: trailing,
        ),
      ),
    );
  }

  /// Today's `chat_detail_avatar` node shape, verbatim: the identifier, the
  /// button flag and the label all stay on ONE node, with the gesture inside
  /// it.
  Widget _avatarCluster(BuildContext context, AppLocalizations l10n) {
    final Widget visual = avatarImage != null
        ? _CircularImageAvatar(
            image: avatarImage!,
            size: JeebTopBar.identityAvatarDiameter,
          )
        : JeebAvatar(
            initial: title,
            imageUrl: avatarUrl,
            diameter: JeebTopBar.identityAvatarDiameter,
          );
    final VoidCallback? onTap = onAvatarTap;
    return Semantics(
      identifier: 'chat_detail_avatar',
      button: onTap != null,
      label: l10n.chatAvatarA11y,
      child: onTap != null
          ? GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: visual,
            )
          : visual,
    );
  }
}

/// `★ 4.9` — the counterpart's rating, in the periwinkle subtitle ink.
///
/// The star deliberately INHERITS that ink rather than taking
/// `starRatingColor`: the yellow star token belongs to screens 11/12/15
/// (00-MIGRATION-PLAN §4.1), and the board draws this one periwinkle.
class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String value = rating.toStringAsFixed(1);
    final TextStyle style = context.jeebText.caption.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSecondaryContainer,
    );
    return Semantics(
      label: AppLocalizations.of(context).chatCounterpartRatingA11y(value),
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: Sizes.medium,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: Spacing.twoXSmall),
            // The one LTR island: `4.9` must never render as `9.4`.
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(value, style: style),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular avatar for a pre-resolved [ImageProvider] (e.g. a non-network
/// source bound by a caller). [JeebAvatar] only accepts a URL, so the
/// image-provider case keeps a thin circular treatment of its own — and
/// `chat_dm_header_parity_test` D1 pins exactly this ClipOval + Image shape.
class _CircularImageAvatar extends StatelessWidget {
  const _CircularImageAvatar({required this.image, required this.size});

  final ImageProvider image;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image(
        image: image,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
