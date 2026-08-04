# Findings triage

24 wave documents, **836 findings**. Nobody is going to read that in order, so this
is the index: what to fix first, what is one fix rather than many, and what is noise.

**How to read the counts below.** They are keyword matches over the wave docs, not a
curated tally — they overlap, and a single finding that mentions both contrast and
overflow is counted twice. Treat them as *where the mass is*, not as a bug count. The
named items further down are individually verified and quoted from the wave docs.

---

## 1. Fix these first — user-visible loss or a dead end

Ordered by what a user loses, not by how hard it is.

| # | What happens | Where |
|---|---|---|
| 1 | **Editing your name deletes your avatar.** `_onSave` omits `photoUrl`; `copyWith` reads the resulting `null` as "clear the field". Success path, under a "Profile saved." snackbar. | `ProfileEditScreen` — SCREENS_WAVE03 |
| 2 | **Every jeeber home base is stored at (0, 0).** `_pickHomeBase` writes `lat: 0, lng: 0` on BOTH branches, and the label is the literal field label. Matching cannot work for that jeeber. | `DmOnboardingServiceAreaStep` — WAVE10 |
| 3 | **`/location` serves a "coming soon" placeholder** while a 461-line implementation sits unused, imported only by the Screen Catalog. | `app_router.dart:970` — FINDING_location_picker_placeholder |
| 4 | **A dead request can be a screen with no reachable affordance** — no back arrow (route can't pop on a push arrival) and the only CTA 616pt below a viewport that cannot scroll. | `JeeberRequestUnavailableScreen` — SCREENS_WAVE04 |
| 5 | **A refund shows both the order AND dispute link.** Gated on data, not row type. The existing test passes only because its fixture omits `orderId` — which the shipped repository sets. | `TransactionDetailScreen` — SCREENS_WAVE02 |
| 6 | **KYC submit has no way out.** All four wired states render an identical frame; after the probe budget there is no retry, cancel, elapsed hint or error branch anywhere on screen. | `KycSubmittingView` — WAVE12 |
| 7 | **The accept sheet clips Confirm AND Cancel** at large text with the capacity banner — a customer who loses the accept race can neither retry nor dismiss. | `OfferAcceptSheet` — WAVE14 |
| 8 | **Deleting your account shows the sign-out copy.** `both` mode keeps `signOutDialogTitle`/`Body`, so the E20 purge terms — 30-day grace, active-order block, reversal — never appear on the surface that offers the irreversible action. | `LogoutDeleteConfirmSheet` — WAVE15 |

**Needs verification before it is believed:** `ChatTab` may be structurally empty
against the live gateway — it `continue`s past every row lacking a `conversationId`,
which the real `/v1/requests` row does not carry. Reasoned from the sibling parser
(`dio_order_repository._parseOrder`), **not** observed against the gateway. If it
holds, the chat inbox is empty in production. (WAVE08)

---

## 2. One fix, many sites — do these as a sweep, not per widget

| Pattern | Sites | Status |
|---|---|---|
| A `*Container` colour role painted as **ink** — ~2:1 in dark, ~17:1 in light so light-only review never sees it | **11** | **FIXED** + source guard (`a79c205`) |
| `OMDSStepperProgress` **fill does not mirror in RTL** — raw canvas coords, never reads `Directionality`. Everything around it flips; only the fill does not, so an Arabic user watches the bar appear to empty as they advance | 2 known | open — one OMDS fix |
| `OmdsPrimaryButton` / `OmdsLoadingButton` pin `height: 48` and centre the label, which **follows the text scaler while the pill does not** — label clipped at 200% | 5+ | open — one OMDS fix |
| `OmdsReviewCard` derives its avatar initial with `RegExp(r'[a-zA-Z]')`, so **every Arabic name gets the "?" placeholder** for an unknown account | 2 | open — one OMDS fix |
| Icons with `applyTextScaling` left false beside text that doubles | many | open — theme-level `iconTheme` |
| A non-flex child in a `Row` claims its intrinsic width first and **starves the `Expanded` sibling to zero** | very many | open — the single most common shape in this corpus |

That last row is where most of the 376 overflow matches live. It is worth a lint
rather than 100 individual fixes.

---

## 3. Fixes that landed on some call sites and not others

The sweep found the same fix missing on siblings three times. Each was invisible
because nothing links the files.

- **JEBV4-286** — `_ButtonLabel` (Flexible + ellipsis) applied to one of two
  near-identical banners, then later to a card but not its parent's disclosure row.
  At 200% the title reaches **0px** and the row overflows. (WAVE07, WAVE19)
- **sprint-009 §T5** — synthetic-handle suppression reached `ClientHomeGreeting`,
  the offer cards and the chat summary, but **not** `CustomerProfileHeader`,
  `ProfileAvatar` or `FeedbackAvatar` — so the profile screen shows
  `jeeb-<hash>` and `phone-only+<hash>@jeeb.internal`. (WAVE11, WAVE15)
- **The periwinkle text audit** — `onSecondaryContainer` ruled out for text in four
  files, missed in `DeliveryManMetaRow` (3.76:1). (WAVE13)

---

## 4. Things that are true of the tests, not the code

Worth reading before trusting any existing suite here.

- `tracking_header_overflow_test.dart` **cannot see** a 732dp overflow because it
  pumps a 914dp-tall surface — 732 fits and `takeException()` stays null.
- `TransactionDetailScreen`'s row overflow is invisible to its widget test only
  because `flutter_test`'s default 800pt surface is **wider than any phone**.
- Several id-based contracts (`customer_wallet_stub_done`,
  `notif_prefs_transactional_lock_icon`) are **absent from the widget and semantics
  trees on arrival** at 320×568 or 200% text, because a `ListView` stops building
  past its cache extent. A driver querying them finds nothing.

**Measurement caveat that applies to most pixel numbers in the wave docs:** they are
taken under `flutter_test`'s square test font, which is wider than the shipped Inter
— roughly double for Arabic. The *structural* claims ("no `maxLines` on an unbounded
`Text`") are solid; treat exact thresholds as pessimistic upper bounds, not device
reproductions. Several agents flagged this themselves.

---

## 5. Known debt, deliberately not fixed

- `tool/preview_blocked.txt` — in scope, needs a production seam first. Currently
  `LiveSettingsScreen`.
- `tool/preview_exclusions.txt` — out of scope by category (behavioural wrappers,
  platform views, dev-only surfaces).
- **5 pre-existing test failures** on this branch, verified to fail identically with
  `lib/` reverted. `gesture_log.dart` has zero commits in this campaign, so that one
  predates it; the other four are unattributed against `main`.
- The local Flutter SDK carries a one-line patch (`initiallyExpanded: false`) so the
  canvas opens collapsed. **Global to the machine, reverts on `flutter upgrade`.**

---

## 6. The overflow numbers are inflated — measured, not suspected

Every wave doc carries a caveat that pixel figures come from `flutter_test`'s
square font. Wave 07 turned that from a caveat into a measurement, and it is worse
than "treat thresholds as upper bounds".

`test/previews/preview_test_harness.dart` does not load real fonts, so text lays
out in Flutter's default face where every glyph is a 1-em square:

| string | test face | real face |
|---|---|---|
| `Flag as Unreachable` | 304.0 px | **154.7 px** |
| `تعذر الوصول إلى العميل` | 352.0 px | **147.9 px** |

Latin ~2x too wide, Arabic ~2.4x. Wiring `loadInterTestFont()` +
`withGoldenTestFonts()` into the harness — both of which this repo already has,
and which **seven preview tests reached for independently** after hitting phantom
AR overflows — moves the suite from

    5344 pass / 0 fail   ->   5217 pass / 127 fail

Those 127 are assertions that PIN an overflow. Under real fonts the overflow does
not happen, so the assertion fails. **127 of 5344 (2.4%) were pinning a defect
that does not exist on any device.**

### What this does and does not invalidate

- **Structural claims stand.** "This `Text` has no `maxLines` inside an unbounded
  `Row`" is true regardless of typeface, and that is the shape of most §1 and §2
  findings.
- **Any specific "overflows by N px at M% text" is suspect**, especially Arabic
  ones and especially near a threshold. A finding that only ever manifested as a
  number, with no structural cause named, should be re-verified before anyone
  spends time on it.
- **The §1 list is unaffected** — those are data loss, dead ends and wrong copy,
  none of which are measured in pixels.

### Why the harness was not simply fixed

Turning it on retroactively red-lines 127 assertions mid-rollout and blocks the
loop's integration gate. Fixed forward instead: the harness now documents the trap,
and new preview tests are told to load the real fonts (the workflow prompt says so
too). The 127 legacy assertions are the backlog — each needs re-checking under real
fonts and either correcting to assert a clean layout or deleting.
