import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/client_unreachable_screen_fixtures.dart';

class ClientUnreachableScreen extends StatelessWidget {
  const ClientUnreachableScreen({super.key, required this.deliveryId});
  final String deliveryId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'client_unreachable_root',
      container: true,
      child: Scaffold(
        appBar: const OMDSAppBar(title: 'Client Unreachable'),
        body: Padding(
          padding: const EdgeInsets.all(Spacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _UnreachableNoticeCard(),
              const SizedBox(height: Spacing.xLarge),
              Semantics(
                identifier: 'client_unreachable_call_again_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Try Calling Again',
                  variant: OmdsButtonVariant.outlined,
                  icon: const Icon(Icons.phone),
                  onTap: () {},
                ),
              ),
              const SizedBox(height: Spacing.small),
              Semantics(
                identifier: 'client_unreachable_chat_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Send Chat Message',
                  variant: OmdsButtonVariant.outlined,
                  icon: const Icon(Icons.chat),
                  onTap: () {},
                ),
              ),
              const Spacer(),
              Semantics(
                identifier: 'client_unreachable_flag_cta',
                container: true,
                button: true,
                child: OmdsPrimaryButton(
                  text: 'Flag as Unreachable',
                  backgroundColor: Theme.of(context).colorScheme.error,
                  onTap: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreachableNoticeCard extends StatelessWidget {
  const _UnreachableNoticeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.medium),
        child: Column(
          children: [
            Icon(
              Icons.phone_disabled,
              size: Sizes.fourXLarge,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: Spacing.small),
            Text(
              'Cannot reach the Client',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: Spacing.xSmall),
            Text(
              'If the Client is not responding, you can flag them as '
              'unreachable. They will have 15 minutes to respond before the '
              'delivery is escalated.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for

/// The canvas box for a phone frame plus the fixture's outline and caption.
const Size _clientUnreachableScreenPhoneCanvas = Size(402, 888);

/// The same, for the smallest supported display.
const Size _clientUnreachableScreenCompactCanvas = Size(332, 612);

/// Builds the screen for [fixture] and hands it to the shared host.
/// The `ClientUnreachableScreen(...)` is constructed HERE rather than inside the
Widget _clientUnreachableScreenHosted(
  ClientUnreachableScreenFixture fixture,
) =>
    ClientUnreachableScreenPreviewHost(
      fixture: fixture,
      screen: ClientUnreachableScreen(deliveryId: fixture.deliveryId),
    );

/// The reference reading: an ordinary phone, default text, live tracking still
/// underneath so the app bar has a back arrow and `pop(true)` has a caller.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Phone · from live tracking',
  size: _clientUnreachableScreenPhoneCanvas,
  matrix: true,
)
Widget clientUnreachableScreenPhone() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.phone,
    );

/// A stack-replacing arrival, carrying a REAL delivery id rather than the
/// catalog's demo one.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Cold arrival · nothing to pop',
  size: _clientUnreachableScreenPhoneCanvas,
)
Widget clientUnreachableScreenColdArrival() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.coldArrival,
    );

/// The smallest display the app supports, at DEFAULT text — no accessibility
/// setting involved.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Compact 320 × 568',
  size: _clientUnreachableScreenCompactCanvas,
)
Widget clientUnreachableScreenCompact() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.compact,
    );

/// The accessibility ceiling on an ORDINARY phone — 200% text on 390 x 844.
/// **This card overflows, and the stripes you see are real.** `Padding >
@JeebPreview(
  group: 'client_unreachable',
  name: 'Phone · 200% text',
  size: _clientUnreachableScreenPhoneCanvas,
)
Widget clientUnreachableScreenLargeText() => _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.phoneLargeText,
    );

/// The worst case the app supports: the smallest display, the largest text, and
/// a stack with nothing to pop.
@JeebPreview(
  group: 'client_unreachable',
  name: 'Compact · 200% text',
  size: _clientUnreachableScreenCompactCanvas,
)
Widget clientUnreachableScreenCompactLargeText() =>
    _clientUnreachableScreenHosted(
      ClientUnreachableScreenFixtures.compactLargeText,
    );
