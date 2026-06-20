// home-disc-jeeber-feed-loading: the feed loading skeleton renders shimmer
// rows (OmdsListItemShimmer) instead of a bare spinner.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omds/omds.dart';

import 'package:jeeb_mobile/features/jeeber_request_feed/presentation/jeeber_feed_shimmer.dart';

void main() {
  testWidgets('JeeberFeedShimmer renders OmdsListItemShimmer rows',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: JeeberFeedShimmer(itemCount: 4)),
      ),
    );

    expect(find.byKey(JeeberFeedShimmer.shimmerKey), findsOneWidget);
    expect(find.byType(OmdsListItemShimmer), findsNWidgets(4));
    // It is NOT the old bare spinner.
    expect(find.byType(OmdsLoadingState), findsNothing);
  });
}
