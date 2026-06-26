import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/search_repository.dart';

/// A single search-result row (`search_result_<id>`). Dumb widget
/// (40_GUARDRAILS_ARCH §1): data in via constructor, the tap out via [onTap] —
/// it never reaches `sl` or `context.go`.
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.result,
    required this.onTap,
  });

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;
    final subtitle = result.subtitle;

    return Semantics(
      identifier: 'search_result_${result.id}',
      button: true,
      container: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: OmdsBorderRadius.small,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: Spacing.medium,
            vertical: Spacing.small,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeadingIcon(kind: result.kind),
              const SizedBox(width: Spacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: textTheme.titleSmall?.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: Spacing.twoXSmall),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Spacing.small),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Typed leading icon — one glyph per result kind (cosmetic; flows key on the
/// row id, not the icon).
class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.kind});

  final SearchResultKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: Sizes.fiveXLarge,
      height: Sizes.fiveXLarge,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: OmdsBorderRadius.small,
      ),
      child: Icon(_iconFor(kind), color: colors.onSurfaceVariant),
    );
  }

  IconData _iconFor(SearchResultKind kind) {
    switch (kind) {
      case SearchResultKind.order:
        return Icons.local_shipping_outlined;
      case SearchResultKind.conversation:
        return Icons.chat_bubble_outline;
      case SearchResultKind.unknown:
        return Icons.search_outlined;
    }
  }
}
