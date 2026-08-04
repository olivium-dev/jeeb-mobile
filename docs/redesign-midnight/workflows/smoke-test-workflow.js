export const meta = {
  name: 'midnight-smoke-test',
  description: 'Real-app smoke test — build + launch on the Galaxy S24, plus build-free static wiring checks',
  phases: [{ title: 'Smoke', detail: 'on-device build/launch/screenshot · static wiring verification' }],
}
const REPO = '/Users/oudaykhaled/Desktop/olivium/jeeb/jeeb-mobile'

phase('Smoke')
const r = await parallel([
  () => agent(`You are the ON-DEVICE SMOKE lane for the Jeeb MIDNIGHT redesign in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch.

**CONTEXT — why you exist.** 7489 widget tests pass and 343 catalog captures are green, but **the app has never once been built or launched this session.** Passing widget tests do not prove the binary compiles, that it boots, that assets resolve at runtime, or that the Midnight theme actually applies on a real device. That is the entire gap you are closing. This is NOT the full M7 validation (which needs real OTP login and two devices for chat) — it is a smoke test: does it build, boot, and look like Midnight.

**DISK GUARD — this is a hard constraint, not advice.** The machine is at **19 GB free / 96% used**, and this repo's owner has a standing rule that a filling root disk here *freezes the Bash tool for every agent*. Before AND after each build step run \`df -h /System/Volumes/Data | tail -1\`. **If free space drops below 6 GB, STOP immediately, run \`flutter clean\` to reclaim, and report — do not push through.** Prefer the cheapest build that answers the question.

TARGET DEVICE: \`RFCX306JSRT\` (SM-S921B, Galaxy S24, Android 16). A second device \`RZCT505K7WF\` (SM-A336B) is attached — ignore it unless the S24 fails.

WHAT TO DO, in order, stopping at the first hard failure and reporting it:
1. \`flutter build apk --debug\` (or \`flutter run\` straight to the device if that is cheaper). **A build failure is the single most valuable thing you could find** — report the exact error, do not try to fix it silently.
2. Install and launch on the S24.
3. **Watch the FIRST FRAMES specifically for a white flash.** The M6 audit found the iOS launch screen was solid white and fixed it; the Android path was never verified. Capture the launch sequence — \`adb exec-out screencap -p > file.png\` in a tight loop during startup, or record with \`adb shell screenrecord\`.
4. Screenshot whatever screen it lands on. Confirm by PIXEL, not by eye: is the background the Midnight navy family (#070C33 / #0B1351 / #10175E)? Is there any large white or light-grey region that should not be there?
5. Check \`adb logcat\` for exceptions during startup — RenderFlex overflows, missing assets, MissingPluginException, null-check errors. **Report every exception you see, even ones that do not crash the app.**
6. If the app lands on a login/OTP screen, that is expected and fine — do NOT attempt to log in (real-flow validation is the owner's M7 job, and needs a real OTP).

**Report honestly and specifically.** "It launched" is not a finding; "it launched, background sampled #070C33 at 5 points, 2 RenderFlex overflows in logcat on the registration screen at lines X/Y" is. If it does NOT build or does NOT launch, that is the most important possible outcome of this whole session — say so plainly and loudly.
Save artefacts to docs/redesign-midnight/smoke/ so they survive.
RETURN: disk before/after · build result (+ exact errors) · did it launch · white-flash verdict with pixel evidence · landing-screen pixel sample · EVERY logcat exception · what you could not check.`,
    { label: 'smoke: build + launch on S24', phase: 'Smoke', model: 'opus' }),

  () => agent(`You are the STATIC WIRING lane for the Jeeb MIDNIGHT redesign in ${REPO}, branch feat/redesign-midnight. NEVER run git commit/checkout/stash/branch, and **do NOT run any build** — a sibling lane owns the build and the machine is disk-constrained. You are read-only analysis.

**CONTEXT:** 7489 widget tests pass, but tests mount widgets directly and mock away the app's real wiring. Your job is to find the class of failure that only shows up when the REAL app starts — the things a widget test cannot see.

CHECK EACH, with file:line evidence:
1. **Assets.** Every path declared in \`pubspec.yaml\` under \`assets:\` — does the file actually exist on disk? And the reverse: every \`Image.asset\`/\`SvgPicture.asset\`/\`Lottie.asset\`/\`rootBundle.load\` string literal in \`lib/\` — is it declared in pubspec AND present? **This session deleted several animation JSONs and two SVGs; a stale reference is a runtime crash that no widget test would catch** unless that exact widget is under test.
2. **Fonts.** Every family declared in pubspec — do the .ttf/.otf files exist? The theme names Inter and Baloo Bhaijaan 2; a missing weight renders as a fallback and no test would notice.
3. **l10n.** \`app_localizations.dart\` is a hand-authored runtime ARB parser (\`_get\` + \`rootBundle.loadString\`), so a getter whose key is absent from the ARB throws AT RUNTIME, not at compile time. **Cross-check every getter against both app_en.arb and app_ar.arb** and report any getter with no key, or any key mismatch between EN and AR. This session landed ~100 keys across five merge lanes.
4. **Routes.** Every \`GoRoute\` in \`app_router.dart\`: does its builder reference a screen class that still exists? Several screens were DELETED this session (settlement x2, rating_prompt, JeebLottieMark, ClientHomeEmptyMark) — confirm no route or redirect still points at a removed symbol.
5. **DI.** Anything resolved via \`sl<...>()\` that is never registered in \`injection_container.dart\` — a runtime throw. The audits already found one registered-but-never-resolved singleton; look for the reverse, which is the crashing direction.

Report each as PASS with evidence, or FAIL with file:line and what would happen at runtime. **A clean PASS list is a perfectly good outcome — do not manufacture findings.** Be explicit about anything your method cannot see.
RETURN: per-check verdict with evidence · every dangling asset/font/key/route/DI reference found · what you could not verify statically.`,
    { label: 'smoke: static wiring', phase: 'Smoke', model: 'opus' }),
])
return { device: r[0], static: r[1] }
