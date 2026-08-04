# Wiring requests — 04 · Client home

Companion to `per-screen-revised/04-client-home.md` (the authoritative spec). Lane code is written
as if every request below is already granted; the serialized integrator applies them.

> Preamble note for the integrator/owner: 04 builds the board's mic hero, which supersedes the
> 2026-07-22 "single create entry point" directive's plus-button implementation while preserving
> its intent (one create surface). The retired `client_home_voice_request` id is NOT revived;
> negative pins stay green. Deliberate copy divergences: hero subtitle says "tap" not "hold"
> (no auto-start seam in `VoiceRecordingScreen`; if literal hold-to-talk is wanted, the 05 lane
> must expose an `autoStartRecording` seam), "Searching for Jeebers…" kept over "Broadcasting",
> "Check Offers" kept over "View offers".

```
### l10n
file: lib/l10n/app_en.arb
need: five new keys for the 04 hero subtitle, greeting eyebrow, and replies offer floor.
exact change:
  "homeGreetingEyebrowMorning": "Good morning",
  "@homeGreetingEyebrowMorning": { "description": "Greeting eyebrow above the name on the client home header, device-local hour < 12." },
  "homeGreetingEyebrowAfternoon": "Good afternoon",
  "@homeGreetingEyebrowAfternoon": { "description": "Greeting eyebrow, device-local hour 12–16." },
  "homeGreetingEyebrowEvening": "Good evening",
  "@homeGreetingEyebrowEvening": { "description": "Greeting eyebrow, device-local hour >= 17." },
  "homeHeroSubtitle": "Tap the mic to talk · or type instead",
  "@homeHeroSubtitle": { "description": "Subtitle inside the client-home mic hero. Deliberately says 'tap', not the board's 'hold' — no auto-start recording seam exists." },
  "homeRepliesOffersFloor": "{offers} · from {amount}",
  "@homeRepliesOffersFloor": {
    "description": "Replies-card meta line combining the pluralized offers count with the lowest quoted fee. {offers} is the pre-pluralized pendingCardOffersBadge string; {amount} is pre-formatted by MoneyFormat (LTR-isolated).",
    "placeholders": { "offers": { "type": "String", "example": "3 offers" }, "amount": { "type": "String", "example": "$8.00" } }
  },
why: the 04 hero and replies card render these; l10n parity gate requires EN+AR together.

### l10n
file: lib/l10n/app_ar.arb
need: Arabic values for the same five keys.
exact change:
  "homeGreetingEyebrowMorning": "صباح الخير",
  "homeGreetingEyebrowAfternoon": "مساء الخير",
  "homeGreetingEyebrowEvening": "مساء الخير",
  "homeHeroSubtitle": "اضغط الميكروفون للتحدث · أو اكتب بدلاً من ذلك",
  "homeRepliesOffersFloor": "{offers} · ابتداءً من {amount}",
why: AR/EN parity; the ARB owns its own separator/order so the Dart caller never concatenates.

### l10n
file: lib/l10n/app_localizations.dart
need: getters for the five keys, matching the hand-rolled _get pattern (cf. :1492, :1852).
exact change:
  String get homeGreetingEyebrowMorning => _get('homeGreetingEyebrowMorning');
  String get homeGreetingEyebrowAfternoon => _get('homeGreetingEyebrowAfternoon');
  String get homeGreetingEyebrowEvening => _get('homeGreetingEyebrowEvening');
  String get homeHeroSubtitle => _get('homeHeroSubtitle');
  String homeRepliesOffersFloor(String offers, String amount) =>
      _get('homeRepliesOffersFloor')
          .replaceFirst('{offers}', offers)
          .replaceFirst('{amount}', amount);
why: feature code reads these through AppLocalizations; there is no gen_l10n step.

### cross-feature
file: lib/core/widgets/jeeb/ (kit lane)
need: six kit behaviors 04 depends on, all consistent with plan §5 rows #3/#4/#6/#7/#9/#23.
exact change: (constraints, not code — kit lane implements)
  1. JeebNavySurfaceCard: shadow:none variant + off-canvas Ø140 accentRing at top-END,
     ClipRRect'd (04 hero is the consumer the plan names for both).
  2. JeebSelectChip: optional `count`; selected renders it as inline text, unselected as the
     Ø18 solid-orange badge (white 11/w800, pad 0/4) — and in BOTH modes the count is a
     SEPARATE Text widget from the label, so find.text label pins survive.
  3. JeebTierChip: emoji and label are two Text children, never one string —
     find.text('سريع')/('إكسبرس') are pinned (client_home_screen_test.dart:577-607); must
     accept the five-tier enum via a per-feature mapper or generic label/emoji params.
  4. JeebAvatar: compose OmdsProfileAvatar internally and forward a caller-supplied Key —
     Key('client-home-greeting-avatar') keeps 7 greeting tests green
     (client_home_greeting_test.dart:75-78 casts tester.widget<OmdsProfileAvatar>).
  5. JeebAvatarStack: caller-composable trailing (+N stays the caller's Text) and the dormant
     fill (surfaceContainerHighest + periwinkle initial) when no URL/name.
  6. JeebProfileHeader: `trailing` nullable + a `trailingReserve` (end-side width) param — 04
     must reserve Spacing.fourXLarge*2 under the shell's overlaid ShellHeaderActions.
why: every design-exact px on 04 (46/56/24/30/−9/1.5/999) is banned in lib/features by
tool/check_design_tokens.sh and legal only inside the kit.

### cross-feature
file: test/features/shell/home_tab_create_request_fab_test.dart
need: rewrite the four top-plus cases for the hero without weakening the disabled-create guard.
exact change: replace find.byKey(Key('client-home-greeting-add')) (:107, :151) with
find.bySemanticsIdentifier('orders_create_request_button'); assert the node exists AND has a tap
action (non-null handler) in all dev-seam variants; keep :121 as-is; keep the negative pins
:129 (client_home_voice_request absent) and :135 (Key('client-home-voice-cta') absent) VERBATIM.
why: the guarded defect (create surface rendering with a null callback from the shell) outlives
the + button; the file lives in the shell's test tree, so the serialized integrator applies it.
```

