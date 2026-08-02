import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

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
