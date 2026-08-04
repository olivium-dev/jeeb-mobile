export const meta = {
  name: 'midnight-m6-fixes',
  description: 'M6 phase 2 — seven lanes composed FROM the four audits per-directory groupings',
  phases: [{ title: 'Fix', detail: 'core theme+glow · core kit · platform chrome · jeeber · chat+client · kyc+money · settings+auth' }],
}
const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'

const COMMON = `
Repo ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch. GOLDEN RULE: code comments max 2 lines, only when super necessary.
Read docs/redesign-midnight/01-TOKEN-SHEET.md + 02-STUDY-NOTES.md first; every ruling binds you.

**THE SESSION'S MOST PRODUCTIVE DEFECT SIGNATURE — and the grep that finds it.** Under Midnight \`colorScheme.primary\` IS \`#D73B00\`, so pass-1 code treating it as navy renders ORANGE. **Use the BROAD pattern \`\\.(primary|tertiary)\\b\`, not \`colorScheme.primary\`** — the audit's first narrow grep missed 21 sites because they alias the scheme to a local (\`final scheme = theme.colorScheme; … scheme.primary\`), including the worst one. \`tertiary\` is a compat ALIAS of primary (same hex), so it leaks identically.
Distinguish a legitimate accent CTA from a leak. The audit verified these as LEGITIMATE — do not touch: the voice mic disc+halo, the map route polyline, the money-field lit border, the offer-accept CTA fill.
**Also fix any pass-1 COMMENT that is now false** (e.g. asserting primary is navy) — a false comment is what produced several of these leaks.

**CLASS 3b — the finding that changes how you work.** Files importing NO \`core/widgets/jeeb/\`, no \`jeeb_text_styles\`, no \`jeeb_semantic_colors\` were never given a Midnight pass at all; the orange is a SYMPTOM. The audit's words: *"A fix lane that only recolours the line will leave a light-theme-shaped surface behind."* Where a file in your list is one of these, restyle the surface — field/ink/surface rungs — not just the offending colour. (Caveat the audit itself raised: zero kit imports is a proxy, not proof; look before assuming.)

CONSTRAINTS: tokens/kit only; ZERO raw hex, ZERO \`Colors.*\` (transparent ok). Preserve frozen test identifiers by re-homing. RTL-safe: prefer \`EdgeInsetsDirectional\`/\`AlignmentDirectional\`. Respect \`MediaQuery.disableAnimations\`.
**Goldens are evidence, NOT gates** (5% tolerance — a real ink swap moved 0.097% and three goldens stayed green carrying the wrong colour). Land per-element assertions read off the widget and PROVE each discriminates by reverting the value and confirming red.
**EXCLUDED — production-dead pending owner ruling Q-043, do not touch:** lib/features/delivery_status/, lib/features/tier_selection/presentation/, lib/features/prohibited_acknowledgment/.
Analyze baseline: 0 errors / 30 known infos. KNOWN-RED and NOT yours: dio_tier_repository (2) · gesture_log (1) · ~12 files under test/previews/.
VERIFY: flutter analyze --no-pub <your dirs> → 0 errors · targeted tests before/after · re-capture affected states.
RETURN: findings handled (file:line each) · leaks fixed vs verified-legitimate · 3b surfaces genuinely restyled vs recoloured · false comments corrected · before/after counts · discrimination proof · anything left.`

