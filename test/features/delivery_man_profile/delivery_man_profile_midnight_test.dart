// M3-10 — per-element MIDNIGHT assertions for the delivery-man public profile.
//
// Goldens tolerate 5% pixel diff, so every ink here is read off the widget.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/theme/jeeb_semantic_colors.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_avatar.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_empty_state.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_midnight_field.dart';
import 'package:jeeb_mobile/core/widgets/jeeb_verified_badge.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_review_card.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

const _review = DeliveryReviewData(
  id: 'r1',
  reviewerName: 'Karl Assaf',
  rating: 4,
  body: 'Great delivery.',
  daysAgo: 2,
);

DeliveryManProfileViewData _data({List<DeliveryReviewData>? reviews}) =>
    DeliveryManProfileViewData(
      name: 'Kamal Hajj',
      rating: 4.3,
      reviewCount: 113,
      location: 'Lebanon',
      isAvailable: true,
      reviews: reviews ?? const <DeliveryReviewData>[_review],
    );

Widget _screen(DeliveryManProfileViewData data) => MaterialApp(
      theme: AppTheme.midnight(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Midnight primitives loop ∞ (02-STUDY-NOTES M0-4).
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: DeliveryManProfileScreen(data: data),
    );

/// The colour the framework will actually paint for [icon].
Color _iconInk(WidgetTester tester, Icon icon) =>
    icon.color ?? IconTheme.of(tester.element(find.byWidget(icon))).color!;

void main() {
  final JeebSemanticColors semantic = JeebSemanticColors.midnight();
  final ColorScheme scheme = AppTheme.midnight().colorScheme;

  testWidgets('mounts the still content field at the top-end glow anchor', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final JeebMidnightField field = tester.widget<JeebMidnightField>(
      find.byType(JeebMidnightField),
    );
    expect(field.variant, JeebFieldVariant.content);
    expect(field.glowPlacement, JeebFieldGlowPlacement.topEnd);
    // A wash is periwinkle and a glow is orange: this screen measures no wash.
    expect(field.washPlacement, isNull);
    expect(field.animateDecor, isFalse);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.transparent,
    );
  });

  testWidgets('identity disc is the R15 glass hero rung', (tester) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final JeebAvatar avatar = tester.widget<JeebAvatar>(
      find.byWidgetPredicate(
        (Widget w) =>
            w is JeebAvatar &&
            w.avatarKey == const Key('delivery-man-profile-avatar'),
      ),
    );
    expect(avatar.fill, JeebAvatarFill.glass);
    expect(avatar.diameter, JeebAvatar.heroDiameter);
  });

  testWidgets('name and section heading are onSurface, never the accent', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final Text name = tester.widget<Text>(find.text('Kamal Hajj'));
    expect(name.style!.color, scheme.onSurface);
    expect(name.style!.color, isNot(scheme.primary));

    final Text heading = tester.widget<Text>(find.text('Reviews'));
    expect(heading.style!.color, scheme.onSurface);
    expect(heading.style!.color, isNot(scheme.primary));
  });

  testWidgets('header meta lines run mutedText under a board-ink glyph', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final Text summary = tester.widget<Text>(find.text('4.3 . 113 Reviews'));
    expect(summary.style!.color, semantic.mutedText);

    // The aggregate star is board ink, not amber (§4.1) and not the accent.
    final Icon star = tester.widget<Icon>(
      find.descendant(
        of: find.bySemanticsIdentifier('profile_score'),
        matching: find.byIcon(Icons.star),
      ),
    );
    expect(_iconInk(tester, star), scheme.onSurface);
    expect(_iconInk(tester, star), isNot(semantic.amber));
  });

  testWidgets('review stars are amber over white-22%, with no hollow glyph', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final Finder stars = find.descendant(
      of: find.byType(DeliveryReviewCard),
      matching: find.byWidgetPredicate((Widget w) => w is Icon),
    );
    final List<Icon> icons = tester.widgetList<Icon>(stars).toList();
    expect(icons, hasLength(5));
    // The board never draws a hollow star (R15).
    expect(icons.map((Icon i) => i.icon), everyElement(Icons.star));
    for (int i = 0; i < 4; i++) {
      expect(_iconInk(tester, icons[i]), semantic.amber, reason: 'star $i');
    }
    expect(_iconInk(tester, icons[4]), semantic.glassBorderVivid);
  });

  testWidgets('review body inks come off the Midnight ramp', (tester) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final Text reviewer = tester.widget<Text>(find.text('Karl'));
    expect(reviewer.style!.color, scheme.onSurface);
    final Text ago = tester.widget<Text>(find.text('2 days ago'));
    expect(ago.style!.color, semantic.mutedText);
  });

  testWidgets('no-reviews band is the compact parcel empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _screen(_data(reviews: const <DeliveryReviewData>[])),
    );
    await tester.pumpAndSettle();

    final JeebEmptyState empty = tester.widget<JeebEmptyState>(
      find.byKey(const Key('delivery-man-profile-reviews-empty')),
    );
    expect(empty.variant, JeebEmptyStateVariant.parcel);
    expect(empty.compact, isTrue);
    expect(empty.status, JeebEmptyStateStatus.empty);
  });

  testWidgets('the trust badge is re-inked so it survives the field', (
    tester,
  ) async {
    await tester.pumpWidget(_screen(_data()));
    await tester.pumpAndSettle();

    final Icon badge = tester.widget<Icon>(
      find.descendant(
        of: find.byType(JeebVerifiedBadge),
        matching: find.byIcon(Icons.verified),
      ),
    );
    expect(_iconInk(tester, badge), scheme.onSurface);
    // Raised navy on navy is the invisible reading it defaults to.
    expect(_iconInk(tester, badge), isNot(scheme.secondaryContainer));
  });
}
