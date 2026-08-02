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
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/prohibited_item_report/prohibited_item_report_screen_preview_test.dart
// ===========================================================================
//
// [ProhibitedItemReportScreen] is the jeeber's "the client asked me to carry
// something I am not allowed to carry" form: a warning card, a free-text
// description, an Attach-Photo affordance and a destructive Report CTA.
//
// The designed states, the captions and the device windows are NOT declared
// here. They live in
// `lib/devtool/catalog/fixtures/prohibited_item_report_screen_fixtures.dart`,
// shared with the on-device Screen Catalog entry for this screen
// (`devtool/catalog/entries/batch_09_entries.dart`), so the designer's in-app
// browser and this canvas cannot drift into showing two different "designed
// states".
//
// ## There is no loading state and no error state, and that is not an omission
//
// This screen has no repository, no cubit, no future and no DI lookup. Its
// entire model is one [TextEditingController]; its entire action is
// `Navigator.of(context).pop(true)`, which happens in the same frame as the
// tap. Nothing can be in flight, so nothing can be pending; nothing is called,
// so nothing can fail. The axes that DO exist are the description text and the
// viewport, and those are what the eight states below cover. Network-free by
// construction, not by the guard in [jeebPreviewHost].
//
// ## Three things about this harness worth knowing before editing it
//
//  * **The screen owns a Scaffold and [jeebPreviewHost] supplies another.**
//    They nest: the host's `Scaffold + SafeArea` frames the card and the
//    screen's own `Scaffold + OMDSAppBar` paints inside it. That is the same
//    nesting the Screen Catalog produces.
//  * **The frame is pinned in the TREE, not just in `size:`.** The `size:` on
//    [JeebPreview] boxes the canvas; [ProhibitedItemReportScreenPreviewHost]
//    pins the same window in the widget tree — inside a pair of unbounded
//    scroll views, so an 844 pt frame stays 844 pt instead of being clamped to
//    the render tests' 600 pt surface.
//  * **Each card carries a caption, and the caption is the pin.** The screen
//    renders five hardcoded English strings and nothing else, so most of these
//    states share every pixel of chrome. Without the caption there is no string
//    that says WHICH designed state a card is showing, and the render test
//    could only assert that something drew.
//
// ## What these previews show that no test showed before
//
//  * **Not one string on this screen is localized.** `Report Prohibited Item`,
//    `Describe the prohibited item`, `Attach Photo`, `Report Item` and the
//    warning sentence are all Dart literals — the file does not import
//    `AppLocalizations` at all. [prohibitedItemReportScreenEmpty] carries
//    `matrix: true` so the Arabic card sits beside the English one: the layout
//    mirrors, and the copy does not translate.
//  * **The description the jeeber types is thrown away.** `Report Item` pops
//    `true` — a bool, not the text — and `requestId` is never read by `build`
//    at all. Nothing on this screen reaches
//    [ProhibitedItemReportService.report], and no `GoRoute` builds this screen
//    anywhere in `app_router.dart`, so nothing reaches the screen either.
//  * **The Report gate does not trim.** `_descriptionController.text
//    .isNotEmpty` arms a destructive CTA on three spaces — see
//    [prohibitedItemReportScreenWhitespaceOnly], which is visually
//    indistinguishable from the empty state and yet is armed.
//  * **`Attach Photo` is wired to `onTap: () {}`.** Every card below shows a
//    fully styled affordance that cannot do anything.
//  * **The body is a non-scrolling `Column` with a `Spacer()` in it.** That is
//    fine on a big phone with the keyboard down, and it is the whole problem
//    the moment either of those stops being true — see
//    [prohibitedItemReportScreenKeyboardOpen], whose render test asserts the
//    overflow rather than pretending it away.

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
///
/// This is the one the matrix is for, and not because the layout is delicate.
/// Put the Arabic card next to the English one and the screen mirrors
/// perfectly while every word stays in English — the app ships 1534 keys in
/// both locales and this screen uses none of them.
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
///
/// Worth noticing what arming it does NOT require — no photo, no category, no
/// confirmation step. One tap on a red button ends the screen.
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
///
/// `OmdsTextField(maxLines: 4)` stops growing at four lines and scrolls
/// internally, with no scrollbar and no affordance saying there is more. The
/// jeeber who wrote the most detail is the one who can least review it before
/// tapping the red button.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Longest · paragraph in a 4-line box',
  size: _prohibitedItemReportScreenPhoneBox,
)
Widget prohibitedItemReportScreenLongest() => _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.longest,
    );

/// The same paragraph on the narrowest phone the app supports.
///
/// The second matrix state: at 320 pt the warning card's sentence takes three
/// lines instead of two, and at 200% text the whole non-scrolling column has to
/// find that room somewhere. Read the AR and 200% cards, not the English one —
/// the English stays plausible long after the other two have stopped fitting.
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
///
/// The content is RTL and the chrome is English, so the card shows both
/// directions at once: an LTR app-bar title and LTR button labels above a field
/// whose text runs the other way. This is the realistic content case for this
/// screen — the people who file these reports are the same drivers the AR
/// locale exists for.
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
///
/// `isEnabled: _descriptionController.text.isNotEmpty` never trims, so this
/// card is pixel-for-pixel the empty state with a live red button on it. Put it
/// beside [prohibitedItemReportScreenEmpty]: the only difference a reviewer can
/// see is the one that matters, and it is the wrong way round.
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
///
/// `Scaffold` drops the top padding for a body that sits under an `appBar`, but
/// it does not drop the bottom one, and this body is a bare `Padding` with no
/// `SafeArea`. The `Spacer()` pushes `Report Item` to the last 48 pt of the
/// window, which is exactly the strip the home indicator sits in.
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
///
/// `Scaffold` defaults to `resizeToAvoidBottomInset: true`, so the 216 pt
/// keyboard comes straight off the height the non-scrolling `Column` has to lay
/// out in. There is no `SingleChildScrollView` anywhere in the body and the
/// `Spacer()` cannot absorb a negative, so the column overflows: a black-and-
/// yellow bar across the form the moment the field is tapped.
///
/// This preview is deliberately NOT in the shared render suite — the suite
/// asserts `takeException() == null` for every state, and this one throws by
/// design. It gets a dedicated group in the render test that asserts the
/// overflow instead, so the defect stays measured rather than hidden.
@JeebPreview(
  group: 'prohibited_item_report',
  name: 'Typing · keyboard up, body overflows',
  size: _prohibitedItemReportScreenCompactBox,
)
Widget prohibitedItemReportScreenKeyboardOpen() =>
    _prohibitedItemReportScreenHosted(
      ProhibitedItemReportScreenPreviewFixtures.keyboardOpen,
    );
