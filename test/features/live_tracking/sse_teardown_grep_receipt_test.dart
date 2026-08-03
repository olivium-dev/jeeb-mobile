import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MB1 — the standing grep receipts for the SSE teardown, run a

/// Joins fragments into a forbidden token at runtime. Neither o
String _tok(List<String> fragments) => fragments.join();

/// The tokens MB1 V-1 requires to be absent, assembled so this 
final List<String> _forbidden = [
  _tok(['SseLive', 'PositionStream']),
  _tok(['LivePosition', 'StreamSource']),
  _tok(['_position', 'Subscription']),
  _tok(['_position', 'RearmTimer']),
  _tok(['kPosition', 'RearmBackoff']),
  _tok(['geo/jeeb', '/stream']),
];

/// Repo root, derived by walking up to `pubspec.yaml` so this w
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

List<File> _dartFiles(List<String> roots) => [
  for (final r in roots)
    if (Directory('${_repoRoot.path}/$r').existsSync())
      ...Directory('${_repoRoot.path}/$r')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')),
];

/// Every file MB1's repo-wide predicate would reach. Deliberate
List<File> get _allSourceFiles => _dartFiles(['lib', 'test']);

/// Strips `///`, `//` and `/* */` so a doc comment can never sa
String _stripComments(String src) {
  final noBlock = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlock
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'//.*$'), ''))
      .join('\n');
}

/// Files whose RAW bytes contain [token] — the shape `git grep 
List<String> _filesContaining(String token) => [
  for (final f in _allSourceFiles)
    if (f.readAsStringSync().contains(token))
      f.path.replaceFirst('${_repoRoot.path}/', ''),
];

