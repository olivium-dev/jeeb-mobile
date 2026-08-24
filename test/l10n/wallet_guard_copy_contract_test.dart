// W6-T4 frozen-copy firewall: the CONTRACT.md §5 table is FROZEN, so any drift
// in either .arb value must fail here rather than ship.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/l10n/app_localizations.dart';

/// EN column of CONTRACT.md §5, byte-copied from that file (never retyped).
const Map<String, String> _frozenEn = <String, String>{
  // C-1
  'walletGuardErrorHolderUnresolved': "We couldn't link your account to a wallet, so the balance check couldn't run. Sign out and sign back in; if it happens again, contact support.",
  // C-2
  'walletGuardErrorFeeUnresolvable': "We couldn't confirm this offer's fee right now. Please try again in a moment.",
  // C-3
  'walletGuardErrorExposureUnresolvable': "We couldn't check your open offers right now. Try again in a moment, or withdraw offers you no longer need.",
  // C-4
  'walletGuardErrorOfferLimitReached': "You've reached the limit of {limit} open offers. Withdraw one or wait for an offer to finish before bidding again.",
  // C-5
  'walletGuardInsufficientSheetTitle': 'Not enough wallet balance',
  // C-6
  'walletGuardInsufficientSheetBody': 'Covering the 10% fee for this offer plus your open offers takes {needed} {currency}. You have {available} {currency}. Top up your wallet or withdraw an open offer.',
  // P-1
  'walletGuardPushOfferWithdrawnTitle': 'Offer withdrawn — top up to keep bidding',
  // P-2
  'walletGuardPushOfferWithdrawnBody': 'Your winning offer was withdrawn because your wallet no longer covers the 10% platform fee. Tap to top up.',
  // C-7
  'offersErrorOfferNotPending': 'This offer is no longer available.',
};

/// AR column of CONTRACT.md §5, byte-copied from that file (never retyped).
const Map<String, String> _frozenAr = <String, String>{
  // C-1
  'walletGuardErrorHolderUnresolved': 'تعذّر ربط حسابك بمحفظة، لذلك لم نتمكن من التحقق من رصيدك. سجّل الخروج ثم ادخل مرة أخرى، وإذا تكررت المشكلة تواصل مع الدعم.',
  // C-2
  'walletGuardErrorFeeUnresolvable': 'تعذّر التحقق من رسوم هذا العرض حاليًا. يرجى المحاولة مرة أخرى بعد قليل.',
  // C-3
  'walletGuardErrorExposureUnresolvable': 'تعذّر التحقق من عروضك المفتوحة حاليًا. حاول مرة أخرى بعد قليل، أو اسحب العروض التي لم تعد بحاجة إليها.',
  // C-4
  'walletGuardErrorOfferLimitReached': 'لقد بلغت الحد الأقصى للعروض المفتوحة وهو {limit}. اسحب أحد عروضك أو انتظر اكتمال أحدها قبل تقديم عرض جديد.',
  // C-5
  'walletGuardInsufficientSheetTitle': 'رصيد المحفظة غير كافٍ',
  // C-6
  'walletGuardInsufficientSheetBody': 'تغطية رسوم 10% لهذا العرض إضافةً إلى عروضك المفتوحة تتطلب {needed} {currency}، ورصيدك الحالي {available} {currency}. اشحن محفظتك أو اسحب أحد عروضك المفتوحة.',
  // P-1
  'walletGuardPushOfferWithdrawnTitle': 'تم سحب عرضك — اشحن محفظتك لمواصلة تقديم العروض',
  // P-2
  'walletGuardPushOfferWithdrawnBody': 'تم سحب عرضك الفائز لأن رصيد محفظتك لم يعد يغطي رسوم المنصة البالغة 10%. اضغط لشحن محفظتك.',
  // C-7
  'offersErrorOfferNotPending': 'هذا العرض لم يعد متاحًا.',
};

