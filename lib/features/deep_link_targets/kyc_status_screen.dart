import 'package:flutter/material.dart';

import '../../core/widgets/jeeb/jeeb_empty_state.dart';
import '../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../devtool/catalog/fixtures/kyc_status_screen_fixtures.dart';
import '../../core/previews/jeeb_preview.dart';
import '../../l10n/app_localizations.dart';
import '../kyc/presentation/widgets/kyc_state_art.dart';

class KycStatusScreen extends StatefulWidget {
  const KycStatusScreen({super.key});

  @override
  State<KycStatusScreen> createState() => _KycStatusScreenState();
}

class _KycStatusScreenState extends State<KycStatusScreen> {
  static const _featureId = 'kyc-status';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Deliberately still a STUB: `kycStatusPlaceholder` says the status will
    // appear here, which is the honest reading of an unbuilt deep-link target.
    return JeebMidnightField(
      variant: JeebFieldVariant.content,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: JeebEmptyState(
                // The same art the real KYC funnel draws, so the deep-link
                // target and its destination read as one thing.
                variant: kycStateVariant,
                medallions: kycStateMedallions,
                center: const KycStateMark(),
                identifier: 'deep_link_kyc_status_root',
                semanticLabel:
                    '${l10n.kycStatusTitle}. ${l10n.kycStatusPlaceholder}',
                headline: l10n.kycStatusTitle,
                body: l10n.kycStatusPlaceholder,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
const Size _kycStatusScreenPhoneCanvas = Size(402, 888);

/// The smallest display the app is still expected to look right on.
const Size _kycStatusScreenCompactCanvas = Size(332, 612);

/// A notched phone (iPhone 15 Pro class) in portrait.
const Size _kycStatusScreenNotchedCanvas = Size(405, 896);

/// Every state is the same screen in a different window — see the fixture.
/// The `const KycStatusScreen()` is constructed HERE rather than inside the
Widget _kycStatusScreenHosted(KycStatusScreenWindow window) =>
    KycStatusScreenPreviewHost(
      window: window,
      screen: const KycStatusScreen(),
    );

@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone 390 × 844',
  size: _kycStatusScreenPhoneCanvas,
  matrix: true,
)
Widget kycStatusScreenPhone() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.phone);

@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact 320 × 568',
  size: _kycStatusScreenCompactCanvas,
)
Widget kycStatusScreenCompact() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.compact);

@JeebPreview(
  group: 'deep_link_targets',
  name: 'Phone · 200% text',
  size: _kycStatusScreenPhoneCanvas,
)
Widget kycStatusScreenPhoneLargeText() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.phoneLargeText);

@JeebPreview(
  group: 'deep_link_targets',
  name: 'Compact · 200% text',
  size: _kycStatusScreenCompactCanvas,
)
Widget kycStatusScreenCompactLargeText() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.compactLargeText);

@JeebPreview(
  group: 'deep_link_targets',
  name: 'Notched · 200% text',
  size: _kycStatusScreenNotchedCanvas,
)
Widget kycStatusScreenNotchedLargeText() =>
    _kycStatusScreenHosted(KycStatusScreenWindows.notchedLargeText);
