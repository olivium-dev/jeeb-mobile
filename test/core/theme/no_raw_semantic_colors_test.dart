import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression guard for the sprint-009 color-role sweep (UX-AUDIT §T1/T2).
///
/// The files below were migrated from ad-hoc state coloring (brand `tertiary`
/// orange doing warning/success duty, `errorContainer` for recoverable
/// attention states, container roles used as text ink) onto the semantic
/// role layer (`context.jeebRoles.success/warning/info/...`).
///
/// This test greps those files so the old patterns cannot silently return.
/// When migrating a new screen onto `jeebRoles`, ADD it to [migratedFiles] —
/// do not weaken the forbidden patterns. If a migrated file genuinely needs
/// a brand-accent (non-state) tertiary usage again, remove it from the list
/// with a justification in the PR instead of special-casing here.
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
    // Journey 3 — wallet / settlement / history / auth
    'lib/features/wallet/presentation/wallet_hub_screen.dart',
    'lib/features/settlement/presentation/settlement_screen.dart',
    'lib/features/settlement/presentation/settlement_detail_screen.dart',
    'lib/features/settlement/presentation/widgets/settlement_status_pill.dart',
    'lib/features/order_history/presentation/order_status_chip.dart',
    // sign_up_screen.dart removed with the email/password funnel (JEBV4-199).
    'lib/features/prohibited_acknowledgment/presentation/prohibited_acknowledgment_dialog.dart',
    'lib/features/tier_selection/presentation/tier_selection_screen.dart',
    'lib/features/transcription/presentation/widgets/transcription_status_banner.dart',
  ];

  /// Patterns that indicate a regression to pre-sweep state coloring.
  final forbidden = <String, RegExp>{
    // Brand tertiary (orange) doing semantic-state duty. Tier/brand accents
    // live in JeebTierColors / explicit brand constants, never in these files.
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
}
