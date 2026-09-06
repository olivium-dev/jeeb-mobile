import 'package:get_it/get_it.dart';

/// Stage-2 hook for the request-creation funnel: nothing to register today —
/// the moderation ack reuses the registered `ProhibitedAcknowledgmentRepository`.
void registerRequestSummaryDependencies(GetIt getIt) {}
