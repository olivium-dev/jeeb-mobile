/// Re-export shim — sanity-build pass (2026-05-17).
///
/// app_router.dart imports from this path. The wave-2-4 batch placed the
/// implementation at `presentation/onboarding_screen.dart`. Rather than
/// rewrite the router, we re-export the concrete class here so both paths
/// point at the same widget.
library;
export 'presentation/onboarding_screen.dart';
