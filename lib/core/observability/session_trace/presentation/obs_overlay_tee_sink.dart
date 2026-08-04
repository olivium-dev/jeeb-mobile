import '../model/obs_event.dart';
import '../observability.dart';

final class ObsOverlayTeeSink implements ObservabilitySink {
  ObsOverlayTeeSink({required this.inner, required this.onEvent});

  final ObservabilitySink? inner;

  final void Function(ObsEvent event) onEvent;

  @override
  void add(ObsEvent event, {bool flushNow = false}) {
    try {
      onEvent(event);
    } catch (_) {
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
