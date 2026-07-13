// JEBV4-297 — wire-contract guard for the mutual-rating tag taxonomy.
//
// Root cause of the RATING-400: the screen used to send its DISPLAY LABELS
// ('Punctual'/'Careful'/'Friendly'/'Fast') as the on-the-wire `tags[]`. The
// gateway (JeebRatingVocabulary.BuildTags) lowercases each tag and rejects any
// value outside its taxonomy with a 400, so selecting ANY tag made
// POST /v1/ratings/jeeb/submit fail on both mutual-rating attempts.
//
// This test locks the chip keys to the gateway `JeebRatingVocabulary.AllowedTags`
// whitelist so the mismatch cannot silently regress.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/rating/presentation/mutual_rating_screen.dart';

void main() {
  // Mirrors gateway src/JeebGateway/Ratings/Jeeb/JeebRatingVocabulary.cs
  // `AllowedTags`. The gateway lowercases each submitted tag before this check.
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
      // check, so the wire key must survive that normalisation unchanged.
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
