// A13.1 — a frame nobody can decode still returns null, but is no longer
// dropped in total silence (the transport twin of F34).

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/realtime/phoenix_v2_frame.dart';

void main() {
  late List<String> lines;

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
  });

  tearDown(Diag.resetForTest);

  test('a well-formed frame decodes and records nothing', () {
    final frame = PhoenixV2Frame.decode(
      PhoenixV2Frame.encode(topic: 'jeeb:chat:c1', event: 'new_msg'),
    );

    expect(frame, isNotNull);
    expect(frame!.topic, 'jeeb:chat:c1');
    expect(lines.where((l) => l.contains('phoenix_frame_decode_failed')),
        isEmpty);
  });

  test('a malformed frame returns null AND records the drop', () {
    expect(PhoenixV2Frame.decode('{not json'), isNull);

    expect(
      lines.where((l) => l.contains('phoenix_frame_decode_failed')),
      hasLength(1),
    );
  });

  test('a shape the decoder rejects is NOT a decode failure', () {
    // A three-element array is a valid JSON document that simply is not a v2
    // frame — callers already read `null` as "not a frame".
    expect(PhoenixV2Frame.decode('[1,2,3]'), isNull);

    expect(
      lines.where((l) => l.contains('phoenix_frame_decode_failed')),
      isEmpty,
    );
  });

  test('the recorded event never carries the exception text', () {
    PhoenixV2Frame.decode('{not json');

    final String line = lines
        .firstWhere((l) => l.contains('phoenix_frame_decode_failed'));
    expect(line, isNot(contains('FormatException:')));
    expect(line, contains('FormatException'));
  });
}
