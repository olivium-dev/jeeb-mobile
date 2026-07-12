// B-02b — the create-request submit must fire exactly once even under a
// re-entrant call (the footer's own `_submitting` guard is lost across a
// back-nav re-entry, so the guard has to live on the shared controller too).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/location/application/location_select_state.dart';
import 'package:jeeb_mobile/features/request_summary/application/compose_request_controller.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_draft.dart';
import 'package:jeeb_mobile/features/request_summary/domain/request_submission_service.dart';

/// A submission service whose `submit` blocks until [release] is called, so the
/// test can hold a create IN FLIGHT and fire a second submit against it.
class _GatedSubmission implements RequestSubmissionService {
  int submitCount = 0;
  Completer<String> _gate = Completer<String>();

  @override
  Future<String> submit(RequestDraft draft) {
    submitCount++;
    return _gate.future;
  }

  void release(String id) {
    _gate.complete(id);
    _gate = Completer<String>();
  }
}

// JEBV4-176: a current-location choice now carries a REAL resolved GPS fix
// (non-Beirut) — the controller refuses to create without a real coordinate.
const _loaded = LocationSelectState(
  status: LocationSelectStatus.loaded,
  currentGpsStatus: CurrentGpsStatus.resolved,
  gpsLat: 33.8959,
  gpsLng: 35.4797,
);

void main() {
  group('B-02b — ComposeRequestController in-flight guard', () {
    test('a re-entrant submit joins the in-flight create (fires exactly once)',
        () async {
      final gated = _GatedSubmission();
      final controller = ComposeRequestController(gated);

      final f1 = controller.submitFromLocation(_loaded);
      final f2 = controller.submitFromLocation(_loaded); // while f1 in flight

      expect(gated.submitCount, 1, reason: 'the create must fire only once');
      expect(identical(f1, f2), isTrue, reason: 'both callers share one future');

      gated.release('req-1');
      expect(await f1, 'req-1');
      expect(await f2, 'req-1');
    });

    test('a fresh submit after the first settles fires a new create (retry ok)',
        () async {
      final gated = _GatedSubmission();
      final controller = ComposeRequestController(gated);

      final first = controller.submitFromLocation(_loaded);
      gated.release('req-1');
      await first;

      final second = controller.submitFromLocation(_loaded);
      gated.release('req-2');
      expect(await second, 'req-2');
      expect(gated.submitCount, 2);
    });
  });
}
