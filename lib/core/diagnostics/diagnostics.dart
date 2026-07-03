/// Jeeb diagnostic event stream (`[jeeb-diag]`).
///
/// One structured JSON line per event — navigation, API call, or domain event —
/// under a stable logcat prefix so agents / Codex can grep exactly which screens
/// opened, which APIs were called, and which domain events fired during a device
/// run. Debug/dev-only; see [Diag] for the build gate and wire format, and
/// `docs/diagnostics.md` for schemas + example greps.
///
/// Persistence + export (diag-persistence lane): [DiagFileSink] tees the stream
/// into rotated on-device JSONL session files; [DiagExport] carries the pure
/// export helpers (adb one-liner). The dev-only Settings → Diagnostics screen
/// lives in `diagnostics_screen.dart` (imported explicitly by the router — it
/// is presentation, not stream API, so it stays out of this barrel).
library;

export 'diag.dart';
export 'diag_dio_interceptor.dart';
export 'diag_export.dart';
export 'diag_file_sink.dart';
export 'diag_nav_observer.dart';
export 'diag_redaction.dart';
