// The platform commission rate has ONE copy in `lib/`.
//
// ## What went wrong, and what nearly went wrong
//
// The rate lived, longhand, in three unrelated places:
//
//   lib/features/earnings/domain/earnings_summary.dart      kJeebFeeRate = 0.10
//   lib/features/offers/presentation/offer_submission_screen.dart  _price * 0.10
//   lib/features/wallet/data/stub_wallet_transaction_repository.dart  feeRate: 0.1
//
// They agreed with settlement — the gateway's
// `CommissionCalculator.FlatRate = 0.10m` (owner ruling Q-001, flat 10% for
// v1) — so nothing was visibly broken. They agreed by coincidence, though:
// nothing connected them, and the next rate change would have had to find all
// three or start telling Jeebers the wrong take-home.
//
// That is not hypothetical. A FIFTH copy of this number, on the gateway's tier
// catalogue, drifted exactly that way: `GET /tiers` published 0.25 / 0.20 /
// 0.15 for weeks while settlement paid 10%. It reached no user for a reason
// that is pure luck — the app never parsed `commissionRate` at all. The
// numeric copies below were the client-side version of the same shape, waiting
// for someone to change one of them.
//
// ## What this file asserts
//
//  1. POSITIVE: every rate the app renders derives from `kJeebCommissionRate`,
//     and the value matches the gateway's authority.
//  2. NEGATIVE (the durable half): `lib/` contains no SECOND numeric copy. This
//     is a source scan, so it catches a copy nobody thought to unit-test — which
//     is how all three originals survived.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/jeeb_commission.dart';
import 'package:jeeb_mobile/features/earnings/domain/earnings_summary.dart';
import 'package:jeeb_mobile/features/wallet/data/stub_wallet_transaction_repository.dart';
import 'package:jeeb_mobile/features/wallet/domain/wallet_ledger_repository.dart';

