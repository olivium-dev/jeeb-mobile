/// Widget previews for [CustomerProfileRow] — run with
/// `flutter widget-preview start`.
///
/// The row is pure: an icon, a label, a semantics id, a tap callback and an
/// optional trailing widget. There is no cubit and no repository to stub, so
/// every state below is network-free by construction — the only inputs that can
/// change what it renders are the string it is handed and the widget in its
/// trailing slot. That makes the states worth reviewing string-shaped and
/// width-shaped, which is exactly where a `Row` of fixed-size leading/trailing
/// boxes around one [Expanded] label breaks.
///
/// The labels come from the ARB via [AppLocalizations] rather than English
/// literals, because the live caller (`CustomerProfileRows`, JM-035 AC2) passes
/// `l10n.*` for all eight rows — resolving them here means the **AR RTL dark**
/// rendering exercises the real "كلمة المرور والأمان", not a placeholder.
///
/// Three things these previews surface, all in the widget and none fixed here:
///
/// * **The label truncates instead of wrapping, and the row never grows.**
///   `Text(..., overflow: TextOverflow.ellipsis)` is passed without `maxLines`,
///   which caps the paragraph at one line rather than wrapping then
///   ellipsizing. Measured on a 390dp phone the label gets 286dp and the row
///   stays 56dp tall in every state below, including at 200% text — so a label
///   longer than its budget silently loses its tail. "Password and security"
///   wants 155dp at 1x (fine) and **307dp at 200% text**, i.e. the longest
///   Account label is already clipped at the accessibility ceiling the golden
///   tests assert. The Arabic "كلمة المرور والأمان" wants 327dp at 200% and
///   clips harder.
/// * **The trailing slot is charged to the label, not to the row.** A chevron
///   costs 16dp; the "Register" pill ([CustomerRegisterPill]) is an
///   intrinsic-width [OmdsPrimaryButton] that costs ~89dp, so the register row
///   hits the truncation ceiling far earlier than its seven siblings — 213dp of
///   label at phone width, 87dp on a 320dp phone at 200% text.
/// * **Dark mode makes the icon disc disappear.** `CustomerProfileIconDisc`
///   paints `Icon(color: onSecondary)` on a `secondaryContainer` fill. In the
///   light scheme those are hand-authored as white-on-navy (17.1:1), but the
///   dark scheme is `ColorScheme.fromSeed`, where `onSecondary` is the *dark*
///   ink meant for the light `secondary` tone: #2D2F42 on #444559 measures
///   **1.40:1**. The M3 pair for that fill, `onSecondaryContainer`, measures
///   7.23:1. Every AR RTL dark rendering below shows the same empty navy
///   circle.
library;

import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../features/customer_profile/presentation/widgets/customer_profile_row.dart';
import '../../features/customer_profile/presentation/widgets/customer_register_pill.dart';
import '../../l10n/app_localizations.dart';
import '../harness/jeeb_preview.dart';

/// The canvas box for one profile row on a phone: full width, one 56dp row plus
/// room to see the gap to its neighbours.
const Size _rowBox = Size(390, 88);

/// A 320dp-class phone, with room for the caption the narrow state carries.
const Size _narrowBox = Size(320, 128);

/// Caption used by [customerProfileRowNarrowPhone]. Dev-facing, so it is a
/// literal rather than an ARB key — it is what distinguishes that state from
/// [customerProfileRowRegisterPill] in the render test, which otherwise renders
/// the same row at a different width.
const String kNarrowPhoneCaption = 'Narrow phone · 320dp';

/// A plausible expansion of the password row's label — the shape a settings
/// label takes once someone appends the feature it actually opens. Exported so
/// the render test can pin the exact string it truncates.
const String kLongLabel =
    'Password, security and two-factor authentication settings';

/// The Arabic sibling of [kLongLabel]. A long English literal rendered in the
/// AR canvas proves nothing about Arabic — the glyphs, the shaping and the
/// truncation point all differ, and an RTL string clips at its own end.
const String kLongArabicLabel =
    'إعدادات كلمة المرور والأمان والمصادقة الثنائية للحساب';

/// One row, wired the way `CustomerProfileRows` wires it.
///
/// [label] is a callback over [AppLocalizations] so a state can either take the
/// real translated string (which changes between the EN and AR renderings) or
/// pin a literal it wants to stress-test. [width] pins the row to a real phone
/// width: a widget test pumps an 800dp surface, where every truncation below
/// disappears.
Widget _hosted({
  required IconData icon,
  required String Function(AppLocalizations l10n) label,
  required String semanticsId,
  Widget? trailing,
  double? width,
}) {
  final Widget row = Builder(
    builder: (BuildContext context) => CustomerProfileRow(
      icon: icon,
      label: label(AppLocalizations.of(context)),
      semanticsId: semanticsId,
      onTap: () {},
      trailing: trailing,
    ),
  );
  if (width == null) return row;
  return Align(
    alignment: AlignmentDirectional.topStart,
    child: SizedBox(width: width, child: row),
  );
}

