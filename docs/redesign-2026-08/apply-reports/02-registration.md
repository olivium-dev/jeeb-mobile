# Apply report — 02 · Registration

**Status: applied** (blocked only on the wiring the instruction set told me to write as-if-granted).

Files changed:
- `lib/features/registration/presentation/registration_screen.dart` — rebuilt.
- `test/registration_screen_test.dart` — 1 string updated, 1 assertion added to the RTL test,
  3 tests added, 1 assertion strengthened.
- `docs/redesign-2026-08/wiring/02-registration.md` — created (3 requests).

No file outside this lane was touched. No new dependency. No `.arb`, theme, router, DI or kit edit.

---

## What I saw in the render that drove the build

1. The navy band is **full-bleed and paints under the status bar** — bottom-only ~36 radius, no
   shadow, ~22% of the screen. Today's implementation is an 80px inset rounded box with a centred
   logo and a separate `OMDSAppBar` above it. That app bar is gone.
2. Inside the band everything is **start-aligned**: wordmark → 26/w700 white headline → one
   periwinkle line that mixes Latin and Arabic. Not centred, not stacked with the form.
3. Two decorative arcs sit off-canvas in the top-**END** corner: a large faint white one (Ø200)
   and a small orange one (Ø120) closer to the corner. Both clipped by the band.
4. **The form is phone-first.** Today social sits above the divider and the phone field below it;
   the board inverts that — label → field → helper → CTA → `or` → social.
5. The field is a **container, not an `InputDecoration`**: grey fill, **2px navy** stroke, r16, a
   hairline divider between `+961` and the digits, and the tick pushed to the far end.
6. Orange appears exactly **twice**: the inner décor ring (30% stroke) and the ~20px validity
   tick. Nothing else. The CTA is navy, the "or" is not orange, the trust note is not orange.
7. The CTA is a **pill** (999) with a soft navy drop shadow — the only lift on the screen.
8. Social is a **compact two-up row**, Google at the start, thin brown outline, white fill.
9. The bottom **~40% is plain white emptiness** (plan R1), and the trust note is docked at the
   very bottom, not floating after the social row.

## Task-by-task

| Task | Done |
|---|---|
| 1 · shell | `OMDSAppBar` + `SafeArea` + padded scroll view deleted. Now `Semantics(registration_root) → AnnotatedRegion(light) → Scaffold → LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight) → IntrinsicHeight → Column[hero, Padding(24/24/24/0)(body), Spacer, trust note]`. |
| 2 · hero | **Consumed the kit**: `JeebNavySurfaceCard.topBand` + `JeebNavyRing.bandOuter/bandInner` (the kit ships 02's exact ring constants). `_WelcomeHeading` deleted; `Key('registration.welcome')` moved onto the in-band headline. |
| 3 · phone block | `_PhoneField` is now a `StatefulWidget` owning a `FocusNode`; label → container row → helper. Fill/stroke/radius/focus-ring moved out of `InputDecoration`. Tick is `ValueListenableBuilder` on the controller. No grouping formatter, controller-ownership machinery untouched. |
| 4 · CTA + divider | `OmdsLoadingButton` kept (type-pinned), wrapped in a `DecoratedBox` with `OmdsBorderRadius.pill` + `JeebShadows.ctaNavy`; `h56`, `jeebText.button`. `_OrDivider` restyled to `jeebText.bodySmall`, everything else untouched. |
| 5 · order + trust note | `_PhoneEntryBody` reordered phone-first; `_TrustNote` **consumes `JeebInfoNote.muted`** (kit) rather than hand-rolling the panel. |
| 6 · tests | See below. |
| 7 · wiring + gate | `wiring/02-registration.md` written; `dart analyze` delta is the 5 as-if-granted errors and nothing else. |

## Deliberate deviations from the instruction set (all upward)

1. **The instruction set says the kit is empty and to inline #4 and #22.** The 🛑 STOP block voids
   that. I imported `JeebNavySurfaceCard.topBand` and `JeebInfoNote.muted` instead. Both already
   carry 02's exact spec (the kit even ships `JeebNavyRing.bandOuter/bandInner` labelled "02").
2. **`textStyle` on `OmdsLoadingButton` must carry its own colour.** The instruction's snippet is
   `textStyle: context.jeebText.button` — but `omds_loading_button.dart:113-121` only inks its
   *default* style, so a supplied style with no colour inherits the body ink and the label would
   have gone navy-on-navy (invisible). I pass `.copyWith(color: colorScheme.onPrimary)`.
3. **The CTA shadow is conditional.** `boxShadow: canTap ? JeebShadows.ctaNavy : null` — kit §1.6
   "disabled CTAs drop their shadow"; the instruction's `const` decoration would have left a
   full-strength lift under a 60%-faded pill.
4. **The "Phone number" label is a tap target.** `.maestro/flows/jm-009-phone-otp.yaml:111` does
   `tapOn: text: "Phone number"` then `inputText:` — that string was the field's *hint* and is now
   a label above it. A `GestureDetector(opaque) → _focusNode.requestFocus` keeps the frozen flow
   working (and is correct label behaviour anyway).
5. **Flag ↔ dial-code gap is `Spacing.twoXSmall`, not `Spacing.small`.** The board draws
   `🇱🇧 +961` as one span separated by a literal space; 12px there reads as two separate items.
   All other row gaps are 12 as specified.
6. **`_TrustNote` has a top inset (`Spacing.xLarge`), not 0.** With the `Spacer` collapsed (short
   viewport, 200% text scale) a 0 top inset would let it touch the social row.

## Frozen inventory — verified emitted

`registration_root` · `_register_hero` (via the kit wrapper, `container` + `explicitChildNodes`
both set) · `_register_hero_logo` · `register_phone_field` (still on the `TextField` itself) ·
`register_phone_submit_cta`. New: `register_phone_valid_check`, `register_phone_helper`,
`register_trust_note`. Keys: `registration.phonePrefix` · `.phoneField` · `.sendCode` ·
`.welcome` · `.orDivider`; `.googleSignIn` / `.appleSignIn` still come from
`SocialSignInSection` untouched.

## Tests

- `find.text('مرحباً بك في جيب')` → `find.text('أهلاً بك يا جار')` (the one legitimate break).
- RTL test also asserts the AR tagline renders.
- FR-LOGIN hero test strengthened with `find.bySemanticsIdentifier('_register_hero')`.
- Added: tick opacity 0 → 1 (8 digits) → 0 (6 digits); trust note present + copy; helper carries
  the resting copy and swaps to `registrationPhoneInvalid` on the error path.
- Every other assertion in the file is untouched and should still hold — nothing in the
  controller-ownership path, the `sendCode(renderedPhone:)` path or the CTA type changed.

**These tests cannot run until the l10n wiring lands** (the screen references four getters that do
not exist yet). That is the as-if-granted contract, stated in §C-7 of the instruction set.

## Gate

`dart analyze lib/features/registration/presentation test/registration_screen_test.dart`
→ 11 errors, of which **6 belong to `otp_verification_screen.dart` (screen 03's lane, same
directory, concurrent)** and **5 are mine and are exactly the wiring dependencies** listed at the
top of `wiring/02-registration.md`. Zero lint infos, zero warnings, nothing else introduced.

Layout mechanics were verified in isolation with a throwaway widget test (since deleted): the
`Spacer`-inside-`SingleChildScrollView` trio docks the note at the bottom on a tall viewport,
degrades to a real scroll at 360×320, and mirrors under RTL without exceptions.
