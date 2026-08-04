# Jeeb — Design System

**Jeeb (جيب)** is a voice-first, peer-to-peer delivery marketplace that formalizes Lebanon's informal WhatsApp errand economy into a trusted app. You say what you need; nearby verified couriers ("Jeebers") send price-and-time offers within minutes; you pick the best one and follow your order to your door — paying cash on delivery.

> **اطلب. قارن. استلم.** — *Order. Compare. Receive.*
> **جيب، مشوارك أسهل** — *Jeeb — your errand made easier.*

The name is the product: **Jeeb** is Lebanese-Arabic for **"bring (me)"** — the exact phrase you'd text a friend (*"جيب لي…"*). It also means **"pocket."** A courier is a **Jeeber** — a title, not a job.

This design system captures the **navy-led, orange-accented** identity of the shipped mobile app, its bilingual (AR ⇄ EN, RTL-aware) type system, the five-tier urgency spectrum, and the reusable UI used across the Client and Jeeber experiences.

---

## Sources (the reader may or may not have access — recorded for provenance)

- **Brand & marketing brief** — the working brief these foundations are derived from (navy+orange canonical palette, tone, lexicon, tier system, KPIs).
- **Live Flutter app theme** — `jeeb-mobile/lib/core/theme/app_theme.dart`, `jeeb_tier_colors.dart` (canonical palette + tier colors).
- **Figma file** — "Jeeb Delivery App" (`ZOi3kKtw7sd42ssSVX3Kn4`, node `56535:1525`). Mounted here as a virtual FS. The file pairs a full **Material 3 component kit** (the `Components` page — generic, not Jeeb-branded) with the **real Jeeb screens** on the `Playground` and `Low-Fidelity` pages (Splash, Request type, Voice request, Chat/offers, Order tracking, Feedback, Jeeber onboarding & profile).
- **Product requirements** — `updated-requirements/01-vision-and-personas.md`, `00-README.md`, `boundaries.md`, `02-domain-model.md`.
- **Existing AR marketing video** — `marketing/jeeb-arabic-video/` (uses a *gold-on-dark* expression that conflicts with the product palette — see Open Decisions).

### ⚠️ Open brand decisions (carried from the brief — flagged, not resolved here)
1. **Palette** — this system adopts **navy + orange** (the shipped app, Figma source of truth) as canonical. The gold marketing-video direction is treated as off-brand.
2. **Logomark** — the **"Jeeb" wordmark** (orange wheel-`b`) is used as primary. A scooter glyph appears on splash; whether to lock the scooter or favour a more inclusive movement/voice mark is still open.
3. **Public tier count** — all **5 tiers** are documented (the live app ships 5; the spec said 3).
4. **English tagline** — not locked; "Your errand, made easier" pairs best with the AR master line.
5. **Arabic display face** — Baloo Bhaijaan 2 is used as a placeholder expressive AR face pending licensing.

---

## CONTENT FUNDAMENTALS — how Jeeb writes

**Voice:** warm, neighbourly, plain-spoken, quietly confident. Jeeb talks like a **helpful friend on WhatsApp**, never like a corporate logistics brand. Bilingual and code-switch-comfortable (Beirutis mix AR/EN/FR naturally).

- **Person:** address the user as **"you"**; prefer **"neighbour"** over "client" in consumer copy. The supply side is always a **Jeeber** (never "driver," "rider," "gig worker").
- **Casing:** **Sentence case** for body and most UI. **Tier names are proper nouns** — Title Case (Flash, Express, Standard, On-the-Way, Eco). Screen titles in the app are short single words ("Request", "Traking" *(sic in app)*, "Feedback"). Headlines are imperative and friendly: *"Choose your request."*
- **Trust through clarity, not hype.** Every safety mechanic is stated plainly and treated as a *headline benefit*, not fine print: *"Your code. Your proof it's really yours." · "We only take a cut of the delivery fee. Never your goods." · "Pay cash at the door. That's it."*
- **The verb is the brand.** Lean on **"Jeeb it" / "جيبها"** and the category phrase **"Bring me anything."**
- **Numbers stay concrete and modest:** *"Offers in minutes," "3km away from you," "Estimated time: 20 mins," "Hi, I can bring you your order in 2 hours for 35$."* No inflated stats.
- **Emoji:** used **only** as the tier system's fixed lexicon — ⚡ Flash · 🚀 Express · 🟦 Standard · 🤝 On-the-Way · 🌿 Eco. Each emoji is a stable, meaningful glyph, not decoration. Do **not** sprinkle emoji elsewhere.
- **Avoid:** "gig," "task," "labour," "cheap," "fixed price," "driver." Never imply a card is required, never promise coverage beyond Beirut.

**Example copy (verbatim from product):**
- Tier descriptions: *"Delivered in less than 1 hour. Highest price • Priority pickup"* · *"Matched with someone already heading there. Lower price • Flexible timing."*
- Offer bubble: *"Hi i can bring you your order in 2 hours for 35$"* → **Accept Offer**.
- Constraint hint, in orange: *"Accept only one offer."*

---

## VISUAL FOUNDATIONS

**Overall feel:** cool, trustworthy, **airy**. Lots of white space; clean, not busy. The signature is **warm-on-cool tension** — an institutional **navy** (`#0B1351`) that says "safe to hand my errand to," warmed by brown outlines and punched by an **energetic orange** (`#D73B00`) reserved for action and emphasis.

