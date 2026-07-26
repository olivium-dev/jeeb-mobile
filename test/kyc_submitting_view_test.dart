import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_cubit.dart';
import 'package:jeeb_mobile/features/kyc/application/kyc_wizard_state.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_gateway.dart';
import 'package:jeeb_mobile/features/kyc/domain/kyc_submission.dart';
import 'package:jeeb_mobile/features/kyc/presentation/widgets/kyc_submitting_view.dart';
import 'package:jeeb_mobile/features/photo_attachment/data/stub_photo_picker_service.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

class _SyncAppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _SyncAppLocalizationsDelegate(this._arbByTag);

  final Map<String, String> _arbByTag;

  @override
  bool isSupported(Locale locale) => _arbByTag.containsKey(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return debugLoadAppLocalizationsSync(
      locale,
      _arbByTag[locale.languageCode]!,
    );
  }

  @override
  bool shouldReload(_SyncAppLocalizationsDelegate old) => false;
}

late _SyncAppLocalizationsDelegate _syncDelegate;

void _loadArbFromDisk() {
  final en = File('lib/l10n/app_en.arb').readAsStringSync();
  final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
  _syncDelegate = _SyncAppLocalizationsDelegate({'en': en, 'ar': ar});
}

Widget _host({Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: [
      _syncDelegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const Scaffold(body: SafeArea(child: KycSubmittingView())),
  );
}

class _SubmittingGateway extends FakeKycGateway {
  int statusCalls = 0;
  Completer<KycSubmission>? _heldStatus;

  void holdNextStatus() {
    _heldStatus = Completer<KycSubmission>();
  }

  void completeHeldStatus() {
    final heldStatus = _heldStatus;
    if (heldStatus == null || heldStatus.isCompleted) return;
    heldStatus.complete(const KycSubmission(status: KycStatus.notSubmitted));
  }

  @override
  Future<KycSubmission> fetchStatus() {
    statusCalls++;
    final heldStatus = _heldStatus;
    if (heldStatus != null && !heldStatus.isCompleted) {
      return heldStatus.future;
    }
    return Future.value(const KycSubmission(status: KycStatus.notSubmitted));
  }
}

class _SubmittingCubit extends KycWizardCubit {
  _SubmittingCubit({required KycGateway gateway})
    : super(pickerService: StubPhotoPickerService(), gateway: gateway) {
    emit(state.copyWith(step: KycWizardStep.submitting));
  }
}

class _SubmittingHarness {
  const _SubmittingHarness({required this.gateway, required this.cubit});

  final _SubmittingGateway gateway;
  final KycWizardCubit cubit;
}

_SubmittingHarness _newSubmittingHarness({bool holdStatus = false}) {
  final gateway = _SubmittingGateway();
  if (holdStatus) gateway.holdNextStatus();
  final cubit = _SubmittingCubit(gateway: gateway);
  addTearDown(() async {
    if (!cubit.isClosed) await cubit.close();
  });
  return _SubmittingHarness(gateway: gateway, cubit: cubit);
}

Widget _pollingHost(_SubmittingHarness harness) {
  return BlocProvider<KycWizardCubit>.value(
    value: harness.cubit,
    child: _host(),
  );
}

Future<void> _mountPollingHost(
  WidgetTester tester,
  _SubmittingHarness harness,
) async {
  await tester.pumpWidget(_pollingHost(harness));
  await tester.pump();
}

Future<void> _pumpTime(WidgetTester tester, Duration duration) async {
  await tester.pump(duration);
  await tester.pump();
}

Future<void> _changeLifecycle(
  WidgetTester tester,
  AppLifecycleState state,
) async {
  tester.binding.handleAppLifecycleStateChanged(state);
  await tester.pump();
}

Future<void> _disposePollingHost(
  WidgetTester tester,
  _SubmittingHarness harness,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  if (!harness.cubit.isClosed) await harness.cubit.close();
}

void main() {
  setUpAll(_loadArbFromDisk);

  testWidgets('renders headline, body, upload icon, and spinner (English)', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    expect(find.byKey(KycSubmittingView.rootKey), findsOneWidget);
    expect(find.byKey(KycSubmittingView.titleKey), findsOneWidget);
    expect(find.byKey(KycSubmittingView.spinnerKey), findsOneWidget);
    expect(find.text('Submitting your documents'), findsOneWidget);
    // D20: the KYC submit copy no longer references vehicle details (the
    // vehicle step was removed; the stale "vehicle" wording was dropped).
    expect(find.textContaining('uploading your ID and selfie'), findsOneWidget);
    expect(find.textContaining('vehicle'), findsNothing);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });

  testWidgets('renders Arabic copy when locale is ar', (tester) async {
    await tester.pumpWidget(_host(locale: const Locale('ar')));
    await tester.pump();

    expect(find.text('جاري إرسال مستنداتك'), findsOneWidget);
    expect(
      find.textContaining('نقوم برفع الهوية والصورة الشخصية'),
      findsOneWidget,
    );
  });

  testWidgets('marks itself as a live region for screen readers', (
    tester,
  ) async {
    await tester.pumpWidget(_host());
    await tester.pump();

    final semantics = tester.getSemantics(
      find.byKey(KycSubmittingView.rootKey),
    );
    expect(semantics.label.isNotEmpty, isTrue);
  });

  testWidgets('FM5-F12-S1: five scheduled probes complete at t=2,4,6,8,10s; '
      'capped silence has a resume presence control', (tester) async {
    final harness = _newSubmittingHarness();
    await _mountPollingHost(tester, harness);

    await _pumpTime(tester, const Duration(milliseconds: 1999));
    expect(harness.gateway.statusCalls, 0);
    await _pumpTime(tester, const Duration(milliseconds: 1));
    expect(harness.gateway.statusCalls, 1);
    expect(harness.gateway.statusCalls, greaterThan(0));

    for (var expected = 2; expected <= 5; expected++) {
      await _pumpTime(tester, const Duration(seconds: 2));
      expect(harness.gateway.statusCalls, expected);
    }
    await _pumpTime(tester, const Duration(hours: 1));
    expect(harness.gateway.statusCalls, 5);

    await _changeLifecycle(tester, AppLifecycleState.paused);
    await _changeLifecycle(tester, AppLifecycleState.resumed);
    expect(harness.gateway.statusCalls, 6);

    await _disposePollingHost(tester, harness);
  });

  testWidgets('FM5-F12-O1: a slow submitting refresh never overlaps; '
      'completion provides the presence control', (tester) async {
    final harness = _newSubmittingHarness(holdStatus: true);
    await _mountPollingHost(tester, harness);
    await _pumpTime(tester, const Duration(seconds: 2));
    expect(harness.gateway.statusCalls, 1);

    await _changeLifecycle(tester, AppLifecycleState.paused);
    await _changeLifecycle(tester, AppLifecycleState.resumed);
    await _pumpTime(tester, const Duration(hours: 1));
    expect(harness.gateway.statusCalls, 1);

    harness.gateway.completeHeldStatus();
    await tester.pump();
    await _pumpTime(tester, const Duration(seconds: 2));
    expect(harness.gateway.statusCalls, 2);

    await _disposePollingHost(tester, harness);
  });

  testWidgets(
    'FM5-F12-R1: resume cannot issue a probe once both budgets are spent; '
    'three in-budget resumes are the presence control',
    (tester) async {
      final harness = _newSubmittingHarness();
      await _mountPollingHost(tester, harness);
      for (var scheduled = 1; scheduled <= 5; scheduled++) {
        await _pumpTime(tester, const Duration(seconds: 2));
        expect(harness.gateway.statusCalls, scheduled);
      }

      for (var expected = 6; expected <= 8; expected++) {
        await _changeLifecycle(tester, AppLifecycleState.paused);
        await _changeLifecycle(tester, AppLifecycleState.resumed);
        expect(harness.gateway.statusCalls, expected);
      }
      for (var resume = 0; resume < 10; resume++) {
        await _changeLifecycle(tester, AppLifecycleState.paused);
        await _changeLifecycle(tester, AppLifecycleState.resumed);
      }
      expect(harness.gateway.statusCalls, 8);

      await _disposePollingHost(tester, harness);
    },
  );

  testWidgets(
    'FM5-F12-R2: resume probes are bounded at three beyond the scheduled '
    'budget; a scheduled request is the presence control',
    (tester) async {
      final harness = _newSubmittingHarness();
      await _mountPollingHost(tester, harness);
      await _changeLifecycle(tester, AppLifecycleState.paused);

      for (var expected = 1; expected <= 3; expected++) {
        await _changeLifecycle(tester, AppLifecycleState.resumed);
        expect(harness.gateway.statusCalls, expected);
        await _changeLifecycle(tester, AppLifecycleState.paused);
      }
      await _changeLifecycle(tester, AppLifecycleState.resumed);
      expect(harness.gateway.statusCalls, 3);
      await _pumpTime(tester, const Duration(seconds: 2));
      expect(harness.gateway.statusCalls, 4);

      await _disposePollingHost(tester, harness);
    },
  );

  testWidgets(
    'FM5-F12-S2: backgrounding pauses the submitting poll and resume checks '
    'immediately; inactive and resume are presence controls',
    (tester) async {
      final harness = _newSubmittingHarness();
      await _mountPollingHost(tester, harness);

      await _changeLifecycle(tester, AppLifecycleState.inactive);
      await _pumpTime(tester, const Duration(seconds: 2));
      expect(harness.gateway.statusCalls, 1);
      await _changeLifecycle(tester, AppLifecycleState.paused);
      await _pumpTime(tester, const Duration(hours: 1));
      expect(harness.gateway.statusCalls, 1);
      await _changeLifecycle(tester, AppLifecycleState.resumed);
      expect(harness.gateway.statusCalls, 2);

      await _disposePollingHost(tester, harness);
    },
  );

  testWidgets(
    'FM5-F12-S3: dispose cancels the grace timer and the chained timer; '
    'a mounted request is the presence control',
    (tester) async {
      final graceHarness = _newSubmittingHarness();
      await _mountPollingHost(tester, graceHarness);
      await _disposePollingHost(tester, graceHarness);
      await _pumpTime(tester, const Duration(hours: 1));
      expect(graceHarness.gateway.statusCalls, 0);

      final chainedHarness = _newSubmittingHarness();
      await _mountPollingHost(tester, chainedHarness);
      await _pumpTime(tester, const Duration(seconds: 2));
      expect(chainedHarness.gateway.statusCalls, 1);
      await _disposePollingHost(tester, chainedHarness);
      await _pumpTime(tester, const Duration(hours: 1));
      expect(chainedHarness.gateway.statusCalls, 1);
    },
  );
}