void main() {
  group('MB1 — the deleted SSE symbols are gone REPO-WIDE', () {
    for (final token in _forbidden) {
      test('$token appears in 0 files under lib/ + test/', () {
        expect(
          _filesContaining(token),
          isEmpty,
          reason:
              'MB1 V-1 greps the whole tree with no pathspec, so prose '
              'counts as a residual. If THIS file is the hit, someone '
              'un-split the token — read the class doc.',
        );
      });
    }

    test('this file does not defeat its own receipts', () {
      final self = File(
        '${_repoRoot.path}/test/features/live_tracking/'
        'sse_teardown_grep_receipt_test.dart',
      ).readAsStringSync();
      for (final token in _forbidden) {
        expect(
          self.contains(token),
          isFalse,
          reason:
              '"$token" is spelled literally in this file, so V-1\'s '
              'repo-wide grep will name it.',
        );
      }
    });
  });

  group('POSITIVE CONTROL — the instrument can find things', () {
    test('LivePositionSource is still PRESENT (a zero here is the FAILURE)', () {
      final files = _filesContaining(_tok(['LivePosition', 'Source']));
      expect(
        files,
        isNotEmpty,
        reason:
            'deleting this type would satisfy every negative receipt '
            'above while destroying the thing MB1 exists to wire — the '
            'archetypal grep-driven false pass.',
      );
      expect(
        files.any(
          (f) => f.endsWith(
            'lib/features/live_tracking/domain/'
            'live_tracking_repository.dart',
          ),
        ),
        isTrue,
        reason:
            'it must survive at its DECLARATION site, not merely in a '
            'test fake.',
      );
    });

    test(
      'a symbol that never existed is reported absent (no false positives)',
      () {
        expect(
          _filesContaining(_tok(['SseLive', 'PositionStream', 'Xyzzy'])),
          isEmpty,
        );
      },
    );
  });

  group('MB1 — fetchLivePosition has a real production CALL SITE', () {
    test('>=1 call expression in lib/, on comment-stripped source', () {
      final callSites = <String>[];
      for (final f in _dartFiles(['lib'])) {
        final code = _stripComments(f.readAsStringSync());
        if (RegExp(r'\.fetchLivePosition\(').hasMatch(code)) {
          callSites.add(f.path.replaceFirst('${_repoRoot.path}/', ''));
        }
      }
      expect(
        callSites,
        isNotEmpty,
        reason:
            'baseline was 0. If this reds, the courier marker is '
            'orphaned again and the P0 is back.',
      );
      expect(callSites, contains(endsWith('live_tracking_cubit.dart')));
    });

    test('NEGATIVE CONTROL: a bare-token match would have passed on the '
        'orphaned code, so the receipt must be a CALL', () {
      final declCode = _stripComments(
        File(
          '${_repoRoot.path}/lib/features/live_tracking/domain/'
          'live_tracking_repository.dart',
        ).readAsStringSync(),
      );
      expect(
        declCode.contains('fetchLivePosition'),
        isTrue,
        reason: 'the bare token IS present at the declaration…',
      );
      expect(
        RegExp(r'\.fetchLivePosition\(').hasMatch(declCode),
        isFalse,
        reason: '…but it is NOT a call there.',
      );
    });
  });

  group('MB1 — the position axis has no clock', () {
    const keepAliveFile =
        'lib/features/live_tracking/data/courier_position_socket.dart';
    const clockPatterns = ['Timer.periodic', 'Timer(', 'Future.delayed'];

/// The predicate, extracted so the POSITIVE CONTROL can run the
    List<String> clockHits(String path, String code) => [
      for (final pattern in clockPatterns)
        if (code.contains(pattern)) '$path -> $pattern',
    ];

    test('the CUBIT holds no clock at all — the file the P0 actually lived in',
        () {
      final code = _stripComments(
        File(
          '${_repoRoot.path}/lib/features/live_tracking/application/'
          'live_tracking_cubit.dart',
        ).readAsStringSync(),
      );
      expect(clockHits('live_tracking_cubit.dart', code), isEmpty);
    });

    test('no Timer / Future.delayed anywhere in the feature except the ONE '
        'named keepalive', () {
      final offenders = <String>[];
      for (final f in _dartFiles(['lib/features/live_tracking'])) {
        final rel = f.path.replaceFirst('${_repoRoot.path}/', '');
        if (rel == keepAliveFile) continue;
        offenders.addAll(clockHits(rel, _stripComments(f.readAsStringSync())));
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the entire point of MB1 is that the position is read on '
            'EVENTS and on no clock. A re-armed timer here is how the '
            'original 2/5/15/30 s backoff became a permanent poll against a '
            '404 for four days.',
      );
    });

    test('the allowance is EXACTLY one Timer.periodic and nothing else', () {
      final code = _stripComments(
        File('${_repoRoot.path}/$keepAliveFile').readAsStringSync(),
      );
      expect(
        RegExp('Timer.periodic').allMatches(code).length,
        1,
        reason: 'one keepalive, not a family of timers',
      );
      expect(code.contains('Timer('), isFalse);
      expect(code.contains('Future.delayed'), isFalse);
    });

    test('the allowed tick CANNOT be a poll — it receives nothing', () {
      final code = _stripComments(
        File('${_repoRoot.path}/$keepAliveFile').readAsStringSync(),
      );

      expect(
        RegExp(r'Timer\.periodic\(\s*_keepAlive\s*,\s*\(_\)\s*=>\s*'
                r'_sendKeepAlive\(\)\s*\)')
            .hasMatch(code),
        isTrue,
        reason: 'the permitted timer must call _sendKeepAlive and nothing else',
      );

      final body = RegExp(
        r'(?:void|Future<void>) _sendKeepAlive\(\)\s*(?:async\s*)?\{(.*?)\n  \}',
        dotAll: true,
      ).firstMatch(code)?.group(1);
      expect(body, isNotNull, reason: 'the pinned method must be findable');
      expect(body, contains('_send('));
      for (final banned in const ['await', 'Dio', 'HttpClient', 'http.', '.get(']) {
        expect(body!.contains(banned), isFalse,
            reason: 'a keepalive that can $banned is a poll');
      }
    });

    test('POSITIVE CONTROL: the ban still fires on planted source', () {
      expect(
        clockHits('planted.dart', 'void t() { Timer.periodic(d, (_) {}); }'),
        isNotEmpty,
      );
      expect(clockHits('planted.dart', 'Timer(d, () {});'), isNotEmpty);
      expect(
        clockHits('planted.dart', 'await Future.delayed(d);'),
        isNotEmpty,
      );
      expect(clockHits('planted.dart', 'final x = 1;'), isEmpty);
    });
  });
}
