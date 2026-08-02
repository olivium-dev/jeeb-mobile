/// Widget previews for [PendingReconnectBanner] — run with
/// `flutter widget-preview start`.
///
/// The banner is a pure function of one bool (`visible`): no cubit, no
/// repository, no clock. Nothing here can reach the network by construction,
/// well before the guard in [jeebPreviewHost] gets a say.
///
/// Because the widget has only two content states, the interesting axis is not
/// the data — it is the BOX. This banner is the first thing in the Pending tab,
/// so what a reviewer needs to see is how much vertical space it steals from
/// the list when the socket drops, and whether its [Row] still fits on the
/// narrowest phone the app supports. Each preview therefore pins a device width
/// and stacks a stand-in list-top under the banner; see [_listTop].
///
/// Two things about the harness are worth knowing before editing this file:
///
/// * **The spinner is frozen.** `OmdsLoadingState` is an indeterminate
///   [CircularProgressIndicator], which never stops scheduling frames — the
///   render tests' `pumpAndSettle` would hang forever on it. [_frozen] mutes the
///   ticker, which also makes the canvas rendering deterministic. A still
///   preview wants a still spinner anyway.
/// * **The widths are real widgets, not just canvas hints.** The `size` on
///   [JeebPreview] sizes the canvas, but the render tests pump at the default
///   800x600 surface, where every layout trivially fits. The explicit
///   [SizedBox] is what makes both readings agree.
library;

import 'package:flutter/material.dart';

import '../../features/home_client/presentation/tabs/pending_requests_tab.dart';
import '../harness/jeeb_preview.dart';

/// Reference phone width, matching the rest of the preview folder.
const double _phoneWidth = 390;

/// The narrowest phone the app still supports (and roughly what an Android
/// multi-window split leaves a foreground app).
const double _smallPhoneWidth = 320;

/// Banner (64) + the stand-in list-top, with headroom for the 200% rendering.
const Size _phoneBox = Size(_phoneWidth, 140);
const Size _smallPhoneBox = Size(_smallPhoneWidth, 140);

/// Two stacked surfaces, so the height comparison fits in one canvas.
const Size _comparisonBox = Size(_phoneWidth, 300);

/// Preview scaffolding — NOT part of the widget under review.
///
/// Stands in for the first row of the pending list so the banner has something
/// to push down. Without it "collapses to nothing" and "renders a 64pt strip"
/// look identical on an empty canvas.
Widget _listTop(String label) => Builder(
      builder: (BuildContext context) {
        final ThemeData theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Text(label, style: theme.textTheme.bodySmall),
        );
      },
    );

/// Mutes the banner's indeterminate spinner — see the library doc.
Widget _frozen(Widget child) => TickerMode(enabled: false, child: child);

/// The Pending tab as the banner sees it: a fixed-width column, banner first.
Widget _hosted({
  required bool visible,
  required String listTopLabel,
  double width = _phoneWidth,
}) =>
    _frozen(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              PendingReconnectBanner(visible: visible),
              _listTop(listTopLabel),
            ],
          ),
        ),
      ),
    );

/// The state users are in ~100% of the time: the socket is up and the banner is
/// not merely hidden but absent — `SizedBox.shrink()`, zero height.
///
/// Worth a preview precisely because it should be invisible: if this ever
/// reserves space, every pending list on every phone starts 64pt lower for no
/// reason. Compare against [pendingReconnectBannerHeightCost].
@JeebPreview(group: 'home_client', name: 'Connected (collapsed)', size: _phoneBox)
Widget pendingReconnectBannerHidden() => _hosted(
      visible: false,
      listTopLabel: 'Connected · list top',
    );

/// AC6 of T-MOB-007: the socket dropped and the tab is showing stale rows.
///
/// The reference reading. Note how much of the strip is chrome — the leading
/// `OmdsLoadingState` keeps its default `EdgeInsets.all(Spacing.large)`, so a
/// 16pt spinner claims a 56pt box and drives the whole banner to 64pt tall for
/// one 16pt line of text.
@JeebPreview(group: 'home_client', name: 'Reconnecting · 390 pt', size: _phoneBox)
Widget pendingReconnectBannerReconnecting() => _hosted(
      visible: true,
      listTopLabel: 'Reconnecting · 390 pt',
    );

/// The same banner with 70pt less to work with.
///
/// The [Row] holds the label with no [Flexible] and no `overflow`, so it cannot
/// ellipsize or wrap: it fits until it doesn't, and then it stripes. This is the
/// width where that margin gets thin, and it is the AR RTL rendering of this
/// preview — Arabic sets slightly wider here, and the matrix never renders
/// Arabic AND 200% together — that is worth actually looking at.
@JeebPreview(group: 'home_client', name: 'Reconnecting · 320 pt', size: _smallPhoneBox)
Widget pendingReconnectBannerNarrow() => _hosted(
      visible: true,
      listTopLabel: 'Reconnecting · 320 pt',
      width: _smallPhoneWidth,
    );

/// Both states stacked, because the defect is the DELTA, not either state.
///
/// A dropped socket does not overlay anything — it inserts a 64pt block above
/// the list, so every row jumps down by four times the height of the line of
/// text that caused it, and jumps back on reconnect. On a flaky connection that
/// is a list that will not hold still under the user's thumb.
@JeebPreview(group: 'home_client', name: 'Height cost (connected vs reconnecting)', size: _comparisonBox)
Widget pendingReconnectBannerHeightCost() => _frozen(
      Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          width: _phoneWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const PendingReconnectBanner(visible: false),
              _listTop('Height cost · connected'),
              const SizedBox(height: 24),
              const PendingReconnectBanner(visible: true),
              _listTop('Height cost · reconnecting'),
            ],
          ),
        ),
      ),
    );
