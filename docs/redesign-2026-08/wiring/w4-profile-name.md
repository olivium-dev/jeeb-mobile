# Wiring requests — w4 · profile-name (display-name setup step)

**Nothing here blocks this lane.** `lib/features/profile_name/` compiles clean, analyzes clean and
its 16 tests are green **without** any of the below. This is one request I could not code against,
recorded so the integrator can decide — not a dependency.

---

### The text input is the one part of the screen still off the design language

file: `tool/check_design_tokens.sh` (shared gate) **or** a new `lib/core/widgets/jeeb/` widget
(shared kit) — either owner, not both.

what: the board's text input (02 `tpl 90-104`) is a **filled `surfaceContainerHigh` slab, r16,
2px `colorScheme.primary` border, `JeebShadows.focusRing` on focus**, with a standalone navy
`cardTitle` label *above* it and a `bodySmall` helper line beneath. `OmdsTextField` — the only
input primitive the gate allows in `lib/features` — renders the opposite: white fill, 1px
cool-neutral border, an M3 floating label, no helper slot. Its white-outlined treatment is a
deliberate OMDS decision (`omds_text_field.dart` "P0-X03"), so a screen-local `fillColor` override
would reintroduce exactly what that P0 fixed.

Screen 02 solved this by hand-rolling a raw `TextField` and taking a **named exemption** in the
gate (`registration_screen.dart`, JEEB-55/JEEB-57). Two ways to close it for everyone else:

1. **Preferred — kit widget.** Add `JeebTextField` to `lib/core/widgets/jeeb/` (the kit is exempt
   from the gate, §4.4), lifting the field body out of `_PhoneField` minus the +961 prefix row:
   label slot, hint, helper/error line, `enabled`, `textCapitalization`, `identifier`. It has at
   least three consumers today (02's phone field, this screen's name field, 06's transcript edit).
2. **Fallback — extend the exemption** in `tool/check_design_tokens.sh`'s "Raw TextField" check
   from `registration_screen\.dart` to the screens that need the board's field, and let each lane
   hand-roll it. Cheaper now, three divergent fields later.

exact change (fallback form only):
```sh
check_pattern \
  "Raw TextField            ->  use OmdsTextField or OmdsValidatedTextField" \
  '\bTextField\(' \
  'OmdsTextField|OmdsValidatedTextField|registration_screen\.dart|display_name_setup_screen\.dart'
```

why it matters here: the field IS the screen — it is the only content between the headline and the
CTA. Everything around it (24px gutters, `jeebText.h1` navy headline, `jeebText.body` subtitle,
`JeebCtaButton` pill + bare text exit, top-aligned block over real white) is now on the system;
the input is the last piece that still reads as stock Material.

no l10n, no route, no DI, no pubspec change requested by this lane.
