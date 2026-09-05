import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_cta_footer.dart';
import '../../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import 'client_unreachable_l10n.dart';

/// Board gutter + block rhythm (redesign-2026-08 §4.3): 24px sides, 16px above
/// the first block. The docked [JeebCtaFooter] owns the bottom edge.
const EdgeInsetsGeometry _kBodyPadding = EdgeInsetsDirectional.fromSTEB(
  Spacing.xLarge,
  Spacing.medium,
  Spacing.xLarge,
  Spacing.medium,
);

// ORPHAN (JEBV4-227, verified 2026-07-12): zero refs; live flow is live_tracking + tracking_noshow_sheet — see docs/project-understanding/reconciliation/orphans.md
//
/// redesign-2026-08: re-skinned onto the Jeeb kit — the Material app bar became
/// the in-body [JeebTopBar], the `errorContainer` slab became a [JeebInfoNote]
/// in the same error role (Wave 0's soft tint, kit geometry), the two recovery
/// actions became outline [JeebCtaButton]s and the escalating edge is docked in
/// a [JeebCtaFooter] over real white emptiness (R1) — the structure its journey
/// neighbour `live_tracking_screen.dart` already uses. Same flow, same actions,
/// same order, same copy, same identifiers.
class ClientUnreachableScreen extends StatelessWidget {
  const ClientUnreachableScreen({
    super.key,
    required this.deliveryId,
    this.onCallAgain,
  });

  final String deliveryId;

  /// Placing the masked call. Null routes to the order hub, which owns every
  /// contact affordance — the control was `onTap: () {}` before.
  final VoidCallback? onCallAgain;

  void _callAgain(BuildContext context) {
    final handler = onCallAgain;
    if (handler != null) {
      handler();
      return;
    }
    context.pushNamed(
      'order-detail',
      pathParameters: <String, String>{'id': deliveryId},
    );
  }

  @override
  Widget build(BuildContext context) {
    final copy = ClientUnreachableL10n.of(context);
    return Semantics(
      identifier: 'client_unreachable_root',
      container: true,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              JeebTopBar.back(
                title: copy.title,
                identifier: 'client_unreachable_back',
              ),
              // The scroll view exists only so 200% text scale cannot overflow
              // the fixed column; at 1.0x the lower half stays plain white
              // (R1) with the escalating CTA docked below it.
              Expanded(
                child: SingleChildScrollView(
                  padding: _kBodyPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Same `errorContainer` role as the card it replaces —
                      // the re-skin adopts the kit's geometry and Wave 0's soft
                      // tint, it does not re-classify the state.
                      JeebInfoNote.error(
                        icon: Icons.phone_disabled,
                        title: copy.noticeTitle,
                        text: copy.noticeBody,
                      ),
                      const SizedBox(height: Spacing.large),
                      Semantics(
                        identifier: 'client_unreachable_call_again_cta',
                        container: true,
                        button: true,
                        child: JeebCtaButton.outline(
                          label: copy.callAgainCta,
                          leadingIcon: Icons.phone,
                          onTap: () => _callAgain(context),
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Semantics(
                        identifier: 'client_unreachable_chat_cta',
                        container: true,
                        button: true,
                        child: JeebCtaButton.outline(
                          label: copy.chatCta,
                          leadingIcon: Icons.chat,
                          onTap: () => context.pushNamed(
                            'chat-detail',
                            pathParameters: <String, String>{'id': deliveryId},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              JeebCtaFooter.single(
                child: Semantics(
                  identifier: 'client_unreachable_flag_cta',
                  container: true,
                  button: true,
                  // Navy pill, not a red slab: the board draws the escalating
                  // edge of this journey (12's `Report no-show` / `Open
                  // dispute`) with no red at all, and the kit has no
                  // destructive variant. The warning is carried by the note
                  // above and by the label itself.
                  child: JeebCtaButton(
                    label: copy.flagCta,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
