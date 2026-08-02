// Structural guardrails for widget previews.
//
// Previews live at the BOTTOM of the widget's own source file, below a banner,
// because `flutter widget-preview start` filters the canvas by the file the
// preview is DECLARED in — see `lib/core/previews/README.md`. That buys the IDE
// panel, and it costs a boundary: preview code and shipping code are now in the
// same file, so "previews never leak into production" can no longer be enforced
// by a directory rule.
//
// These seven invariants are the replacement. They are strictly stronger than
// the import check they replace, because they work on REFERENCES rather than on
// file paths: a fixture that leaks is caught even though it is one scroll away
// from the widget that would use it.
//
// The detector is shared verbatim with `tool/preview_coverage.dart` — see
// `tool/preview_inventory.dart`. Two copies of this parsing drifted once
// already; one implementation, two callers.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports — `tool/` is not a package; this relative
// import is what keeps the detector single-sourced with the CLI.
import '../../tool/preview_inventory.dart';

/// Maximum number of uncovered widgets allowed. Lower it as previews land —
/// never raise it. A widget whose previews are dropped or misnamed fails here
/// immediately, which is the point.
///
/// The WIDGET queue reached ZERO in the wave that previewed
/// `RecentReviewsSection`, `SuperLoginEntryPoints`, `ReviewRow`, `TierCard`,
/// `AnimatedMicButton` and `WalletActivityRow` (150/150). The floor then went
/// back up because the detector stopped excluding `*Screen` — that 100% was 150
/// of 231 — so what is left in the queue is screens, and each screen wave walks
/// this number down. The ratchet is unchanged: a new widget or screen under
/// `lib/features/**` fails this test until it ships with a preview section, or
/// is deliberately listed in `tool/preview_exclusions.txt` with a reason.
/// Raising this number is not the fix for either.
///
/// 74 → 67: the screens wave that previewed `CustomerWalletStubScreen`,
/// `TransactionDetailScreen`, `WalletActivityListScreen`,
/// `WalletChargeInfoScreen`, `WalletHubScreen`, `ChatDetailScreen` and
/// `DeliveryDetailScreen` (163/231).
///
/// 67 → 60: the screens wave that previewed `NotificationPreferencesScreen`,
/// `ProfileEditScreen`, `SavedAddressesScreen`, `SettingsScreen`,
/// `DiagnosticsScreen`, `ProfileUnavailableScreen` and `KycStatusScreen`
/// (170/231).
///
/// 60 → 53: the screens wave that previewed `JeeberRequestDetailScreen`,
/// `JeeberRequestUnavailableScreen`, `LocationPickerScreen`,
/// `DeliveryRegisterPromptScreen`, `OfferKycGateScreen`, `MutualRatingScreen`
/// and `RatingScreen` (177/231).
///
/// 53 → 46: the screens wave that previewed `OtpVerificationScreen`,
/// `RegistrationScreen`, `RequestSummaryScreen`,
/// `RequestSummaryUnavailableScreen`, `SettlementDetailScreen`,
/// `SettlementScreen` and `VoiceRecordingScreen` (184/231).
///
/// 46 → 39: the screens wave that previewed `AccountStatusScreen`,
/// `ActiveDeliveryJeeberScreen`, `SetPasswordScreen`, `BiometricLockScreen`,
/// `BiometricPromptScreen`, `CancellationScreen` and `DevChatPreviewScreen`
/// (191/231).
///
/// 39 → 32: the screens wave that previewed `ClientOffersScreen`,
/// `ClientUnreachableScreen`, `CustomerProfileScreen`, `RatingPromptScreen`,
/// `DeliveryManProfileScreen`, `DeliveryReceiptScreen` and
/// `DeliveryStatusScreen` (198/231).
///
/// 32 → 25: the screens wave that previewed `DisputeStatusScreen`,
/// `EarningsDashboardScreen`, `EscalateScreen`, `GoodsCostScreen`,
/// `JeeberHomeScreen`, `DmOnboardingScreen` and `OnboardingFundingScreen`
/// (205/231). The remaining 25 are all screens; `LiveSettingsScreen` is the
/// one BLOCKED entry and does not count here — it needs a production seam
/// first, recorded in `tool/preview_blocked.txt`.
///
/// 25 → 18: the screens wave that previewed `JeeberPendingOffersScreen`,
/// `RequestFeedScreen`, `KycWizardScreen`, `KycRejectedScreen`,
/// `LanguageSettingsScreen`, `LiveTrackingScreen` and the `/location`
/// `LocationPickerScreen` (212/231). Note the last one is the SECOND class of
/// that name: the wave at 60 → 53 previewed
/// `features/location/presentation/location_picker_screen.dart`, the 461-line
/// implementation the Screen Catalog renders, while the router serves the
/// 36-line placeholder at `presentation/screens/` — so both files count, and
/// only now does opening the one the app actually mounts show the truth. See
/// `docs/previews/FINDING_location_picker_placeholder.md`.
///
/// 18 → 11: the screens wave that previewed `NoOfferTimeoutScreen`,
/// `NotificationPrefsScreen`, `NotificationsListScreen`,
/// `OfferSubmissionScreen`, `OnboardingScreen`, `OrderHistoryScreen` and
/// `OrderSummaryScreen` (219/231). All seven extracted their catalog fixtures
/// into `lib/devtool/catalog/fixtures/` and repointed both surfaces; the
/// Screen Catalog is unchanged at 89 screens / 288 states, entry-for-entry and
/// label-for-label. The remaining 11 are all screens; `LiveSettingsScreen` is
/// still the one BLOCKED entry and does not count here.
///
/// 11 → 4: the screens wave that previewed `OtpHandoverScreen`,
/// `PasswordSecurityScreen`, `DisplayNameSetupScreen`,
/// `ProhibitedItemReportScreen`, `RequestTypeScreen`, `ReviewsListScreen` and
/// `ShellScreen` (226/231). All seven extracted their catalog fixtures into
/// `lib/devtool/catalog/fixtures/` and repointed both surfaces; the Screen
/// Catalog is unchanged at 89 screens / 288 states, entry-for-entry and
/// label-for-label. The remaining 4 are all screens — `SupportTicketScreen`,
/// `TierSelectionScreen`, `TranscriptionScreen`, `VoiceRequestScreen` — and
/// `LiveSettingsScreen` is still the one BLOCKED entry, which does not count
/// here.
const int _coverageFloor = 4;

