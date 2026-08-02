/// Widget previews for [ShellHeaderActions] — run with
/// `flutter widget-preview start`.
///
/// This widget renders **no text of its own** and takes exactly one argument
/// ([ShellHeaderActions.idPrefix], a Semantics id scope). Previewing it on its
/// own would therefore produce five identical pairs of icons, and a render test
/// could not tell one preview from another — the exact failure `expectedText`
/// exists to catch. What actually varies, and what breaks, is the **context**.
///
/// The shell paints this row as a floating OVERLAY on a tab body it does not
/// own. `_HeaderedTab` in `lib/features/shell/shell_screen.dart` (private
/// there, mirrored below as [_HeaderedTab]) stacks it over the tab with
/// `PositionedDirectional(top: 0, end: Spacing.xSmall)` inside a
/// `Material(color: Colors.transparent)` — no scrim, no reserved gap. Whether
/// that lands cleanly is entirely the host screen's decision, and the three
/// production hosts disagree:
///
/// * `customer_profile` — [CustomerProfileHeader] reserves `Sizes.fiveXLarge`
///   (56 dp) of top inset, with a comment saying it is there "to clear the
///   shell-overlaid header actions". This is the host that got it right.
/// * `orders_home` — [ClientHomeGreeting] reserves nothing and puts its filled
///   "+" create-request button in the very same corner.
/// * `delivery_tab` — [JeeberHomeGreeting] reserves nothing and lets its
///   greeting line run the full content width, straight under the icons.
///
/// So each preview below is the widget in one of those real compositions, built
/// from the real host widgets rather than a strawman, plus a caption naming the
/// state. The caption is preview chrome (`labelSmall` / `onSurfaceVariant`) and
/// is deliberately unlocalized: it names the *state*, not the product, so
/// English in the AR RTL rendering is expected.
///
/// **Network-free by construction.** The widget owns no cubit and no
/// repository; the host headers are fed plain fixture values (the ones from
/// `test/customer_profile_screen_test.dart`) with `avatarUrl: null`, so nothing
/// resolves an image or a request. [jeebPreviewHost]'s `CatalogNetworkGuard` is
/// the net, not the plan.
///
/// **Do not tap in the canvas.** Both buttons call `context.goNamed`, and a
/// preview has no `GoRouter` above it, so a tap throws. These are for looking
/// at. The role gate the widget documents (F6 / JEBV4-303: an *active* jeeber
/// reaches the bidding wallet hub, a client the cash-on-delivery stub) is for
/// the same reason not previewed — it only changes `goNamed`'s target, renders
/// identically in every theme and locale, and belongs to a routing test.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/customer_profile/presentation/widgets/customer_profile_header.dart';
import '../../features/home_client/presentation/widgets/client_home_greeting.dart';
import '../../features/jeeber_home/presentation/widgets/jeeber_home_greeting.dart';
import '../../features/shell/widgets/shell_header_actions.dart';
import '../harness/jeeb_preview.dart';

/// A phone-width slice of a tab: a real trailing edge to pin against, and room
/// for the header the overlay lands on.
const Size _tabBox = Size(390, 260);

/// The narrow phones still in the fleet (iPhone SE, Galaxy A0x): same height,
/// 70 fewer logical pixels for the greeting line to fit beside the overlay.
const Size _narrowTabBox = Size(320, 260);

/// The bare row needs no tab underneath it, only room for its caption at 200%.
const Size _rowBox = Size(390, 140);

/// The rated, verified customer from `test/customer_profile_screen_test.dart`.
const String _kProfileName = 'Sami Fawaz';
const String _kProfileEmail = 'kamalhaaj@gmail.com';

/// Longest plausible single-token first name. The greeting widgets show the
/// FIRST name only, so a long *first* name — not a long full name — is what
/// actually pushes a greeting line into the overlay.
const String _kLongFirstName = 'Abdulrahmanalmuhandis';

