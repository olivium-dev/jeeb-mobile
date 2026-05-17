import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  static const _featureId = 'saved-addresses';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Saved Addresses coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Saved Addresses coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