### Color
- **Navy is the brand** — backgrounds of selected/active surfaces, primary buttons, all headlines and app-bar ink, the splash field. Body text is a near-navy **ink** (`#0B0E53`).
- **Orange is rationed** — progress accents, the wordmark's wheel, "do-it-now" highlights, and constraint/error hints (e.g. "Accept only one offer"). Never a large fill.
- **Periwinkle** (`#777FC0`) is the muted voice — secondary labels, Jeeber names in offer cards, tracking metadata.
- **Tier spectrum** is a *functional secondary palette* (red→green = urgent→relaxed). It lives **inside** the product, never in the masthead branding.
- Imagery is **bright and literal** (real map tiles, glossy 3D delivery render) — not filtered, not desaturated, not grainy.

### Type
- **Inter** everywhere in UI (400/500/600/700). Headlines are **navy, bold (700), generous** (24px `Location`, 20px `Choose your request`). Body is 16px ink. Labels 14px medium, captions 12px. Arabic is first-class and RTL-mirrored; campaign Arabic headlines get an expressive display face.
- `text-wrap: pretty` on headings; tight, confident leading.

### Shape, border & elevation
- **Corner radii are soft and large:** cards/tier rows ~16px, sheets & chat bubbles ~24px, the chat input field is a deep ~32px capsule, buttons are **full pills** (999px).
- **Cards prefer outline over shadow.** Unselected tier rows = white with a **1px navy/warm outline**; selected = **solid navy fill, no border**. Offer/message cards = flat **light-grey** (`#F4F4F6`) blocks, no border. Shadows are **soft and low** when present (resting `0 1px 3px rgba(11,19,81,.06)`), never heavy.
- Dividers/chip borders use the **warm brown** (`#916F66`) to break the cool.

### Backgrounds
- Predominantly **plain white**. The **splash** is a full-bleed **navy field** with the centered wordmark. Map/tracking screens are **full-bleed real map imagery** with a **navy route polyline** and a **red location pin**. No gradients, no repeating patterns, no textures.

### Motion, hover & press
- Motion is **functional and gentle** — fades and short slides; the **linear progress bar** advances through order states (Ordered → Picked → In Transit). No bounce, no decorative loops.
- **Press:** primary navy pills darken slightly and may subtly shrink (~0.97). Tier rows snap to the solid-navy selected state.
- **Hover** (where a pointer exists): navy surfaces lighten ~6%; ghost/text targets pick up a faint navy `8%` state layer (Material-derived).
- The **microphone / hold-to-talk** gesture is the hero interaction — build campaign and empty-state visuals around the **mic + waveform** as much as the scooter.

### Layout rules
- Mobile canvas **440×956**, **24px** side gutters, **~28px** block rhythm. Fixed **top app bar** (logo left, centered title, settings gear right) and, on chat, a **fixed bottom input bar**. Content sits between, scrolling.

---

## ICONOGRAPHY

- The shipped app draws icons from **Material Symbols / Material 3** (the Figma `Components` page is a full M3 kit: `Icons/check_24px`, `arrow_right_24px`, `settings_24px`, `local_taxi_24px`, `person_outline_24px`, etc.) plus a few **Iconly** glyphs in chat (`Iconly/Bold/Voice` mic, `Iconly/Curved/Bold/Send`). Line weight is the standard Material 24px grid, mostly **outline** with selected/filled variants.
- **In this design system** we substitute **[Material Symbols Rounded](https://fonts.google.com/icons)** via the Google Fonts CDN icon font — it matches the app's Material lineage and rounded-soft brand shape. ⚠️ *Substitution flag:* the original app bundles specific Material/Iconly SVGs; we use the CDN Material Symbols font as the closest faithful match. Swap in the exact bundled SVGs for production.
- **Emoji** are used **only** as the tier lexicon (⚡🚀🟦🤝🌿) — see Content Fundamentals. No other emoji.
- **Stars** (ratings) render in amber `#FFC107`, filled vs. outline.
- **Brand marks** (in `assets/logo/`): `jeeb-wordmark.svg` (white "Jee" + orange wheel-`b`, for **dark/navy** backgrounds), `jeeb-wordmark-navy.svg` (navy "Jee" + orange `b`, for **light** backgrounds).
- **Illustration:** glossy **3D delivery render** (`assets/illustrations/delivery-3d.png`) for empty states / marketing. Map imagery in `assets/illustrations/map-tracking.jpg`.

---

## Index / manifest

| Path | What |
|---|---|
| `styles.css` | Global entry — `@import`s every token + font file. Consumers link this. |
| `tokens/colors.css` | Brand, supporting, surface, **5-tier** & semantic color tokens + aliases. |
| `tokens/typography.css` | Inter + Arabic families, weights, type scale, tracking. |
| `tokens/spacing.css` | 4px spacing scale, screen layout, radii. |
| `tokens/elevation.css` | Soft shadow + focus-ring tokens. |
| `tokens/fonts.css` | `@font-face` via Google Fonts (Inter, Baloo Bhaijaan 2). |
| `assets/logo/` | Jeeb wordmark — dark-bg + light-bg variants. |
| `assets/illustrations/` | 3D delivery render, tracking map tile. |
| `components/` | Reusable React primitives (see below). |
| `ui_kits/jeeb-app/` | High-fidelity click-through recreation of the Jeeb mobile app. |
| `guidelines/` | Foundation specimen cards (Design System tab). |
| `SKILL.md` | Agent-Skills wrapper for downloading/using this system. |

### Components
Button · IconButton · Input · ChatInput · TierOption · OfferCard · MessageBubble · Avatar · RatingStars · Badge · TierBadge · TopAppBar · ProgressTracker · Card

### UI kits
- **jeeb-app** — Splash, Request (tier select), Voice request, Chat/offers compare, Order tracking.

---

*Generated as a design-system project. An automated compiler indexes `styles.css`, the token closure, and every `<Name>.jsx`+`<Name>.d.ts` component pair.*
