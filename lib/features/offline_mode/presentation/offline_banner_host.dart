import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../application/offline_cubit.dart';
import 'offline_banner.dart';

/// Seats [OfflineBanner] above the router content: a route's ModalBarrier is a
/// `BlockSemantics`, so a banner painted BEFORE it emits no semantics (F5).
class OfflineBannerHost extends StatelessWidget {
  const OfflineBannerHost({super.key, required this.child});

  /// The router content the notice rides above.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfflineCubit, OfflineState>(
      builder: (BuildContext context, OfflineState state) {
        // The banner already sits under the status bar; the content below must
        // not reserve that inset twice.
        final bool shown = OfflineBanner.showsFor(state);
        // Reversed main axis: the first child is laid out LAST in the column
        // yet painted FIRST, so the banner's semantics survive the barrier.
        return Column(
          verticalDirection: VerticalDirection.up,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: shown
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: child,
                    )
                  : child,
            ),
            const OfflineBanner(),
          ],
        );
      },
    );
  }
}
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for the preview
// canvas and the preview tests.

/// Phone-sized: the host claims the whole page, banner plus content.
const Size _offlineBannerHostBox = Size(390, 420);

/// Seats the host over a stand-in page, which is what the app's router content
/// is to it — and, in the canvas, sits under a real route's ModalBarrier.
Widget _offlineBannerHostHosted({
  required String caption,
  required OfflineCubit Function() episode,
}) {
  return BlocProvider<OfflineCubit>(
    key: ValueKey<String>(caption),
    create: (BuildContext _) => episode(),
    child: OfflineBannerHost(
      child: Builder(
        builder: (BuildContext context) => ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Center(child: Text(caption)),
        ),
      ),
    ),
  );
}

/// The shape F5 exists for: the notice on top, the page below it, and the
/// banner painted LAST so its semantics survive the route barrier.
@JeebPreview(
  group: 'offline_mode',
  name: 'Host · notice over the page',
  size: _offlineBannerHostBox,
  matrix: true,
)
Widget offlineBannerHostOffline() => _offlineBannerHostHosted(
      caption: 'setOffline() · banner seated above the page',
      episode: () => OfflineCubit()..setOffline(),
    );

/// Connected: the host must cost nothing at all — the page keeps every pixel.
@JeebPreview(
  group: 'offline_mode',
  name: 'Host · online, full bleed',
  size: _offlineBannerHostBox,
)
Widget offlineBannerHostOnline() => _offlineBannerHostHosted(
      caption: 'OfflineCubit() · page owns the whole box',
      episode: OfflineCubit.new,
    );
