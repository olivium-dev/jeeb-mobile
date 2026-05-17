import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
// Deviation note: router call-site passes a `deliveryId` (deep-link route
// param); the field is retained but unused so the import-graph stays green.
class RatingPromptScreen extends StatefulWidget {
  const RatingPromptScreen({super.key, required this.deliveryId});

  final String deliveryId;

  @override
  State<RatingPromptScreen> createState() => _RatingPromptScreenState();
}

class _RatingPromptScreenState extends State<RatingPromptScreen> {
  static const _featureId = 'rating-prompt';

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
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Rating Prompt coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
