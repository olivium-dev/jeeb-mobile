import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
// Deviation note: router call-site passes a `chatId` (deep-link route param);
// the field is retained but unused so the import-graph stays green.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const _featureId = 'chat-detail';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Chat Detail coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Chat Detail coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}