/// The default shape: navy disc, muted label, directional chevron.
///
/// Two checks live here that the English light rendering cannot make. The AR
/// rendering is the mirroring check — the disc must move to the right edge and
/// the chevron must flip to `arrow_back_ios` via `DirectionalIcons`, because
/// [Icon] does not auto-mirror. The 200% rendering is the truncation check:
/// this label wants 307dp of the 286dp it is given, so the accessibility
/// ceiling clips the longest Account label rather than wrapping it.
@JeebPreview(name: 'Chevron row · localized', size: _rowBox)
Widget customerProfileRowDefault() => _hosted(
      icon: Icons.lock_outline,
      label: (AppLocalizations l10n) => l10n.customerProfilePasswordSecurity,
      semanticsId: 'customer_profile_password_row',
      width: 390,
    );

/// The one row whose trailing slot is not a chevron (JM-035 AC2).
///
/// This is the state the widget's own doc comment exists for: the row is a
/// [Row] rather than a [ListTile] so an intrinsic-width [OmdsPrimaryButton]
/// lays out cleanly. The cost is that the pill takes ~89dp off the label's
/// budget before the [Expanded] sees any of it (213dp here versus 286dp for a
/// chevron row), so this row reaches the truncation ceiling first — at 200%
/// text its label is cut to 157dp of the 289dp it wants.
///
/// Worth eyeballing in the AR RTL dark rendering: the 40dp navy pill sits on a
/// dark surface next to a disc whose glyph has vanished (see the library note),
/// which leaves the row reading as one navy blob.
@JeebPreview(name: 'Register pill trailing', size: _rowBox)
Widget customerProfileRowRegisterPill() => _hosted(
      icon: Icons.delivery_dining_outlined,
      label: (AppLocalizations l10n) => l10n.customerProfileRegisterAsDelivery,
      semanticsId: 'customer_profile_register_delivery_row',
      trailing: CustomerRegisterPill(onTap: () {}),
      width: 390,
    );

/// The overflow ceiling in English, at default text size.
///
/// The row does NOT grow — it truncates. `TextOverflow.ellipsis` with no
/// `maxLines` caps the paragraph at one line, so a 394dp label is clipped to
/// the 286dp it is given and the row stays 56dp tall. Whether that is
/// acceptable is a product call, but it means any ARB string (or translation)
/// wider than that budget silently loses its end instead of reflowing — and the
/// budget shrinks with screen width and with the trailing widget, and does not
/// grow with text scale.
@JeebPreview(name: 'Long label truncates', size: _rowBox)
Widget customerProfileRowLongLabel() => _hosted(
      icon: Icons.lock_outline,
      label: (AppLocalizations _) => kLongLabel,
      semanticsId: 'customer_profile_password_row',
      width: 390,
    );

/// The same ceiling in Arabic script, which is where the app's second locale
/// actually lands.
///
/// The AR RTL rendering must clip this at the row's *start* edge side — the
/// ellipsis belongs on the left — while the EN light rendering shows what an
/// RTL string does inside an LTR row: it must still hug the left edge and leave
/// the chevron at the right. Arabic is not a cosmetic variant here; the app
/// ships 1534 keys in both locales.
@JeebPreview(name: 'Long Arabic label truncates', size: _rowBox)
Widget customerProfileRowLongArabicLabel() => _hosted(
      icon: Icons.lock_outline,
      label: (AppLocalizations _) => kLongArabicLabel,
      semanticsId: 'customer_profile_password_row',
      width: 390,
    );

/// The worst square in the matrix: smallest supported phone, widest trailing
/// widget.
///
/// `CustomerProfileScreen` puts these rows in a [ListView] with no horizontal
/// padding, so on a 320dp device the row is the full 320dp and the label keeps
/// whatever the 48dp of internal padding, the 32dp disc, the 8dp gap and the
/// pill leave it — 143dp at 1x and **87dp at 200% text**, at which point the
/// row's own affordance text is what gets cut while the pill keeps its full
/// intrinsic width. The pill is the only thing here that never yields.
@JeebPreview(name: 'Narrow phone · pill squeeze', size: _narrowBox)
Widget customerProfileRowNarrowPhone() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _hosted(
          icon: Icons.delivery_dining_outlined,
          label: (AppLocalizations l10n) =>
              l10n.customerProfileRegisterAsDelivery,
          semanticsId: 'customer_profile_register_delivery_row',
          trailing: CustomerRegisterPill(onTap: () {}),
          width: 320,
        ),
        const SizedBox(height: Spacing.xSmall),
        Builder(
          builder: (BuildContext context) => Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: Spacing.xLarge,
            ),
            child: Text(
              kNarrowPhoneCaption,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      ],
    );

/// The list's only destructive action, rendered exactly like its neighbours.
///
/// "Sign out" gets the same `onSurfaceVariant` label, the same navy disc and
/// the same forward chevron as "Language" — nothing in the row says this one
/// does not open a screen. That is a design call the widget cannot make on its
/// own (it has no variant parameter), but it is only visible when the row is
/// reviewed next to a navigation row, which is what this state is for.
///
/// It doubles as the control case: at 111dp of a 286dp budget this label fits
/// even at 200% text, which proves the clipping in the states above is
/// content-driven and not a broken [Expanded].
@JeebPreview(name: 'Sign out · destructive', size: _rowBox)
Widget customerProfileRowSignOut() => _hosted(
      icon: Icons.logout_outlined,
      label: (AppLocalizations l10n) => l10n.appBarSignOut,
      semanticsId: 'customer_profile_logout_row',
      width: 390,
    );