---

## Status of the kit requests (verified 2026-08-03, after Wave 1 landed)

All six kit behaviors in the fourth block **already shipped** — they are recorded above for the
audit trail, not as outstanding work:

| # | Shipped as | Verified at |
|---|---|---|
| 1 | `JeebNavySurfaceCard.noShadow` + `JeebNavyRing.heroTopEnd` (Ø140, top −40, end −40) | `jeeb_navy_surface_card.dart:33-34, 121-135` |
| 2 | `JeebSelectChip.count` — inline `Text` when selected, `_JeebChipCountBadge` when not | `jeeb_select_chip.dart:155-162` |
| 3 | `JeebTierChip` — `Text(emoji)` + `Text(label)`, five-tier `JeebTier` + `fromId` | `jeeb_tier_chip.dart:16-66, 160-178` |
| 4 | `JeebAvatar.avatarKey` forwarded to the composed `OmdsProfileAvatar` | `jeeb_avatar.dart:261-263, 290-299` |
| 5 | `JeebAvatarStack.trailing` + `JeebAvatarEntry.fillForIndex` dormant fallback | `jeeb_avatar_stack.dart:11-30, 51` |
| 6 | `JeebProfileHeader.trailingReserve` (nullable `trailing`) | `jeeb_profile_header.dart:31-32, 118-121` |

**Still outstanding: the three l10n blocks and the shell test.** Until the l10n block lands,
`dart analyze` reports five undefined-getter errors in `lib/features/home_client` — that is the
whole of this lane's analyze delta and it clears the moment the integrator applies the ARB + getter
edits.

## Not requested (verified unnecessary)

- **Router** — `voice-request` is registered (`app_router.dart:1059-1060`, `backFallbacks:481`) and
  `request-type` already backs the empty-state CTA. Zero route edits.
- **DI** — no new repository/service; the offer floor rides the existing `/v1/offers` probe.
- **Theme** — Wave 0 shipped everything 04 reads (`jeebText`, `JeebSemanticColors.mutedText`,
  `jeebRoles.accent`).
- **Shell bottom bar / header** — `shell_screen.dart:301-325` already overlays
  `ShellHeaderActions`; 04's header reserves space for it via `trailingReserve` and requests
  nothing.