const LANES = [
{ label: 'core: theme + glow rulings', dirs: 'lib/core/theme/**, lib/core/widgets/jeeb/jeeb_midnight_field.dart', body: `
**APPLY THE RATIFIED GLOW SURVEY (settles Q-027/Q-034/Q-036 after four milestones).** The survey censused all 30 tiles; I accept all three rulings.

**A — alpha: ONE constant \`0.24\`.** Collapse \`_FieldSpec.resolve\`'s per-variant alpha switch. Evidence: α distribution over 17 tiles has mode AND median .24; total L1 error single-.24 = .58 vs **the shipped hero-.28/content-.22 split = .68 — one number beats the split by 15%**. Variant explains only 5.2% of variance. And \`hero\` is correct for ZERO screens: its only two consumers are R1 (board .32) and R4 (.26), and .28 misses both in opposite directions. **The variant enum's real job is the LAYER SET; alpha is orthogonal and must stop riding on it.**
**B — radius AND aspect, changed TOGETHER:** \`_glowRadiusFactor = 500/440\` (1.13636) and \`_glowAspect = 420/500\` (0.84). Board rx mode+median = **500**, not the 520 my own §8 correction claimed; ry mode+median = 420. The shipped 1.18 reproduces ry correctly BY ACCIDENT (1.18×440×420/520 = 419.4), so changing radius alone would drag ry to 404 and break the one dimension currently right. Net: rx 519→500, ry unchanged.
**C — fade \`.58\`.** 16 of 29 in-scope radials declare 58; only 4 declare the shipped .60.
**Per-screen overrides the ruling's ledger calls for** (the right tail is real but per-screen, not a rung — those tiles already use \`glowColor\` overrides): R2 →.40 · R1 add .32 · R5+W1 →.30 · R18 →.26 · R6 →.28 · R22 →.20. Apply only where the screen file is NOT owned by another lane this wave; list any you could not reach.
**The wave-B discriminating radius test currently proves 1.18 against 1.35 — move its expected value and keep it discriminating.**

**ALSO — 7 unset Material sub-themes in \`app_theme.dart\` (audit L1–L7), each falling through to a Material default:** \`bottomSheetTheme.modalBarrierColor\` unset → black54 across 15 sheets · \`datePickerTheme.todayBackgroundColor\`/\`yearBackgroundColor\` unset → **ORANGE** · \`iconTheme\`/\`primaryIconTheme\` unset → white icons · \`expansionTileTheme\` unset → orange chevron · \`dropdownMenuTheme\` unset → bare outline field · \`pageTransitionsTheme\` unset → a \`#0B1351\` transition slab · the unthemed-navy cluster (\`DropdownButton\` canvasColor vs popupMenuTheme; drawer/rail/banner at \`#0A1147\`). 02-STUDY-NOTES §Theme ruling 5 deferred drawer/rail/search/dropdown/segmentedButton/expansionTile/scrollbar/badge/banner to exactly this sweep — close them.` },

{ label: 'core: kit + notifications', dirs: 'lib/core/widgets/jeeb/ (EXCEPT jeeb_midnight_field.dart), lib/core/notifications/, lib/core/observability/, lib/devtool/', body: `
- **L15, the widest-reach item in the audit:** \`jeeb_top_bar.dart\` is not an \`AppBar\`, so \`appBarTheme.systemOverlayStyle\` never applies — **status-bar chrome is unset on ~44 screens.** Make the kit top bar carry the overlay style itself (an \`AnnotatedRegion\`), so every consumer gets it without 44 call-site edits.
- **R15-4 — the kit doc is WRONG and caused an open question.** \`jeeb_select_chip.dart:56-58\` tells call sites to wrap in \`MinTapTarget\`, stating a requirement WCAG does not impose. The AA audit settled it: **WCAG 2.2 SC 2.5.8 (AA) is 24×24 CSS px** — 48dp is Material *guidance*, and 44×44 is SC 2.5.5 which is **AAA**. Every chip role clears 24×24 with 37–71% headroom. Correct the doc; do NOT change chip geometry.
- \`jeeb_stepper.dart:154\` \`washedInk = Color(0x59FFFFFF)\` is the one raw hex a \`Color(0x\` gate trips on forever. The VALUE is right (wave-C ruling 11 deliberately kept 35% off the glass ladder); the HOME is wrong. Give it a named const in the palette that is explicitly not a glass rung, or an explicit exemption marker — say which you chose.
- \`lib/core/notifications/\` push_banner_host + notification_permission_prompt, \`lib/core/observability/\` obs_overlay_event_tile: Class-3b files (zero kit imports) — restyle, don't just recolour.
- devtool L16/L17 + \`catalog_screen.dart:105,108\` \`Colors.black54\`/\`Colors.white\` (outside the sanctioned 3 field paints), \`actions_page.dart:349\`. Low user impact but they sit in the tree the capture harness mounts.` },

{ label: 'platform chrome + registration', dirs: 'ios/, lib/app/, lib/features/registration/, lib/features/biometric_auth/, lib/features/biometric_login/, lib/features/profile_name/, lib/features/onboarding/', body: `
- **THE MOST LITERAL VIOLATION OF "no white flash anywhere", and one no widget test could ever catch:** \`ios/Runner/Base.lproj/LaunchScreen.storyboard:22\` sets \`backgroundColor\` to solid white and the LaunchImage assets are 68-byte 1×1 stock placeholders — **every iOS cold start flashes full-screen white before Flutter's first frame.** Fix it to the Midnight page navy \`#070C33\`. This is on the real-device path, so it matters directly for M7.
- **L14:** six sites set a raw \`SystemUiOverlayStyle.light\` and so leave the **Android nav bar black** instead of navy — registration, biometric_auth, biometric_login, profile_name, onboarding, and \`app/branded_splash.dart\`. Fix consistently; if the kit top bar gains an \`AnnotatedRegion\` this wave (a sibling lane owns that), prefer consuming it over repeating raw styles.
- **L12** \`branded_splash.dart:88\` tagline measures **1.17:1** — effectively invisible. **L13** \`app.dart:640-650\` renders an empty-stack frame over the native (white) window background.
- **3c, a real semantic regression:** \`registration/presentation/super_login/super_login_picker.dart:411-416\` branches client→\`primaryContainer\` / jeeber→\`tertiaryContainer\`, but \`app_theme.dart:23,32\` map BOTH to \`orangeContainer\` — **the ternary is a no-op and the two role badges render identically.** Dev-facing, low user impact, but it is a genuine regression, not cosmetic. Fix by choosing roles that actually differ.
- \`super_login_entry_points.dart:114,145\` underlined links (Class 3b).
- **\`lib/features/auth/social/social_sign_in_button.dart\` is NOT yours** — another lane owns it.` },

{ label: 'jeeber surfaces', dirs: 'lib/features/jeeber_request_feed/, lib/features/jeeber_active_deliveries/, lib/features/jeeber_home/', body: `
- **\`request_card.dart:367\` is the strongest instance of the signature in the whole app: FOUR orange elements per feed row — \`_LocationRow\`'s pin glyph rendered TWICE (pickup + dropoff) plus \`_EarningsBadge\`'s icon AND text — under a comment at \`:358\` that reads "The money figure. Navy, not orange: … the accent is reserved for the do-it-now moment."** Fix the code to match its own comment.
- \`active_deliveries_banner.dart:177\` (disclosure summary title) and \`:313\` (destination line), plus the \`??\` fallback twin at \`jeeber_home/.../jeeber_active_deliveries_banner.dart:210\`. **Fix all three together or you split the pair** that the wave-C ruling and its pair test require to stay identical.
- **L9:** \`OmdsSearchBar\` renders an ORANGE focus ring in jeeber_home (also location and registration, owned by other lanes — fix only your instance).` },

{ label: 'chat + client offers + home + shell', dirs: 'lib/features/chat/, lib/features/client_offers/, lib/features/home_client/, lib/features/shell/', body: `
- \`chat/presentation/widgets/order_chat_pinned_summary.dart:579\` — the "Track" pill paints fill \`onPrimary\` (**white slab**) with ink \`primary\` (**orange**): an orange-on-white pill inside the navy chat strip. The file's header comment is the false rationale that produced it — fix both.
- **Class 3b (never restyled — restyle, don't recolour):** \`chat/.../confirm_delivery_action_sheet.dart:178,205\` · \`chat/.../offer_card_bubble.dart:175,235,249\` (\`:249\` is \`OmdsStarRatingDisplay activeColor: tertiary\` — §3 gives **amber \`#FFC107\`** for stars/ratings) · \`client_offers/.../offer_accept_sheet.dart:176,304\` · \`home_client/.../pending_request_card.dart:82\` · \`home_client/.../active_request_card.dart:122,212,294\` · \`shell/tabs/chat_tab.dart:110\` · \`shell/widgets/shell_header_actions.dart:39\` (R1's header glyphs are WHITE).
- **\`active_request_card.dart:294\` is the orange-spinner signature:** \`LinearProgressIndicator(valueColor: tertiary)\`. \`progressIndicatorTheme\` already inks bare indicators periwinkle, so this explicit override is the ONE that escapes the theme. \`:212\` is a tier-badge FALLBACK, so an *unknown* tier renders orange.
- **THREE sheet drag handles painted solid orange independently** (\`confirm_delivery_action_sheet:178\`, \`offer_accept_sheet:304\`, and \`cancel_request_sheet:243\` owned by another lane). The audit's read: *"a pattern, not three accidents — worth one shared decision."* Make the decision for your two and state it so the sibling lane can match.
- **L8:** pale-periwinkle sheet scrim in chat/ and client_offers/ (also settings, cancel_request, auth — other lanes).
- **PREVIEW LIES worth fixing even though previews are not shipped:** \`chat_bubble_timestamp.dart:83\` draws the sender's bubble as a SOLID \`primary\` slab when R20's shipped outgoing bubble is \`bubbleOutFill\` (orange @24%) + 45% border — the preview misrepresents the shipped widget.` },

{ label: 'kyc + money + tracking', dirs: 'lib/features/kyc/, lib/features/goods_cost/, lib/features/order_summary/, lib/features/voice_request/, lib/features/live_tracking/', body: `
- \`kyc_status_view.dart:312\` h1 title ink (wave-B ruling: \`onSurface\` is the heading ink app-wide) · \`:434\` pending hourglass (a PENDING state wants \`jeebRoles.warning\`/\`info\`, never accent) · \`:720\` approved glyph (wants \`jeebRoles.success\`).
- **\`goods_cost_screen.dart:357\` \`cursorColor: scheme.primary\` directly violates theme ruling 4 ("Cursor/selection periwinkle stands app-wide") — unambiguous.** Also \`:353\` amount ink. \`:302\` rest-state field border is a PLAUSIBLE carry of R9's lit-field treatment — decide with the tile in hand and say which way you ruled.
- \`order_summary/.../order_summary_pinned.dart:446\` \`jeebText.price\` ink on a read-only summary — same class as the transaction-detail leak already fixed.
- \`voice_request/.../voice_recording_screen.dart:435,436,438\` \`OmdsSeekBar\` active + buffered + thumb. **Wave-A ratified R2's waveform live ink as \`#D73B00\`, so an orange playback track is arguable — but three orange elements on a review surface whose CTA is Send is not, and \`bufferedColor == activeColor\` is wrong regardless.** Rule it and say why.
- \`live_tracking_screen.dart:807\` \`trackingAtDoorCta\` is **probably LEGITIMATE** — \`jeeb_color_roles.dart:104\` explicitly sanctions accent for "the at-door arrival banner". Re-point it to \`context.jeebRoles.accent\` so the intent is legible to the next grep rather than looking like a leak.
- **L10:** light-default map flash before the dark style applies.
- Do NOT touch \`tracking_google_map.dart:183\` (route polyline) or \`animated_mic_button.dart:81,83\` — audit-verified legitimate.` },

{ label: 'settings + auth + location + receipt', dirs: 'lib/features/settings/, lib/features/cancel_request/, lib/features/auth/, lib/features/location/, lib/features/delivery_receipt/', body: `
- **L8 sheet scrim** (pale periwinkle) in settings/, cancel_request/, auth/. **L11** \`delivery_receipt/\` opaque-black lightbox barrier. **L9** \`OmdsSearchBar\` orange focus ring in location/. **L10** light-default map flash in location/.
- **Class 3b:** \`cancel_request_sheet.dart:143\` (6XL help glyph), \`:243\` (**drag handle** — a sibling lane is deciding the shared drag-handle treatment for two others; match it) · \`auth/social/social_collision_sheet.dart:46\` (\`person_off_outlined\` — arguably wants \`error\`).
- **\`auth/social/social_sign_in_button.dart\` — DO NOT "fix" the 5 raw hex.** They are third-party identity brand marks (\`#4285F4\` Google, \`#1877F2\` Facebook, white) required by Apple App Store review item 4.0 and Google Identity branding; the file carries the rationale and JEEB-57. **My ruling: record them as a NAMED EXEMPTION** so the M6 gate asserts "≤5 hex outside theme, all in social_sign_in_button.dart" instead of a plain zero. Add the exemption to the guard test and say exactly how you expressed it.` },
]

phase('Fix')
const r = await parallel(LANES.map((l) => () => agent(
  `YOUR DIRECTORIES: ${l.dirs}.\n${l.body}\n${COMMON}`,
  { label: l.label, phase: 'Fix', model: 'opus' },
)))
return Object.fromEntries(LANES.map((l, i) => [l.label, r[i]]))
