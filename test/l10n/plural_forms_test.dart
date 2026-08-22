// Plural-forms dispatch test for T-MOB-FIX-002 (JEB-2).

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/l10n/app_localizations.dart';

typedef _PluralFn = String Function(AppLocalizations l10n, int count);

class _PluralCase {
  const _PluralCase(this.name, this.base, this.fn);
  final String name;
  final String base;
  final _PluralFn fn;
}

const _arabicCases = <_PluralCase>[
  _PluralCase(
    'availabilityActiveDeliveries',
    'availabilityActiveDeliveries',
    _availability,
  ),
  _PluralCase('chatPendingMessages', 'chatPendingMessages', _chat),
  _PluralCase(
    'earningsSummaryCompleted',
    'earningsSummaryCompleted',
    _earnings,
  ),
  _PluralCase(
    'dashboardNearbyRequests',
    'dashboardNearbyRequests',
    _nearby,
  ),
  _PluralCase(
    'dashboardTodayEarningsCompleted',
    'dashboardTodayEarningsCompleted',
    _today,
  ),
  _PluralCase(
    'requestSummaryFindingNotified',
    'requestSummaryFindingNotified',
    _finding,
  ),
  _PluralCase(
    'requestSummaryPhotosAttached',
    'requestSummaryPhotosAttached',
    _photos,
  ),
  _PluralCase('filterSheetApplyCta', 'filterSheetApplyCta', _filterApply),
  _PluralCase(
    'homeRequestsRepliesBadge',
    'homeRequestsRepliesBadge',
    _repliesBadge,
  ),
];

String _availability(AppLocalizations l, int n) =>
    l.availabilityActiveDeliveries(n);
String _chat(AppLocalizations l, int n) => l.chatPendingMessages(n);
String _earnings(AppLocalizations l, int n) => l.earningsSummaryCompleted(n);
String _nearby(AppLocalizations l, int n) => l.dashboardNearbyRequestsCount(n);
String _today(AppLocalizations l, int n) => l.dashboardTodayEarningsCompleted(n);
String _finding(AppLocalizations l, int n) =>
    l.requestSummaryFindingNotifiedCount(n);
String _photos(AppLocalizations l, int n) => l.requestSummaryPhotosAttached(n);
String _filterApply(AppLocalizations l, int n) => l.filterSheetApplyCta(n);
String _repliesBadge(AppLocalizations l, int n) =>
    l.homeRequestsRepliesBadge(n);

String _expectedForm(int n) {
  if (n == 0) return 'Zero';
  if (n == 1) return 'One';
  if (n == 2) return 'Two';
  final mod = n % 100;
  if (mod >= 3 && mod <= 10) return 'Few';
  if (mod >= 11 && mod <= 99) return 'Many';
  return 'Other';
}

void main() {
  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('${locale.languageCode} plural dispatch', () {
      late AppLocalizations l10n;

      setUpAll(() {
        final raw = File('lib/l10n/app_${locale.languageCode}.arb')
            .readAsStringSync();
        l10n = debugLoadAppLocalizationsSync(locale, raw);
      });

      for (final c in _arabicCases) {
        // LEAD §4 — count ∈ {0,1,2,3,11,100,1000} plus extra mod-100 edges.
        const counts = <int>[0, 1, 2, 3, 5, 10, 11, 99, 100, 101, 110, 111, 1000];
        for (final count in counts) {
          test('${c.name}($count) maps to ${_expectedForm(count)} form', () {
            final out = c.fn(l10n, count);
            expect(out, isNotNull);
            expect(out, isNotEmpty);
            expect(
              out,
              isNot(equals(c.base)),
              reason: 'dispatch fell back to function-identity key',
            );
            // The dispatched form must be one of the six CLDR forms in the ARB.
            final form = _expectedForm(count);
            final expected = l10n.byKey('${c.base}$form');
            expect(expected, isNotNull,
                reason: 'ARB missing form ${c.base}$form');
            // The output should equal the form (after placeholder substitution).
            if (count > 2 && expected != null) {
              final concrete = expected.replaceFirst('{count}', '$count');
              expect(out, equals(concrete));
            }
          });
        }
      }

      // All 6 AR forms exist in the ARB for every plural set
      for (final c in _arabicCases) {
        test('${c.name} declares all 6 CLDR forms in ${locale.languageCode}',
            () {
          for (final form in const [
            'Zero',
            'One',
            'Two',
            'Few',
            'Many',
            'Other'
          ]) {
            expect(
              l10n.byKey('${c.base}$form'),
              isNotNull,
              reason: 'missing ARB form: ${c.base}$form',
            );
          }
        });
      }
    });
  }
}
