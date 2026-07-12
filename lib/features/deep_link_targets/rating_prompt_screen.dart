import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Placeholder governed by `qa/t-mob-fix-001/placeholder-discipline.sh`
/// (Type-A list, JEB-137). The full Jeeber-profile-with-reviews UI for this
/// route is the deliverable of `T-MOB-RATING-001` and ships only after the
/// CI gate is lifted (this file removed from `TYPE_A_FILES`). Until then,
/// every rule asserted by that script holds on every PR; do NOT add
/// behavior, action buttons, loading indicators, dialogs, snackbars, or
/// l10n hooks here, and keep the AC5 logger inside `initState`.
///
/// The router call-site passes a `deliveryId` (deep-link route param); the
/// field is retained but unused so the import-graph stays green.
// ORPHAN (JEBV4-227, verified 2026-07-12): route always redirects to mutual-rate in production; builder dead except in dev-catalog capture — see docs/project-understanding/reconciliation/orphans.md
class RatingPromptScreen extends StatefulWidget {
  const RatingPromptScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<RatingPromptScreen> createState() => _RatingPromptScreenState();
}

class _RatingPromptScreenState extends State<RatingPromptScreen> {
  static const String _featureId = 'rating-prompt';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Rating Prompt coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: OMDSAppBar(title: 'Rate your Jeeber', showBackButton: true),
        icon: Icons.construction_outlined,
        title: 'Rating Prompt coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
