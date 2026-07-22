import '../model/obs_event.dart';
import '../observability.dart';

/// A non-invasive [ObservabilitySink] DECORATOR used only by the devtool
/// overlay (see `ObsOverlayController.attach`) to observe the live event
/// stream without disturbing persistence.
///
/// [Observability.record] hands every captured event to whichever sink is
/// currently installed. Wrapping that sink in a tee — rather than replacing
/// it — means the real writer (`ObsFileWriter`, installed by
/// `Bootstrap.minimal()`) keeps receiving every event exactly as before;
/// this class only ever ADDS an observer, it never removes or alters
/// behavior. [onEvent] is wrapped in a try/catch so a UI-side bug can never
/// break the capture pipeline it taps into — the same fail-soft contract
/// the rest of this tool follows (see `Observability.record`).
final class ObsOverlayTeeSink implements ObservabilitySink {
  ObsOverlayTeeSink({required this.inner, required this.onEvent});

  /// The sink this tee wraps — the real writer, or null before one exists
  /// (e.g. a cold-start race before `Observability.install` resolves).
  final ObservabilitySink? inner;

  /// Invoked with every event BEFORE it reaches [inner]. Must never throw
  /// out of [add] — see the try/catch below.
  final void Function(ObsEvent event) onEvent;

  @override
  void add(ObsEvent event, {bool flushNow = false}) {
    try {
      onEvent(event);
    } catch (_) {
      // Fail-soft by contract — an overlay bug must never break capture.
    }
    inner?.add(event, flushNow: flushNow);
  }

  @override
  Future<void> flush() => inner?.flush() ?? Future<void>.value();

  @override
  Future<void> close() => inner?.close() ?? Future<void>.value();

  @override
  String? get sessionFilePath => inner?.sessionFilePath;
}
