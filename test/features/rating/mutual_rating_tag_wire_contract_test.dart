// JEBV4-297 — wire-contract guard for the mutual-rating tag taxonomy.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

void main() {
  // Mirrors gateway src/JeebGateway/Ratings/Jeeb/JeebRatingVocabulary.cs
  const gatewayAllowedTags = <String>{
    'punctuality',
    'communication',
    'package_condition',
    'courtesy',
    'navigation',
  };

  test('every mutual-rating chip key is a recognised gateway rating tag', () {
    expect(kMutualRatingTags, isNotEmpty);
    for (final tag in kMutualRatingTags) {
      // The gateway does raw.Trim().ToLowerInvariant() before the whitelist
      expect(
        tag.key,
        tag.key.trim().toLowerCase(),
        reason: 'tag key "${tag.key}" must already be trimmed+lowercase',
      );
      expect(
        gatewayAllowedTags.contains(tag.key),
        isTrue,
        reason: 'tag key "${tag.key}" (label "${tag.label}") is not in the '
            'gateway JeebRatingVocabulary.AllowedTags taxonomy and would 400',
      );
    }
  });

  test('chip labels are non-empty and keys are unique', () {
    final keys = kMutualRatingTags.map((t) => t.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'duplicate tag key');
    for (final tag in kMutualRatingTags) {
      expect(tag.label.trim(), isNotEmpty);
    }
  });
}
