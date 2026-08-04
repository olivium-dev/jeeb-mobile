// M6 orange-budget lane — per-element ink assertions for `kyc_status_view`.
//
// Goldens are evidence, not gates (5% tolerance), so each swap is pinned by
// reading the value off the widget. Every assertion is RELATIONAL: the shared
// `wrapForTest` themes with `ThemeData.light()`, so a Midnight hex read here
// would measure the harness rather than the app.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/theme/jeeb_color_roles.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/kyc_status_view.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/sync_app_localizations.dart';

Future<KycWizardCubit> _cubitFor(KycStatus status) async {
  final cubit = KycWizardCubit(
    pickerService: StubPhotoPickerService(),
    gateway: FakeKycGateway(initial: KycSubmission(status: status)),
  );
  await cubit.loadStatus();
  return cubit;
}

Widget _host(KycWizardCubit cubit) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: BlocProvider<KycWizardCubit>.value(
        value: cubit,
        child: const KycStatusView(),
      ),
    );

Future<void> _pump(WidgetTester tester, KycStatus status) async {
  final cubit = await _cubitFor(status);
  addTearDown(cubit.close);
  await tester.pumpWidget(_host(cubit));
  await tester.pump();
}

void main() {
  testWidgets('the status headline is onSurface ink, never the accent',
      (tester) async {
    await _pump(tester, KycStatus.pending);

    final Text title =
        tester.widget<Text>(find.byKey(KycStatusView.pendingTitleKey));
    final ColorScheme scheme = Theme.of(
      tester.element(find.byKey(KycStatusView.pendingTitleKey)),
    ).colorScheme;

    expect(title.style?.color?.toARGB32(), scheme.onSurface.toARGB32());
    // The discriminator: reverting to `colorScheme.primary` fails here.
    expect(title.style?.color?.toARGB32(), isNot(scheme.primary.toARGB32()));
  });

  testWidgets('the pending hourglass is the info pair, never the accent',
      (tester) async {
    await _pump(tester, KycStatus.pending);

    final Finder glyph = find.byIcon(Icons.hourglass_top_rounded);
    expect(glyph, findsOneWidget);

    final BuildContext context = tester.element(glyph);
    final JeebRoles roles = context.jeebRoles;
    final ColorScheme scheme = Theme.of(context).colorScheme;

    expect(
      tester.widget<Icon>(glyph).color?.toARGB32(),
      roles.onInfoContainer.toARGB32(),
    );
    expect(
      tester.widget<Icon>(glyph).color?.toARGB32(),
      isNot(scheme.primary.toARGB32()),
    );

    // The disc behind it is the matching container half of the same role pair.
    final BoxDecoration disc = tester
        .widgetList<Container>(
          find.ancestor(of: glyph, matching: find.byType(Container)),
        )
        .map((Container c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((BoxDecoration d) => d.shape == BoxShape.circle);
    expect(disc.color?.toARGB32(), roles.infoContainer.toARGB32());
  });

  testWidgets('the rejected head keeps its own role pair unchanged',
      (tester) async {
    await _pump(tester, KycStatus.rejected);

    final Finder glyph = find.byIcon(Icons.error_outline_rounded);
    expect(glyph, findsOneWidget);
    final ColorScheme scheme = Theme.of(tester.element(glyph)).colorScheme;
    expect(
      tester.widget<Icon>(glyph).color?.toARGB32(),
      scheme.onErrorContainer.toARGB32(),
    );
  });
}
