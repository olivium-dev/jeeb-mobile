import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../devtool/catalog/fixtures/prohibited_item_report_screen_fixtures.dart';
import '../../../core/previews/jeeb_preview.dart';

class ProhibitedItemReportScreen extends StatefulWidget {
  const ProhibitedItemReportScreen({
    super.key,
    required this.requestId,
    this.initialDescription,
  });
  final String requestId;

  final String? initialDescription;

  @override
  State<ProhibitedItemReportScreen> createState() =>
      _ProhibitedItemReportScreenState();
}

class _ProhibitedItemReportScreenState
    extends State<ProhibitedItemReportScreen> {
  late final _descriptionController =
      TextEditingController(text: widget.initialDescription);

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const OMDSAppBar(title: 'Report Prohibited Item'),
      body: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _WarningCard(),
            const SizedBox(height: Spacing.medium),
            OmdsTextField(
              controller: _descriptionController,
              labelText: 'Describe the prohibited item',
              maxLines: 4,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Spacing.medium),
            OmdsPrimaryButton(
              text: 'Attach Photo',
              variant: OmdsButtonVariant.outlined,
              icon: const Icon(Icons.camera_alt),
              onTap: () {},
            ),
            const Spacer(),
            OmdsPrimaryButton(
              text: 'Report Item',
              isEnabled: _descriptionController.text.isNotEmpty,
              backgroundColor: Theme.of(context).colorScheme.error,
              onTap: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Row(
          children: [
            Icon(Icons.warning, color: theme.colorScheme.error),
            const SizedBox(width: Spacing.small),
            Expanded(
              child: Text(
                'If the Client requested delivery of a prohibited item, '
                'report it here.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The reference phone this screen is designed against.
const Size _prohibitedItemReportScreenPhoneBox = Size(390, 844);

/// The narrowest phone the app still supports.
const Size _prohibitedItemReportScreenCompactBox = Size(320, 568);

/// A notched phone, whose home indicator the body has to clear on its own.
const Size _prohibitedItemReportScreenNotchedBox = Size(393, 852);

/// Builds the screen the way a route would build it — an id and an optional
/// seeded description — inside the shared captioned window.
Widget _prohibitedItemReportScreenHosted(
  ProhibitedItemReportScreenCase state,
) {
  return ProhibitedItemReportScreenPreviewHost(
    state: state,
    screen: ProhibitedItemReportScreen(
      requestId: ProhibitedItemReportScreenPreviewFixtures.requestId,
      initialDescription: state.description,
    ),
  );
}

/// The cold form: nothing typed, so `Report Item` sits at 45% opacity and the
/// field's label is still resting inside the box rather than floating above it.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Empty · Report disabled',
  size: _prohibitedItemReportScreenPhoneBox,
  matrix: true,
)
Widget prohibitedItemReportScreenEmpty() => _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.empty,
    );

/// One plausible line typed: the label has floated, and the destructive CTA is
/// at full error-red.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Filled · Report armed',
  size: _prohibitedItemReportScreenPhoneBox,
)
Widget prohibitedItemReportScreenFilled() => _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.filled,
    );

/// The layout ceiling on the reference phone: a paragraph in a box that shows
/// four lines.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Longest · paragraph in a 4-line box',
  size: _prohibitedItemReportScreenPhoneBox,
)
Widget prohibitedItemReportScreenLongest() => _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.longest,
    );

/// The same paragraph on the narrowest phone the app supports.
/// The second matrix state: at 320 pt the warning card's sentence takes three
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Longest · compact 320',
  size: _prohibitedItemReportScreenCompactBox,
  matrix: true,
)
Widget prohibitedItemReportScreenLongestCompact() =>
    _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.longestCompact,
    );

/// A jeeber in Beirut typing the report in Arabic.
/// The content is RTL and the chrome is English, so the card shows both
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Arabic report · English chrome',
  size: _prohibitedItemReportScreenPhoneBox,
)
Widget prohibitedItemReportScreenArabicContent() =>
    _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.arabic,
    );

/// Three spaces in the field, and the destructive CTA is armed.
/// `isEnabled: _descriptionController.text.isNotEmpty` never trims, so this
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Whitespace only · armed anyway',
  size: _prohibitedItemReportScreenPhoneBox,
)
Widget prohibitedItemReportScreenWhitespaceOnly() =>
    _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.whitespaceOnly,
    );

/// A notched phone: 59 pt of status bar at the top, 34 pt of home indicator at
/// the bottom.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Notched · CTA under the home indicator',
  size: _prohibitedItemReportScreenNotchedBox,
)
Widget prohibitedItemReportScreenNotched() => _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.notched,
    );

/// The state the jeeber is actually in for the whole time this screen matters:
/// a small phone with the keyboard up.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Typing · keyboard up, body overflows',
  size: _prohibitedItemReportScreenCompactBox,
)
Widget prohibitedItemReportScreenKeyboardOpen() =>
    _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.keyboardOpen,
    );
