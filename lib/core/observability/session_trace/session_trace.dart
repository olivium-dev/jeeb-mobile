/// Jeeb session-trace observability tool.
///
/// The richer, unified, interaction-aware sibling of the `[jeeb-diag]`
/// stream (`lib/core/diagnostics/`) — records screen, api, notification, and
/// interaction signals into one ordered, redacted, per-session JSONL file.
/// Runs ALONGSIDE `diag`; never modifies it. Devtool + runtime gated (see
/// [kObsCompiledIn] / `ObservabilityConfig`) — a zero-cost no-op in any
/// production build. See the architecture contract for the full design.
library;

export 'model/obs_event.dart';
export 'observability.dart';
export 'observability_config.dart';
export 'secret_redactor.dart';
export 'obs_file_writer.dart';

// The following are exported by each module's own PR as its capture/export
// file lands (Phase 1, built in parallel against this frozen core — see the
// architecture contract §10). Uncomment the corresponding line when that
// file exists:
export 'capture/obs_nav_observer.dart'; // Module 1 — screen
export 'capture/obs_dio_interceptor.dart'; // Module 2 — api
export 'capture/obs_notification_recorder.dart'; // Module 3 — notif.
export 'capture/obs_interaction_observer.dart'; // Module 4 — interaction

//   export 'export/obs_trace_export.dart';           // Module 5 — export
//   (not yet landed — no file exists at this path; keep commented until it does)
//
// NOTE: presentation screens are imported explicitly by the router/dev UI,
// NOT re-exported here (mirrors diagnostics.dart keeping
// diagnostics_screen.dart out of the barrel).