/// Repo root, found by walking up to `pubspec.yaml` so this works from any cwd.
Directory get _repoRoot {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate the repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

/// The ONE file allowed to hold the literal.
const String _singleSource = 'lib/core/jeeb_commission.dart';

/// A decimal literal that is a plausible commission rate. Deliberately narrow:
/// `0.1`, `0.10`, `0.100`… and nothing else, so this cannot fire on an
/// unrelated fraction.
final RegExp _rateLiteral = RegExp(r'(?<![\d.])0\.10*(?![\d])');

/// Identifiers that make a line a COMMISSION line rather than an arbitrary one.
/// Without this the scan would flag `127.0.0.1` — which is the only other place
/// the digits `0.1` occur in `lib/` today.
final RegExp _commissionContext = RegExp(
  r'commission|feeRate|fee_rate|FeeRate|platformFee|platform_fee|'
  r'serviceFee|reserve|Reserve|takeHome|netEarning',
  caseSensitive: false,
);

List<File> get _libDartFiles => Directory('${_repoRoot.path}/lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Every offending `path:line -> text` in [lines], attributed to [rel].
///
/// The literal must appear in CODE (trailing comments stripped), but the
/// commission CONTEXT is searched over a WINDOW — the three lines before and
/// the line after, raw. Dart's formatter routinely splits a getter across two
/// lines, which puts `_reserve` on one and `* 0.10` on the next; a same-line
/// predicate reads that as an anonymous fraction and waves it through. That is
/// not hypothetical — it is how the first version of this scan failed its own
/// negative control (NC-A came back GREEN on a faithfully re-planted copy).
List<String> commissionLiteralHits(String rel, List<String> lines) {
  final hits = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final code = lines[i].split('//').first;
    if (lines[i].trimLeft().startsWith('///')) continue;
    if (!_rateLiteral.hasMatch(code)) continue;
    final window = lines
        .sublist((i - 3).clamp(0, lines.length), (i + 2).clamp(0, lines.length))
        .join('\n');
    if (!_commissionContext.hasMatch(window)) continue;
    hits.add('$rel:${i + 1} -> ${lines[i].trim()}');
  }
  return hits;
}

void main() {
  group('the rate itself', () {
    test('mirrors the gateway authority — CommissionCalculator.FlatRate', () {
      // `jeeb-gateway/src/JeebGateway/Financials/CommissionCalculator.cs:54`
      //   public const decimal FlatRate = 0.10m;
      // Owner ruling Q-001 (2026-07-07): flat 10% for v1.
      expect(kJeebCommissionRate, 0.10);
      expect(kJeebCommissionPercent, 10);
      expect(
        kJeebCommissionRate * 100,
        closeTo(kJeebCommissionPercent.toDouble(), 1e-9),
        reason: 'the display percentage and the computed rate are the SAME '
            'number in two shapes; they must not be free to disagree',
      );
    });

    test('every surviving alias resolves to the single source', () {
      // `kJeebFeeRate` is kept as a name (its call site reads correctly) but no
      // longer holds a literal.
      expect(kJeebFeeRate, same(kJeebCommissionRate));
    });
  });

  group('the three call sites that used to hold their own copy', () {
    test('earnings: the derived fee follows the single source', () {
      // `_deriveFee` is the legacy-payload fallback: no explicit fee on the
      // wire, so the app computes one.
      final item = EarningsDeliveryItem.fromJson(const {
        'deliveryId': 'DLV-1',
        'amount': {'value': 200.0, 'currency': 'USD'},
        'deliveredAt': '2026-08-01T10:00:00Z',
      });
      expect(item.cashCollected, 200.0);
      expect(item.feePaid, 200.0 * kJeebCommissionRate);
      expect(item.feePaid, 20.0); // pinned, so a silent rate flip is loud here
    });

    test('wallet: the fee row a Jeeber READS follows the single source',
        () async {
      // This repository is the DI-bound one (`injection_container.dart` still
      // binds it, per its own class doc), so its rate SHIPS — it was never a
      // test fixture.
      final txn = await const StubWalletTransactionRepository()
          .fetchTransaction('txn-fee-001');
      expect(txn.type, WalletLedgerType.feeWon);
      expect(txn.feeRate, kJeebCommissionRate);
      expect(txn.feePercent, closeTo(10.0, 1e-9));
      expect(
        txn.title,
        contains('$kJeebCommissionPercent%'),
        reason: 'the label beside the number must come from the same constant '
            'as the number, or the row can contradict itself',
      );
    });
  });

  group('NEGATIVE — no second numeric copy may reappear in lib/', () {
    test('the single source is the only file holding the rate literal', () {
      final root = _repoRoot.path;
      final offenders = <String>[];
      for (final file in _libDartFiles) {
        final rel = file.path.replaceFirst('$root/', '');
        if (rel == _singleSource) continue;
        offenders.addAll(commissionLiteralHits(rel, file.readAsLinesSync()));
      }
      expect(
        offenders,
        isEmpty,
        reason: 'a commission rate literal outside $_singleSource is a second '
            'copy of a number the gateway owns. Import kJeebCommissionRate '
            'instead.\n${offenders.join('\n')}',
      );
    });

    test('POSITIVE CONTROL — the scan fires on each of the three ORIGINAL '
        'copies, re-planted verbatim', () {
      // A ban nobody has ever seen fire is not a ban. These are the literal
      // lines as they stood on origin/main, run through the very predicate the
      // sweep above uses.
      expect(
        commissionLiteralHits('x.dart', const [
          '/// Legacy fallback fee rate for older mock payloads.',
          'const double kJeebFeeRate = 0.10;',
        ]),
        hasLength(1),
        reason: 'earnings_summary.dart:6',
      );
      expect(
        commissionLiteralHits('x.dart', const [
          '  /// Reserve held against this offer = exactly 10% of the price.',
          '  double? get _reserve => _price == null ? null : (_price! * 0.10);',
        ]),
        hasLength(1),
        reason: 'offer_submission_screen.dart:187',
      );
      expect(
        commissionLiteralHits('x.dart', const [
          '      pinnedPrice: 15.0,',
          '      feeRate: 0.1,',
        ]),
        hasLength(1),
        reason: 'stub_wallet_transaction_repository.dart:52',
      );
    });

    test('POSITIVE CONTROL — the window catches a SPLIT expression, which the '
        'first version of this scan did not', () {
      // The formatter puts the context word and the literal on different lines.
      // A same-line predicate returns 0 here and the ban silently stops
      // banning; this is the exact miss that made NC-A pass.
      expect(
        commissionLiteralHits('x.dart', const [
          '  double? get _reserve =>',
          '      _price == null ? null : (_price! * 0.10);',
        ]),
        hasLength(1),
      );
    });

    test('NEGATIVE CONTROL — it does not fire on the look-alikes', () {
      // The only other place these digits occur in lib/.
      expect(
        commissionLiteralHits('x.dart', const [
          "const String devHost = 'http://127.0.0.1:9000';",
        ]),
        isEmpty,
        reason: 'an IP octet is not a commission rate',
      );
      // An unrelated fraction, even next to the word "fee".
      expect(
        commissionLiteralHits('x.dart', const [
          '  // fee row styling',
          '  color.withValues(alpha: 0.12)',
        ]),
        isEmpty,
        reason: '0.12 is not the rate literal',
      );
      // A commission AMOUNT is not a rate.
      expect(
        commissionLiteralHits('x.dart', const ['      commission: 4.0,']),
        isEmpty,
      );
    });

    test('the scan looked at a real, non-empty tree', () {
      // The denominator, stated. An empty file list would make the ban above
      // vacuously green.
      expect(_libDartFiles.length, greaterThan(200));
      expect(
        File('${_repoRoot.path}/$_singleSource').existsSync(),
        isTrue,
        reason: 'the single source must exist for the exemption to mean '
            'anything',
      );
    });
  });
}