/// Whole-word identifier match — `_hosted` must not match `_hostedFoo`.
bool _referencesName(String haystack, String name) => RegExp(
      r'(?<![A-Za-z0-9_$])' + RegExp.escape(name) + r'(?![A-Za-z0-9_$])',
    ).hasMatch(haystack);

void main() {
  final PreviewInventory inventory = PreviewInventory.scan();

  test('INV-1 · lib/previews/ does not exist', () {
    final dir = Directory('lib/previews');
    final List<String> leftovers = dir.existsSync()
        ? dir.listSync(recursive: true).map((FileSystemEntity e) => e.path).toList()
        : const <String>[];

    expect(
      dir.existsSync(),
      isFalse,
      reason: 'Previews now live in the widget file they belong to, and the '
          'harness lives at $harnessPath. Nothing may remain under '
          'lib/previews/:\n${leftovers.join('\n')}',
    );
  });

  test('INV-2 · the harness is imported only by files with a preview section', () {
    final offenders = <String>[];
    final stale = <String>[];

    for (final SourceFile file in inventory.files) {
      if (file.path.startsWith('lib/core/previews/')) continue;
      final String source = file.rawLines.join('\n');

      // Nothing may reach for the retired tree, at any path spelling.
      if (source.contains('previews/harness/') ||
          source.contains('package:jeeb_mobile/previews/')) {
        stale.add(file.path);
      }

      final bool importsHarness =
          source.contains('core/previews/jeeb_preview.dart') ||
              source.contains('package:jeeb_mobile/core/previews/');
      if (importsHarness && !file.hasPreviewSection) offenders.add(file.path);
    }

    expect(
      stale,
      isEmpty,
      reason: 'These files import the retired lib/previews/ tree, which no '
          'longer exists:\n${stale.join('\n')}',
    );
    expect(
      offenders,
      isEmpty,
      reason: 'These files import the preview harness but have no JEEB PREVIEWS '
          'section — an import left behind after the previews were deleted. '
          'Remove it:\n${offenders.join('\n')}',
    );
  });

  test('INV-3 · no @JeebPreview above a banner, and one banner per file', () {
    final offenders = <String>[];

    for (final SourceFile file in inventory.files) {
      if (file.bannerLines.length > 1) {
        offenders.add('${file.path}: ${file.bannerLines.length} banners — a '
            'file gets ONE section even when it previews several widgets');
      }
      final List<int> annotations = file.previewAnnotationLines;
      if (annotations.isEmpty) continue;
      if (!file.hasPreviewSection) {
        offenders.add('${file.path}: has @JeebPreview but no banner');
        continue;
      }
      for (final int line in annotations) {
        if (line < file.bannerIndex) {
          offenders.add('${file.path}:${line + 1}: @JeebPreview above the banner');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('INV-4 · nothing above a banner references anything below it', () {
    final offenders = <String>[];

    for (final SourceFile file in inventory.previewSections) {
      final String shipping = file.codeAboveBanner;
      for (final SectionDeclaration decl in file.sectionDeclarations) {
        if (_referencesName(shipping, decl.name)) {
          offenders.add('${file.path}: production code above the banner '
              'references `${decl.name}`, declared at line ${decl.line + 1}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'A preview fixture is now reachable from shipping code, so it is '
          'no longer tree-shaken and a dev-only fixture ships to users:\n'
          '${offenders.join('\n')}',
    );
  });

  test('INV-5 · nothing below a banner is referenced from another library', () {
    // Preview functions are public because the SDK requires it
    // (`_PreviewVisitor.visitFunctionDeclaration` drops private ones), so
    // privacy does not protect them. `test/` is exempt — that is where they are
    // legitimately called.
    final offenders = <String>[];

    for (final SourceFile file in inventory.previewSections) {
      for (final SectionDeclaration decl in file.sectionDeclarations) {
        final RegExp reference = RegExp(
          r'(?<![A-Za-z0-9_$])' + RegExp.escape(decl.name) + r'(?![A-Za-z0-9_$])',
        );
        for (final SourceFile other in inventory.files) {
          if (identical(other, file)) continue;
          if (reference.hasMatch(other.codeText)) {
            offenders.add('${other.path} references `${decl.name}`, which is '
                'preview-only code in ${file.path}');
          }
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('INV-6 · every name below a banner is widget-prefixed, and public only '
      'when a test needs it', () {
    final String testSources = Directory('test')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .map((File f) => f.readAsStringSync())
        .join('\n');

    final unprefixed = <String>[];
    final gratuitouslyPublic = <String>[];

    for (final SourceFile file in inventory.previewSections) {
      final Set<String> previewNames =
          file.previewFunctions.map((PreviewFunction p) => p.name).toSet();

      for (final SectionDeclaration decl in file.sectionDeclarations) {
        // §3.4: `_clientHomeGreetingHosted`, `_ClientHomeTierBadgeActiveHeader`,
        // `clientHomeGreetingNamed`. Strip the privacy underscore, then match
        // either spelling of a widget name declared in THIS file. This is what
        // lets one file merge previews for three widgets without collisions —
        // 232 preview files each used to declare a bare `_hosted`.
        final String bare =
            decl.name.startsWith('_') ? decl.name.substring(1) : decl.name;
        final bool prefixed = file.widgetClasses.any(
          (String w) =>
              hasNamePrefix(bare, lowerCamel(w)) || hasNamePrefix(bare, w),
        );
        if (!prefixed) {
          unprefixed.add('${file.path}:${decl.line + 1}: `${decl.name}` is not '
              'prefixed with a widget name from this file '
              '(${file.widgetClasses.where((String w) => !w.startsWith('_')).join(', ')})');
        }

        if (decl.isPrivate || previewNames.contains(decl.name)) continue;
        if (!_referencesName(testSources, decl.name)) {
          gratuitouslyPublic.add('${file.path}:${decl.line + 1}: '
              '`${decl.name}` is public but no test uses it — make it private');
        }
      }
    }

    expect(unprefixed, isEmpty, reason: unprefixed.join('\n'));
    expect(gratuitouslyPublic, isEmpty, reason: gratuitouslyPublic.join('\n'));
  });

  test('INV-7 · preview coverage does not regress', () {
    final List<WidgetCoverage> results = inventory.coverage();

    List<WidgetCoverage> of(CoverageVerdict v) =>
        results.where((WidgetCoverage r) => r.verdict == v).toList();

    final List<WidgetCoverage> malformed = of(CoverageVerdict.malformed);
    final List<WidgetCoverage> uncovered = of(CoverageVerdict.uncovered);

    // MALFORMED is a widget with one half of a preview section and not the
    // other — a section that builds it but has no preview named after it, or
    // previews named after it that never build it. Almost always a half-applied
    // edit, and it must not be able to hide inside the floor.
    expect(
      malformed.map((WidgetCoverage r) => '${r.widget.name} '
          '(${r.widget.path}): ${r.reason}'),
      isEmpty,
      reason: 'Half-finished preview sections. Run: '
          'dart run tool/preview_coverage.dart',
    );

    expect(
      uncovered.length,
      lessThanOrEqualTo(_coverageFloor),
      reason: 'Preview coverage regressed: ${uncovered.length} widgets have no '
          'preview but the floor is $_coverageFloor. Either add the missing '
          'previews or lower the floor if widgets were deleted.\n'
          'Run: dart run tool/preview_coverage.dart\n'
          '${uncovered.map((WidgetCoverage r) => '  ${r.widget.name} '
              '(${r.widget.path})').join('\n')}',
    );
  });
}
