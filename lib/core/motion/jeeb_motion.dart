/// The MIDNIGHT motion module — the 8 primitives of
/// `docs/redesign-midnight/00-MASTER-PLAN.md` §2.6, implemented once so screens
/// consume motion without owning controllers.
///
/// | Primitive | Keyframes | Timing | Widget |
/// |---|---|---|---|
/// | `jFloat` | translateY 0 → −7px → 0 | 4s / 4.4s ease-in-out ∞ | [JFloat] |
/// | `jTwinkle` | opacity .2→1→.2, scale .7→1.15→.7 | 2.4–3s ease-in-out ∞ | [JTwinkle] |
/// | `jBreathe` | opacity .45→1→.45 | 1.6–3.6s ease-in-out ∞ | [JBreathe] |
/// | `jWave` | scaleY .5→1.15→.5 | 1.3s ease-in-out ∞ | [JWaveBar] / [JWaveBars] |
/// | `jDash` | stroke-dashoffset → −40 | 2s linear ∞ | [JDashOffset] / [JDashedPath] |
/// | `jHalo` | scale .75→1.6, opacity .8→0 | 2.6s ease-out ∞ | [JHalo] |
/// | `jArcPulse` | opacity .15→1(@35%)→.15 | 2.4s ease-in-out ∞ | [JArcPulse] |
/// | `jBlink` | opacity 1↔0 hard cut | 1.1s step-end ∞ | [JBlink] |
///
/// Three rules hold across all of them:
///
/// * **Colour is the consumer's job.** Nothing here imports `lib/core/theme`;
///   the module ships geometry and opacity only. ([JHalo] and [JDashedPath] take
///   a colour because they paint, not because they choose.)
/// * **Reduce motion renders a fixed keyframe of the row** — the FIRST one, or
///   the LIT one for an element that carries information ([JMotionRest], Q-037)
///   — and schedules no frames at all. Never a frozen mid-cycle value. See
///   `JMotionLoop`.
/// * **Every widget takes a `delay`**, which is the board's stagger; group
///   helpers live on [JeebMotion] (`stagger`, `spread`).
///
/// The loops are infinite, as the board specifies. A widget test that mounts a
/// primitive must advance with `tester.pump(<duration>)` — `pumpAndSettle` only
/// terminates under reduce motion.
library;

export 'jeeb_motion_dash.dart';
export 'jeeb_motion_loop.dart';
export 'jeeb_motion_primitives.dart';
export 'jeeb_motion_tokens.dart';
