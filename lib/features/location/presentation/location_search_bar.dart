import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../data/location_repository.dart';

class LocationSearchBar extends StatelessWidget {
  const LocationSearchBar({
    super.key,
    required this.hintText,
    required this.query,
    required this.results,
    required this.isSearching,
    required this.onChanged,
    required this.onResultSelected,
    this.controller,
    this.emptyResultsLabel,
  });

  final String hintText;
  final String query;
  final List<LocationPoint> results;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final ValueChanged<LocationPoint> onResultSelected;
  final TextEditingController? controller;

  final String? emptyResultsLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = query.trim().isNotEmpty;
    final showResults = hasQuery && (results.isNotEmpty || !isSearching);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OmdsSearchBar(
          controller: controller,
          hintText: hintText,
          onChanged: onChanged,
          onClear: () => onChanged(''),
        ),
        if (isSearching)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        if (showResults)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.small),
            child: Material(
              color: colorScheme.surfaceContainerLowest,
              elevation: 1,
              borderRadius: OmdsBorderRadius.uiMedium,
              child: _ResultsList(
                results: results,
                emptyLabel: emptyResultsLabel,
                onSelected: onResultSelected,
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.results,
    required this.emptyLabel,
    required this.onSelected,
  });

  final List<LocationPoint> results;
  final String? emptyLabel;
  final ValueChanged<LocationPoint> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Text(
          emptyLabel ?? 'No matches',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: results.length,
      separatorBuilder: (_, _) => Divider(
        height: 1,
        thickness: 0.5,
        color: colorScheme.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final point = results[index];
        return _ResultTile(
          point: point,
          onTap: () => onSelected(point),
        );
      },
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.point, required this.onTap});

  final LocationPoint point;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Row(
          children: [
            Icon(
              Icons.place_outlined,
              color: colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                point.address ?? '${point.latitude}, ${point.longitude}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