/// One specimen: the widget in its host composition, with a caption naming the
/// state.
///
/// Pass [body] to place the actions over a real tab surface (the production
/// shape); omit it for the bare row on its own.
Widget _hosted({
  required String caption,
  required String idPrefix,
  Widget? body,
}) {
  return _Specimen(
    caption: caption,
    child: body == null
        ? _BareRow(idPrefix: idPrefix)
        : _HeaderedTab(idPrefix: idPrefix, body: body),
  );
}

/// The component on its own: two [IconButton]s in a `mainAxisSize.min` [Row],
/// 96 × 48 dp, outlined here so the footprint is visible.
///
/// Worth one state of its own because this is the only rendering where nothing
/// else competes for the corner. Three things to check: both glyphs clear the
/// 48 dp tap floor (they do — [IconButton] enforces it, and it does NOT grow at
/// 200% text, so the box in the third rendering is the same 96 × 48); the
/// wallet chip is tinted `colorScheme.primary` while the bell is
/// `colorScheme.onSurface`, so they read at deliberately different weights; and
/// in **AR RTL** the pair mirrors as a unit — the bell stays on the screen-edge
/// side, the wallet stays inboard.
@JeebPreview(group: 'shell', name: 'Actions only', size: _rowBox)
Widget shellHeaderActionsBareRow() => _hosted(
      caption: 'Actions only · 96 × 48 dp',
      idPrefix: 'orders_home',
    );

/// **The state that breaks**: the Requests tab (`orders_home`, JM-023).
///
/// [ClientHomeGreeting] is the first child of the HomeTab's `ListView` with
/// `Spacing.medium` (16 dp) of top padding and reserves nothing for the
/// overlay, while its filled "+" create-request button sits at the trailing
/// edge behind `Spacing.medium` of padding. Measured at 390 dp: the "+" button
/// occupies `LTRB(326, 16, 374, 64)` and the bell `LTRB(334, 0, 382, 48)` — a
/// 40 × 32 dp intersection, about 55% of the "+" button's area. The overlay is
/// the LAST child of the shell's `Stack`, so it also wins the hit test there:
/// a tap on the top-trailing corner of "+" opens Notifications instead of
/// starting a request. At 200% text the "+" only drops to y 20 and the overlap
/// survives.
///
/// The two glyphs also share space with the greeting line, whose ellipsized box
/// ends at x 314 — under the wallet chip's 298-322 glyph.
@JeebPreview(group: 'shell', name: 'Requests tab', size: _tabBox)
Widget shellHeaderActionsRequestsTab() => _hosted(
      caption: 'Requests tab · orders_home',
      idPrefix: 'orders_home',
      body: ListView(
        children: <Widget>[
          ClientHomeGreeting(name: 'Sami', onAddPressed: () {}),
        ],
      ),
    );

/// The same collision at the width where it hurts, with the longest plausible
/// first name.
///
/// Two independent squeezes land together here: the trailing "+" button and the
/// overlay do not move relative to the screen edge, so on a 320 dp phone they
/// take the same absolute bite out of a line that has 70 fewer pixels to give.
/// The greeting ellipsizes earlier, and what is left of it still ends beneath
/// the wallet chip. This is the rendering to check first in **AR RTL** — the
/// whole arrangement mirrors, so the failure moves to the leading edge rather
/// than disappearing.
@JeebPreview(group: 'shell', name: 'Requests tab · narrow + long name', size: _narrowTabBox)
Widget shellHeaderActionsRequestsNarrowLongName() => _hosted(
      caption: 'Requests tab · long name at 320 dp',
      idPrefix: 'orders_home',
      body: ListView(
        children: <Widget>[
          ClientHomeGreeting(name: _kLongFirstName, onAddPressed: () {}),
        ],
      ),
    );

