# Wiring requests — w3-customer-profile

Both items below are **non-blocking**: the customer-profile lane shipped without either, using a
call-site workaround. They are filed because the workaround is a duplication a shared owner can
delete.

---

## 1. `DirectionalIcons.signOut` (shared: `lib/core/widgets/directional_icons.dart`)

`Icons.logout` ships with `matchTextDirection: false`, so its arrow keeps pointing at the LTR end
edge inside an Arabic layout. `settings_footer.dart:141-145` already declares a private
`_signOutGlyph` const to fix that, and `customer_profile_rows.dart` now declares a byte-identical
second copy. Two copies of a raw codepoint is one Flutter upgrade away from drifting.

Paste-ready, into `DirectionalIcons`:

```dart
  /// `Icons.logout` with `matchTextDirection: true` — the stock glyph does not
  /// mirror, so the exit arrow points at the LTR end edge under RTL. The
  /// codepoint is repeated because `IconData` only accepts const arguments;
  /// callers should keep an `assert(signOut.codePoint == Icons.logout.codePoint)`
  /// if they want a loud failure on a Flutter upgrade.
  static const IconData signOut = IconData(
    0xe3b3,
    fontFamily: 'MaterialIcons',
    matchTextDirection: true,
  );
```

Then delete `_signOutGlyph` from both `settings_footer.dart` and `customer_profile_rows.dart` and
pass `DirectionalIcons.signOut`.

---

## 2. Ink override on `JeebVerifiedBadge` (shared: `lib/core/widgets/jeeb_verified_badge.dart`)

`JeebVerifiedBadge` hardcodes `colorScheme.secondaryContainer` (navy). The customer-profile identity
card is now a `JeebNavySurfaceCard`, where a navy glyph is invisible. The lane worked around it with
a scoped `Theme(...)` that re-points `secondaryContainer` for the badge subtree only
(`customer_profile_header.dart` `_NameBadge`) — correct, but obscure.

Two options, in preference order:

**(a) make it tone-aware** (preferred — no call-site change anywhere, matches the kit's
`JeebSurfaceTone` contract):

```dart
    final tone = JeebSurfaceTone.of(context);
    final ink = tone.onNavy
        ? tone.titleInk
        : Theme.of(context).colorScheme.secondaryContainer;
```

**(b) add an optional `color`**:

```dart
    this.color, // null -> colorScheme.secondaryContainer
```

Either lets `_NameBadge` drop its `Theme` wrapper. `delivery_man_profile_header.dart` (the only
other consumer, on a light surface) is unaffected by both.
