import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the sprint-009 color-role sweep (UX-AUDIT §T1/T2).
/// The files below were migrated from ad-hoc state coloring (brand `tertiary`
void main() {
  /// Feature files migrated onto the semantic role layer.
  const migratedFiles = <String>[
    // Journey 1 — request compose + offer flow
    'lib/features/client_offers/presentation/widgets/offer_window_timer.dart',
    'lib/features/offer_kyc_gate/presentation/offer_kyc_gate_screen.dart',
    'lib/features/no_offer_timeout/presentation/no_offer_timeout_screen.dart',
    'lib/features/home_client/presentation/tabs/pending_requests_tab.dart',
    // Journey 2 — jeeber dashboard / feed / delivery / dispute
    'lib/features/jeeber_request_feed/presentation/request_feed_screen.dart',
    'lib/features/jeeber_home/presentation/widgets/inactivity_warning_banner.dart',
    'lib/features/jeeber_home/presentation/widgets/jeeber_feed_tab_view.dart',
    'lib/features/delivery_status/presentation/widgets/delivery_lifecycle_banner.dart',
    'lib/features/dispute_status/presentation/dispute_status_screen.dart',
    'lib/features/offline_mode/presentation/offline_banner.dart',
    // Journey 3 — wallet / history / auth
    'lib/features/wallet/presentation/wallet_hub_screen.dart',
    // MIDNIGHT M3-11..14: the rest of the wallet journey, added with the
    // restyle that took `colorScheme.primary` off eight non-CTA elements.
    'lib/features/wallet/presentation/wallet_activity_list_screen.dart',
    'lib/features/wallet/presentation/widgets/wallet_activity_row.dart',
    'lib/features/wallet/presentation/transaction_detail_screen.dart',
    'lib/features/wallet/presentation/wallet_charge_info_screen.dart',
    'lib/features/wallet/presentation/customer_wallet_stub_screen.dart',
    // settlement_screen/_detail_screen/settlement_status_pill removed with the
    // ratified M3-15/16 orphan deletion (02-STUDY-NOTES §ORPHAN, owner Q9).
    'lib/features/order_history/presentation/order_status_chip.dart',
    // MIDNIGHT M3-31: the all-reviews list, added with the restyle that took
    // `colorScheme.primary` off six per-row non-CTA elements and the aggregate.
    'lib/features/reviews/presentation/reviews_list_screen.dart',
    'lib/features/reviews/presentation/widgets/review_row.dart',
    // sign_up_screen.dart removed with the email/password funnel (JEBV4-199).
    'lib/features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart',
    'lib/features/tier_selection/presentation/tier_selection_screen.dart',
    'lib/features/transcription/presentation/widgets/transcription_status_banner.dart',
  ];

  /// Patterns that indicate a regression to pre-sweep state coloring.
  final forbidden = <String, RegExp>{
    // Brand tertiary (orange) doing semantic-state duty. Tier/brand accents
    'M3 tertiary role': RegExp(r'\.(tertiary|tertiaryContainer|onTertiary\w*)\b'),
    // Raw hex literals — everything must resolve through a role or token.
    'raw Color(0x...) literal': RegExp(r'Color\(0x'),
    // Material palette constants as semantic state colors.
    'Colors.* palette state color': RegExp(
      r'Colors\.(red|green|amber|orange|yellow|blue|teal|lime)\b',
    ),
    // Container fill roles used as text ink on plain surfaces.
    'container role used as ink': RegExp(
      r'color:\s*\w+\.colorScheme\.(secondaryContainer|primaryContainer)\s*,\s*\n\s*fontWeight',
    ),
  };

  group('no raw semantic colors in migrated files', () {
    for (final path in migratedFiles) {
      test(path, () {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: '$path was moved/deleted — update no_raw_semantic_colors_test.dart');
        final source = file.readAsStringSync();
        for (final entry in forbidden.entries) {
          final match = entry.value.firstMatch(source);
          expect(
            match,
            isNull,
            reason: '$path regressed the color-role sweep: found '
                '"${match?.group(0)}" (${entry.key}). Use context.jeebRoles '
                '(success/warning/info/error pairs) or the correct M3 role '
                'pair instead — see lib/core/theme/jeeb_color_roles.dart.',
          );
        }
      });
    }
  });

  // ── MIDNIGHT M6: the app-wide raw-hex gate, with NAMED exemptions ────────
  //
  // The allowlist above only guards the files it lists. This group is the
  // complement: EVERY `Color(0x…)` under `lib/` outside `lib/core/theme/` must
  // belong to a declared exemption, so a new literal anywhere else fails here
  // rather than waiting for someone to add its file to `migratedFiles`.
  //
  // Fable's M6 ruling: the gate asserts "≤5 hex outside theme, all in
  // social_sign_in_button.dart" — NOT a plain zero. Those five are third-party
  // identity brand marks (#4285F4 Google, #1877F2 Facebook, white ×3) required
  // by Apple App Store review item 4.0 and the Google Identity branding
  // guidelines; the file carries the rationale and JEEB-57. They are not
  // themeable and re-pointing them would breach both platforms' review rules.
  group('raw hex outside lib/core/theme is exempt-only', () {
    /// path → the exact number of `Color(0x…)` literals sanctioned there.
    ///
    /// The gate is one-directional: a file may drop BELOW its declared count
    /// (someone removed a literal — good), never above, and a file that is not
    /// a key here may have none at all. So the ledger can only tighten.
    const exemptions = <String, int>{
      // Fable's named M6 exemption. Brand-locked, permanent (JEEB-57).
      'lib/features/auth/social/social_sign_in_button.dart': 5,
      // `JeebStepper.washedInk` — white 35%, deliberately OFF the 7/10/14
      // glass ladder (wave-C ruling 11). Owned by the M6 core-kit lane, which
      // is re-homing it into the palette; declared so this gate does not go
      // red on another lane's in-flight work, and it may drop to zero.
      'lib/core/widgets/jeeb/jeeb_stepper.dart': 1,
    };

    /// Excluded from the scan, not exempted: these ARE the token layer.
    bool isTokenLayer(String path) =>
        path.startsWith('lib/core/theme/');

    final hexLiteral = RegExp(r'Color\(0x');

    late final Map<String, int> found;

    setUpAll(() {
      found = <String, int>{};
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path;
        if (isTokenLayer(path)) continue;
        final count =
            hexLiteral.allMatches(entity.readAsStringSync()).length;
        if (count > 0) found[path] = count;
      }
    });

    test('every raw-hex file is a declared exemption', () {
      final undeclared = found.keys
          .where((path) => !exemptions.containsKey(path))
          .toList()
        ..sort();
      expect(
        undeclared,
        isEmpty,
        reason: 'raw Color(0x…) literals outside lib/core/theme/ in files with '
            'no declared exemption: $undeclared. Resolve them through a token '
            '(JeebMidnight / JeebSemanticColors / JeebColorRoles / '
            'ColorScheme). If a literal is genuinely brand-locked, it needs a '
            'Fable ruling and an entry in `exemptions` above — not a silent '
            'addition.',
      );
    });

    test('no exemption exceeds its declared count', () {
      for (final entry in found.entries) {
        final declared = exemptions[entry.key];
        if (declared == null) continue;
        expect(
          entry.value,
          lessThanOrEqualTo(declared),
          reason: '${entry.key} now has ${entry.value} raw hex literals but is '
              'only exempt for $declared. New literals in an exempt file are '
              'still regressions.',
        );
      }
    });

    test('the social brand marks are exactly the 5 Fable sanctioned', () {
      const path = 'lib/features/auth/social/social_sign_in_button.dart';
      expect(
        found[path],
        5,
        reason: 'The M6 gate is "≤5 hex outside theme, all in '
            'social_sign_in_button.dart". A different count means either a new '
            'literal crept in or the brand marks were "fixed" — re-read the '
            'EXEMPT block in that file and JEEB-57 before changing this.',
      );
      // Pins WHICH hexes, so swapping Google blue for an arbitrary value
      // cannot pass a count-only check.
      final source = File(path).readAsStringSync();
      for (final brand in const <String>[
        '0xFF4285F4', // Google Blue 500
        '0xFF1877F2', // Facebook Brand Blue
        '0xFFFFFFFF', // glyph foregrounds (Google / Facebook / Apple)
      ]) {
        expect(source, contains(brand),
            reason: '$brand is brand-required and must not be re-pointed.');
      }
    });

    test('the exemption ledger names no file that is already clean-by-path',
        () {
      for (final path in exemptions.keys) {
        expect(isTokenLayer(path), isFalse,
            reason: '$path is already excluded as the token layer; listing it '
                'as an exemption is dead ledger.');
      }
    });
  });
}
