// COPY-07 / EP-04 / EP-17 / UX-25: the support form borrows no other feature's
// copy, snacks through the kit, and never offers a Retry a 401 cannot win.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_attachment.dart';
import 'package:jeeb_mobile/features/photo_attachment/domain/photo_picker_service.dart';
import 'package:jeeb_mobile/features/support/application/support_cubit.dart';
import 'package:jeeb_mobile/features/support/domain/support_repository.dart';
import 'package:jeeb_mobile/features/support/presentation/support_ticket_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _FailingRepo implements SupportRepository {
  const _FailingRepo(this.kind, this.failure);

  final SupportFailure kind;
  final AppFailure failure;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      throw SupportRepositoryException.classified(kind, appFailure: failure);
}

class _OkRepo implements SupportRepository {
  const _OkRepo();

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async =>
      const SupportTicket(id: 'ticket-1', status: 'open');
}

class _FailingPicker implements PhotoPickerService {
  _FailingPicker(this.failure);

  final PhotoPickFailure failure;

  @override
  Future<RawPhoto> pickFromCamera() => pickFromGallery();

  @override
  Future<RawPhoto> pickFromGallery() async => throw PhotoPickException(failure);
}

class _OkPicker implements PhotoPickerService {
  @override
  Future<RawPhoto> pickFromCamera() => pickFromGallery();

  @override
  Future<RawPhoto> pickFromGallery() async => RawPhoto(
    bytes: Uint8List.fromList(<int>[1, 2, 3]),
    source: PhotoSource.gallery,
  );
}

SupportCubit _seeded(SupportRepository repo) => SupportCubit(repo)
  ..setCategory(SupportCategory.delivery)
  ..setBody('My delivery never arrived.');

void main() {
  Widget harness(
    SupportCubit cubit, {
    PhotoPickerService? picker,
    Locale locale = const Locale('en'),
  }) {
    final router = GoRouter(
      initialLocation: '/support',
      routes: <RouteBase>[
        GoRoute(
          path: '/support',
          builder: (_, _) =>
              SupportTicketScreen(cubit: cubit, photoPicker: picker),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
        GoRoute(
          path: '/profile',
          name: 'customer-profile',
          builder: (_, _) => const Scaffold(body: Text('profile')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  Future<void> attach(WidgetTester tester) async {
    await tester.ensureVisible(byId('support_attach'));
    await tester.tap(byId('support_attach'));
    await tester.pumpAndSettle();
  }

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a denied photo permission snacks the PHOTO copy', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(
          _seeded(const _OkRepo()),
          picker: _FailingPicker(PhotoPickFailure.permissionDenied),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await attach(tester);

      expect(byId('support_attach_error'), findsOneWidget);
      final l10n = AppLocalizations.of(tester.element(byId('support_root')));
      final snack = byId('support_attach_error');
      expect(
        find.descendant(
          of: snack,
          matching: find.text(l10n.supportPhotoPermissionDenied),
        ),
        findsOneWidget,
      );
      // COPY-07: never the microphone key.
      expect(
        find.descendant(
          of: snack,
          matching: find.text(l10n.voiceRecordingErrorPermission),
        ),
        findsNothing,
      );
    });

    testWidgets('[$tag] an unavailable picker snacks the attachment copy', (
      tester,
    ) async {
      useReduceMotion(tester);
      await tester.pumpWidget(
        harness(
          _seeded(const _OkRepo()),
          picker: _FailingPicker(PhotoPickFailure.unavailable),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();
      await attach(tester);

      final l10n = AppLocalizations.of(tester.element(byId('support_root')));
      final snack = byId('support_attach_error');
      expect(snack, findsOneWidget);
      expect(
        find.descendant(
          of: snack,
          matching: find.text(l10n.supportAttachmentFailed),
        ),
        findsOneWidget,
      );
      // EP-04/EP-05: the kit's snack, never a raw one.
      expect(
        find.descendant(
          of: snack,
          matching: find.text(l10n.escalateErrorServer),
        ),
        findsNothing,
      );
    });
  }

  testWidgets('a cancelled pick stays silent', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        _seeded(const _OkRepo()),
        picker: _FailingPicker(PhotoPickFailure.cancelled),
      ),
    );
    await tester.pumpAndSettle();
    await attach(tester);

    expect(byId('support_attach_error'), findsNothing);
  });

  testWidgets('a successful pick adds the attachment chip', (tester) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(_seeded(const _OkRepo()), picker: _OkPicker()),
    );
    await tester.pumpAndSettle();
    await attach(tester);

    expect(byId('support_attach_item_0'), findsOneWidget);
  });

  testWidgets('unauthorized gets the sign-in way out, never a Retry', (
    tester,
  ) async {
    useReduceMotion(tester);
    final cubit = _seeded(
      const _FailingRepo(SupportFailure.unauthorized, UnauthorizedFailure()),
    );
    await cubit.submit();
    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(byId('support_error'), findsOneWidget);
    expect(byId('support_error_signin_cta'), findsOneWidget);
    expect(byId('support_retry_cta'), findsNothing);
    final l10n = AppLocalizations.of(tester.element(byId('support_root')));
    expect(
      find.descendant(
        of: byId('support_error'),
        matching: find.text(l10n.supportErrorUnauthorized),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the retry pill no longer reads "Submit"', (tester) async {
    useReduceMotion(tester);
    final cubit = _seeded(
      const _FailingRepo(SupportFailure.network, NetworkFailure(offline: true)),
    );
    await cubit.submit();
    await tester.pumpWidget(harness(cubit));
    await tester.pumpAndSettle();

    expect(byId('support_retry_cta'), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(byId('support_root')));
    // EP-17/UX-29: the retry label is a retry label.
    expect(
      find.descendant(
        of: byId('support_retry_cta'),
        matching: find.text(l10n.actionRetry),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: byId('support_retry_cta'),
        matching: find.text(l10n.supportSubmitCta),
      ),
      findsNothing,
    );
  });

  testWidgets('the form labels are support copy, not borrowed keys', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(harness(_seeded(const _OkRepo())));
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(tester.element(byId('support_root')));
    // JeebSectionLabel upper-cases its own label.
    expect(find.text(l10n.supportCategoryLabel.toUpperCase()), findsOneWidget);
    expect(find.text(l10n.supportCategoryAccount), findsOneWidget);
    expect(find.text(l10n.supportCategoryOther), findsOneWidget);
    expect(find.text(l10n.supportBodyLabel), findsOneWidget);
    expect(find.text(l10n.supportOrderLinkLabel), findsOneWidget);
    // COPY-08: the borrowed escalate label is gone from the category group.
    expect(find.text(l10n.escalateCommentLabel), findsNothing);
    expect(find.text(l10n.ordersTitle), findsNothing);
  });
}
