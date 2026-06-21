import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Skeleton loading state for the jeeber request feed
/// (home-disc-jeeber-feed-loading). Renders a short list of
/// [OmdsListItemShimmer] placeholders so the initial-load surface matches the
/// project's list-skeleton guideline instead of a bare centered spinner.
///
/// Used by both the standalone [RequestFeedScreen] and the
/// [JeeberFeedTabView]'s initial-load path (where the spinner was previously
/// absent and the tab fell straight through to the empty state).
class JeeberFeedShimmer extends StatelessWidget {
  const JeeberFeedShimmer({super.key, this.itemCount = 5});

  /// QA / test anchor.
  static const Key shimmerKey = Key('jeeber-feed-shimmer');

  /// Number of skeleton rows to render.
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: shimmerKey,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.small),
      itemBuilder: (_, _) => const OmdsListItemShimmer(
        hasTrailing: true,
        leadingSize: 56,
      ),
    );
  }
}
