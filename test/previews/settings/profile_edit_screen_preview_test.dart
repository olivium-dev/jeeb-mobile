// Render tests for the ProfileEditScreen previews.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/settings/presentation/screens/profile_edit_screen.dart';

import '../preview_test_harness.dart';

/// The long Arabic fixture name, spelled once.
const String _longName = 'عبد الرحمن المهندس الطرابلسي بن يوسف';

/// The screen's own localized required-field error (`profileNameRequired`).
const String _required = 'Please enter your name.';

/// `OmdsTextField`'s built-in `isRequired` message. Hardcoded English inside
/// the design system — NOT one of the app's 1534 localized keys.
const String _omdsRequired = 'This field is required';

/// The single name field on the screen.
TextField _nameField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

void main() {
  setUpAll(loadPreviewArbs);

  testPreviewsRender(
    'ProfileEditScreen',
    const <String, Widget Function()>{
      'Saved profile · name and phone': profileEditScreenSaved,
      'No name yet': profileEditScreenNoNameYet,
      'Photo on file · remove offered': profileEditScreenWithPhoto,
      'Loads after mount · the name field stays blank':
          profileEditScreenLoadsAfterMount,
      'Never loads · the screen has no loading state':
          profileEditScreenNeverLoads,
      'Saving · write in flight': profileEditScreenSaving,
      'Ceiling · long Arabic name': profileEditScreenLongName,
    },
    expectedText: const <String, String>{
      // The name in the field — this state is the only one that both has a
      'Saved profile · name and phone': 'Maya Haddad',
      // No name to pin, so the phone is the state. Every fixture carries a
      'No name yet': '+96176554433',
      'Photo on file · remove offered': 'Karim Aoun',
      // The phone lands (it is read from `state` in `build`); the name does
      'Loads after mount · the name field stays blank': '+96181234567',
      // `phoneE164` is still `''`, so `_PhoneRow` prints its em-dash
      'Never loads · the screen has no loading state': '—',
      // The CTA label under `isSavingProfile`.
      'Saving · write in flight': 'Saving…',
      'Ceiling · long Arabic name': _longName,
    },
  );

  group('ProfileEditScreen previews · the states are distinct', () {
    // Each preview builds its own host → its own `SettingsCubit`, so these are

    testWidgets('the saved profile fills the field and offers one CTA', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenSaved);

      expect(find.text('Edit profile'), findsOneWidget);
      expect(_nameField(tester).controller!.text, 'Maya Haddad');
      expect(find.text('+96170123456'), findsOneWidget);
      // Read-only phone: the padlock is the only thing that says so.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // No photo on file → no third CTA.
      expect(
        find.bySemanticsIdentifier('profile_edit_remove_avatar_cta'),
        findsNothing,
      );
      // The initial bubble, not '?'.
      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('the no-name state shows "?", the label AND the hint', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenNoNameYet);

      expect(_nameField(tester).controller!.text, isEmpty);
      expect(find.text('?'), findsOneWidget);
      expect(find.text('+96176554433'), findsOneWidget);
      // An empty field paints both `labelText` and `hintText`, stacked — the
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('How should we address you?'), findsOneWidget);
    });

    testWidgets('only the state with a photoUrl offers Remove avatar', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenWithPhoto);

      expect(
        find.bySemanticsIdentifier('profile_edit_remove_avatar_cta'),
        findsOneWidget,
      );
      expect(find.text('Remove avatar'), findsOneWidget);
      // It is the only state that mounts an `Image` at all...
      expect(find.byType(Image), findsOneWidget);
      // ...and, until the failed file read lands, the only one with NO glyph
      expect(find.text('K'), findsNothing);
      // The Remove CTA is the only thing on screen that knows a photo is set.
      expect(find.text('?'), findsNothing);
    });

    testWidgets('the saving state disables all three CTAs', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenSaving);

      expect(find.text('Saving…'), findsOneWidget);
      expect(find.text('Save'), findsNothing);
      // Change avatar is disabled with it — tapping opens no source sheet.
      await tester.tap(find.byKey(const Key('profile-edit-change-avatar')));
      await tester.pumpAndSettle();
      expect(find.text('Gallery'), findsNothing);
      expect(find.text('Camera'), findsNothing);
      // ...but the field the save is reading from stays fully editable.
      expect(_nameField(tester).enabled, isTrue);
      // And there is no progress indicator anywhere: a paler pill is the
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('the ceiling name reaches the field intact but cannot be seen '
        'whole', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844); // the declared box
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpPreview(tester, profileEditScreenLongName);

      expect(_nameField(tester).controller!.text, _longName);
      expect(find.text('+9613000077221'), findsOneWidget);
      // `maxLines: 1` is the OMDS default and this screen does not override
      expect(_nameField(tester).maxLines, 1);
      final double editable = tester.getSize(find.byType(EditableText)).width;
      final TextPainter painter = TextPainter(
        text: const TextSpan(
          text: _longName,
          style: TextStyle(fontSize: 16, fontFamily: 'Inter'),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      expect(painter.width, greaterThan(editable * 1.5));
    });
  });

  // FINDING 1. The name field is seeded ONCE, in `initState`, from whatever
  group('ProfileEditScreen previews · the name field never syncs', () {
    testWidgets('the read lands, the avatar and phone update, the field does '
        'not', (WidgetTester tester) async {
      await pumpPreview(tester, profileEditScreenLoadsAfterMount);

      // The read DID resolve: both `build`-time readers moved.
      expect(find.text('+96181234567'), findsOneWidget);
      expect(find.text('R'), findsOneWidget); // Rania → initial bubble
      // The one editable field on the screen did not.
      expect(_nameField(tester).controller!.text, isEmpty);
      expect(find.text('Rania Nasrallah'), findsNothing);
    });

    testWidgets('so Save tells a user with a name on file to enter one', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenLoadsAfterMount);

      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text(_required), findsOneWidget);
      expect(find.text('Profile saved.'), findsNothing);
    });
  });

  // FINDING 2. `SettingsState.isLoading` is never read by this screen, and
  group('ProfileEditScreen previews · there is no loading state', () {
    testWidgets('a read that never lands renders a live, empty form', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenNeverLoads);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('—'), findsOneWidget); // no phone yet
      expect(find.text('?'), findsOneWidget); // no name yet
      expect(_nameField(tester).enabled, isTrue);
      // The primary CTA is not merely visible, it is live.
      expect(find.text('Save'), findsOneWidget);
      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();
      expect(find.text(_required), findsOneWidget);
    });
  });

  // FINDING 3, and the one that costs a user something. `_onSave` calls
  group('ProfileEditScreen previews · Save deletes the avatar', () {
    testWidgets('a name-only save clears photoUrl and the Remove CTA with it', (
      WidgetTester tester,
    ) async {
      await pumpPreview(tester, profileEditScreenWithPhoto);

      // A photo is on file...
      expect(
        find.bySemanticsIdentifier('profile_edit_remove_avatar_cta'),
        findsOneWidget,
      );

      // ...the user changes nothing about it and saves the name.
      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();

      // The save reports success...
      expect(find.text('Profile saved.'), findsOneWidget);
      expect(_nameField(tester).controller!.text, 'Karim Aoun');
      // ...and the photo is gone.
      expect(
        find.bySemanticsIdentifier('profile_edit_remove_avatar_cta'),
        findsNothing,
      );
      expect(find.text('Remove avatar'), findsNothing);
    });
  });

  // FINDING 4. The field carries `isRequired: true`, which switches on
  group('ProfileEditScreen previews · two required-field errors, one '
      'localized', () {
    testWidgets('clearing the field raises the OMDS message, Save raises the '
        'localized one', (WidgetTester tester) async {
      await pumpPreview(tester, profileEditScreenSaved);

      await tester.enterText(find.byKey(const Key('profile-edit-name')), '');
      await tester.pumpAndSettle();

      expect(find.text(_omdsRequired), findsOneWidget);
      expect(find.text(_required), findsNothing);

      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();

      // The screen's own error takes over (`errorText` wins over the internal
      expect(find.text(_required), findsOneWidget);
    });

    testWidgets('the OMDS message does not translate', (
      WidgetTester tester,
    ) async {
      await pumpPreview(
        tester,
        profileEditScreenSaved,
        locale: const Locale('ar'),
      );

      await tester.enterText(find.byKey(const Key('profile-edit-name')), '');
      await tester.pumpAndSettle();

      // English, on an Arabic screen whose own error string IS localized.
      expect(find.text(_omdsRequired), findsOneWidget);

      await tester.tap(find.byKey(const Key('profile-edit-save')));
      await tester.pumpAndSettle();

      expect(find.text('يُرجى إدخال اسمك.'), findsOneWidget);
    });
  });
}