/// CONTRACT §3: the gateway renders the push EN title/body itself, so mobile's
/// own P-1/P-2 EN copy MUST stay byte-identical to these gateway strings.
const String _gatewayPushTitleEn = 'Offer withdrawn — top up to keep bidding';
const String _gatewayPushBodyEn = 'Your winning offer was withdrawn because your wallet no longer covers the 10% platform fee. Tap to top up.';

const String _pushTitleKey = 'walletGuardPushOfferWithdrawnTitle';
const String _pushBodyKey = 'walletGuardPushOfferWithdrawnBody';
const String _limitKey = 'walletGuardErrorOfferLimitReached';
const String _sheetBodyKey = 'walletGuardInsufficientSheetBody';

AppLocalizations _load(Locale locale) => debugLoadAppLocalizationsSync(
  locale,
  File('lib/l10n/app_${locale.languageCode}.arb').readAsStringSync(),
);

int _countOf(String haystack, String needle) =>
    haystack.split(needle).length - 1;

void main() {
  const Locale en = Locale('en');
  const Locale ar = Locale('ar');

  test('EN copy is byte-identical to CONTRACT §5', () {
    final AppLocalizations loc = _load(en);
    for (final MapEntry<String, String> row in _frozenEn.entries) {
      expect(
        loc.byKey(row.key),
        row.value,
        reason: 'app_en.arb drifted from the FROZEN CONTRACT §5 copy for '
            '"${row.key}" — copy changes need a new ruling in RULINGS.md.',
      );
    }
  });

  test('AR copy is byte-identical to CONTRACT §5', () {
    final AppLocalizations loc = _load(ar);
    for (final MapEntry<String, String> row in _frozenAr.entries) {
      expect(
        loc.byKey(row.key),
        row.value,
        reason: 'app_ar.arb drifted from the FROZEN CONTRACT §5 copy for '
            '"${row.key}" — copy changes need a new ruling in RULINGS.md.',
      );
    }
  });

  test('push EN copy is byte-identical to the gateway wire strings', () {
    final AppLocalizations loc = _load(en);
    expect(loc.byKey(_pushTitleKey), _gatewayPushTitleEn);
    expect(loc.byKey(_pushBodyKey), _gatewayPushBodyEn);
    // The §5 table and the gateway pin must not drift apart either.
    expect(_frozenEn[_pushTitleKey], _gatewayPushTitleEn);
    expect(_frozenEn[_pushBodyKey], _gatewayPushBodyEn);
  });

  for (final Locale locale in const <Locale>[en, ar]) {
    final String tag = locale.languageCode;

    test('$tag: C-6 template carries {needed}, {available} and TWO '
        '{currency} slots', () {
      final String? template = _load(locale).byKey(_sheetBodyKey);
      expect(template, isNotNull);
      expect(template, contains('{needed}'));
      expect(template, contains('{available}'));
      expect(
        _countOf(template!, '{currency}'),
        2,
        reason: 'C-6 renders the currency code after BOTH amounts, so the '
            'getter must replaceAll (not replaceFirst) that slot.',
      );
    });

    test('$tag: C-4 template carries the {limit} slot', () {
      expect(_load(locale).byKey(_limitKey), contains('{limit}'));
    });

    test('$tag: walletGuardErrorOfferLimitReached substitutes {limit}', () {
      final String rendered = _load(locale).walletGuardErrorOfferLimitReached(
        20,
      );
      expect(rendered, contains('20'));
      expect(rendered, isNot(contains('{limit}')));
    });

    test('$tag: walletGuardInsufficientSheetBody substitutes every slot', () {
      final String rendered = _load(locale).walletGuardInsufficientSheetBody(
        '20.00',
        '10.00',
        'USD',
      );
      expect(rendered, contains('20.00'));
      expect(rendered, contains('10.00'));
      expect(_countOf(rendered, 'USD'), 2);
      expect(rendered, isNot(contains('{needed}')));
      expect(rendered, isNot(contains('{available}')));
      expect(rendered, isNot(contains('{currency}')));
    });
  }
}