/// The jeeber dashboard (`delivery_tab`), which the shell only mounts for a
/// user with the jeeber role.
///
/// [JeeberHomeGreeting] has no trailing button, so nothing competes for the tap
/// — but it also reserves nothing, and its greeting line is a full-width [Text]
/// rather than a shrink-wrapped one: measured at 390 dp its box is
/// `LTRB(16, 16, 374, 44)`, and the overlay occupies 286-382. With a long first
/// name the glyphs run under both icons, and because the shell wraps the
/// actions in `Material(color: Colors.transparent)` there is no scrim to
/// separate them — text and icon simply overlap.
@JeebPreview(group: 'shell', name: 'Jeeber dashboard', size: _tabBox)
Widget shellHeaderActionsJeeberDashboard() => _hosted(
      caption: 'Jeeber dashboard · delivery_tab',
      idPrefix: 'delivery_tab',
      body: ListView(
        children: const <Widget>[JeeberHomeGreeting(name: _kLongFirstName)],
      ),
    );

/// The host that gets it right: the Profile tab (`customer_profile`, JM-035).
///
/// [CustomerProfileHeader] opens with `Sizes.fiveXLarge` (56 dp) of top inset
/// specifically to clear this overlay, so the avatar and identity block start
/// below the icons and nothing collides. Reviewed side by side with the
/// Requests states, this is the reference for what the other two hosts are
/// missing — and the evidence that the fix belongs in the hosts (or in a
/// reserved inset the shell injects), not in [ShellHeaderActions] itself.
///
/// It also carries the second half of the `idPrefix` contract: the same widget
/// must expose `customer_profile_wallet_chip` / `customer_profile_bell` here
/// and `orders_home_*` above, so the two headers never emit duplicate ids —
/// the regression `test/customer_profile_screen_test.dart` guards from the
/// screen's side.
@JeebPreview(group: 'shell', name: 'Profile tab', size: _tabBox)
Widget shellHeaderActionsProfileTab() => _hosted(
      caption: 'Profile tab · customer_profile',
      idPrefix: 'customer_profile',
      body: ListView(
        children: const <Widget>[
          CustomerProfileHeader(
            name: _kProfileName,
            email: _kProfileEmail,
            avatarUrl: null,
            isVerified: true,
            rating: 4.8,
            ratingCount: 42,
          ),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// Fixtures. Nothing below is production code.
// ---------------------------------------------------------------------------

/// The shell's overlay, reproduced.
///
/// A copy of `_HeaderedTab` in `lib/features/shell/shell_screen.dart`, which is
/// private and cannot be imported: same `Stack`, same
/// `PositionedDirectional(top: 0, end: Spacing.xSmall)`, same transparent
/// `Material`. If the shell's stacking ever changes, this is the fixture to
/// update — the whole point of these previews is that the composition is real.
///
/// The inner [SafeArea] is copied too, and is a no-op in both the canvas and
/// the app: the shell's own `Scaffold` body already consumed the top inset
/// above the tab, so the overlay and the tab body share one origin. That is
/// exactly why the collisions below are not artefacts of the preview.
///
/// The outline is preview chrome — it marks where the tab's trailing edge is,
/// which is the whole question in every state.
class _HeaderedTab extends StatelessWidget {
  const _HeaderedTab({required this.idPrefix, required this.body});

  final String idPrefix;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: body),
          PositionedDirectional(
            top: 0,
            end: Spacing.xSmall,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: ShellHeaderActions(idPrefix: idPrefix),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The actions with nothing behind them, outlined so the 96 × 48 dp footprint
/// is measurable by eye.
class _BareRow extends StatelessWidget {
  const _BareRow({required this.idPrefix});

  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border.all(color: colors.outline)),
        child: Material(
          color: Colors.transparent,
          child: ShellHeaderActions(idPrefix: idPrefix),
        ),
      ),
    );
  }
}

/// The specimen frame: the composition under review, with a caption naming the
/// state beneath it.
///
/// The caption sits below so it reads as a label on the frame rather than as
/// part of the header inside it, and is capped at two lines so the 200%-text
/// rendering shrinks the frame instead of overflowing the canvas box.
class _Specimen extends StatelessWidget {
  const _Specimen({required this.caption, required this.child});

  final String caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.xSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: child),
          const SizedBox(height: Spacing.xSmall),
          Text(
            caption,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
