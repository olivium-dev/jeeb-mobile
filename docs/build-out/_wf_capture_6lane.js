export const meta = {
  name: 'jeeb-capture-6lane',
  description: 'Phase B-2 6-lane batch: prep in parallel, then capture+signoff across 6 emulator+mock lanes concurrently',
  phases: [{ title: 'Prep' }, { title: 'Capture' }],
}
const M = '/Users/oudaykhaled/Desktop/olivium/jeeb'
const SSD = '/Volumes/Extreme Pro/jeeb-scenarios'
let _A = args
if (typeof _A === 'string') { try { _A = JSON.parse(_A) } catch (e) { _A = {} } }
const INPUT = Array.isArray(_A) ? { ids: _A } : (_A || {})
const IDS = INPUT.ids || []
const dir = id => `${SSD}/_captures/${id}`
// 6 lanes: each its own emulator + isolated mock instance (host port). Lane A uses 10.0.2.2:4010 build;
// lanes B-F use the localhost build + adb reverse tcp:4010->host port (set up at boot). The capture agent
// only needs device + host mock port (reset/seed via curl localhost:<port>; maestro --device <dev>).
const ALL_LANES = [
  { dev: 'emulator-5554', port: 4010 },
  { dev: 'emulator-5556', port: 4011 },
  { dev: 'emulator-5558', port: 4012 },
  { dev: 'emulator-5560', port: 4013 },
  { dev: 'emulator-5562', port: 4014 },
  { dev: 'emulator-5564', port: 4015 },
]
const LANES = INPUT.lanes ? ALL_LANES.filter(l => INPUT.lanes.includes(l.dev)) : ALL_LANES
const ENV = `Env (do NOT rediscover; ${M}/jeeb-mobile/docs/build-out/71_MAESTRO_QA_PLAYBOOK.md + 62_SEAM_HARNESS.md):
- export JAVA_HOME="$(/usr/libexec/java_home)"; appId app.jeeb.mobile.dev; assert by Semantics id ONLY (no text).
- Gate EVERY screenshot behind extendedWaitUntil on the state's id (45000ms for any post-network-submit state, else 25000-45000ms). No fixed sleeps. AP-9 any cross-wave CTA.`
const PILOT_LESSONS = `Lessons: tiered extendedWaitUntil + no sleeps; at signoff verify mp4 >10KB and IGNORE macOS ._* sidecars (~4KB), match real artifacts by exact name; --device/-e flags are run-time only; validate screenshot CONTENT not just existence.`
const RECIPE = `SUCCESS-PATH RECIPE (full notes ${SSD}/_lessons/success-paths.md):
- Valid login: test@jeeb.app / Password123! (NOT returning@jeeb.app). Customer-home id: shell_tab_requests.
- Signup: FRESH unique email + Password123!.
- Signup & social-no-phone land on registration PHONE-ENTRY (RegistrationStep.phone) FIRST, not OTP. Sequence to reach OTP: (1) extendedWaitUntil id:_register_hero (45000ms) [this IS a real Semantics id], screenshot the phone-entry state; (2) tapOn text:"Phone number" (the +961 field) — if that misses, tapOn point/index of the phone input row; (3) inputText "70123456"; (4) tapOn text:"Send code"; (5) extendedWaitUntil id:phone_otp_root (45000ms), screenshot OTP. OTP ids (real Semantics): phone_otp_root/phone_otp_input/phone_otp_verify_cta/phone_otp_resend_cta.
- Social: jeeb.seam.social_login=facebook_no_phone; tap login_social_facebook -> phone-entry (then same phone->Send code->OTP sequence).
- CRITICAL KNOWN-BROKEN PATTERN: registration.phoneField and registration.sendCode are Flutter Keys, NOT Semantics ids — Maestro id: selector CANNOT match them (fails "Element not found: Id matching regex: registration.phoneField"). NEVER use an id: selector for registration.phoneField or registration.sendCode. Drive them by text/index ONLY (tapOn text:"Send code"; tap the phone field by text/index). Gate/assert on _register_hero (phone-entry) and phone_otp_root (OTP), which ARE Semantics ids.
- DO NOT invent state-suffixed ids (e.g. *_revealed/_hidden/_active/_filled). A toggle keeps the SAME id in both states (signup_password_visibility_toggle, login_password_visibility_toggle). Assert the real id from SEMANTICS_IDS.md/lib; differentiate states by screenshot CONTENT, not by a made-up id. Every asserted id MUST exist in source.`

phase('Prep')
async function prep(id) {
  const D = dir(id)
  await agent(`Researcher (UX). Read ${SSD}/_planning/SCENARIOS.json, find id "${id}". For semantics ids, FIRST read ${SSD}/_planning/SEMANTICS_IDS.md; only grep ${M}/jeeb-mobile/lib if missing. ALSO read ${SSD}/_lessons/success-paths.md and ${SSD}/_lessons/batch.md for accumulated gotchas (Flutter-Key-vs-Semantics-id traps, timeouts, negative-state content checks) and apply them. Consult ${M}/jeeb-mobile/docs/build-out/62_SEAM_HARNESS.md for seam keys/landing ids. Write "${D}/spec.json": { id, title, seam_args:{}, mock_seed:[curl steps or "default"], states:[{order,name,semantics_id_to_assert,action_to_reach}...] }. Each id MUST exist (cite source). ${RECIPE} ${ENV}\nReply "done".`, { label: `research:${id}`, phase: 'Prep' })
  await agent(`QA test-plan engineer. Read "${D}/spec.json". Write Maestro flow "${D}/flow.yaml": appId header; launchApp clearState:true with seam_args as arguments; for EACH state: extendedWaitUntil id (45000ms post-network, else tiered), takeScreenshot ABSOLUTE "${D}/<order>_<name>", then action_to_reach. id-selectors only, no text/sleeps. ${RECIPE} Also write "${D}/mock-config.json" (seed steps relative to the lane mock, or {"mock":"default"}). ${ENV}\nReply "done".`, { label: `plan:${id}`, phase: 'Prep' })
  await agent(`Maestro consultant. Read "${D}/flow.yaml" + ${M}/jeeb-mobile/docs/build-out/71_MAESTRO_QA_PLAYBOOK.md. Validate (id-only asserts, tiered waits, takeScreenshot absolute paths, no text/sleeps, AP-9, run-time-only flags). If wrong, REWRITE "${D}/flow.yaml". ${PILOT_LESSONS}\nReply "ok" or fixes.`, { label: `maestro:${id}`, phase: 'Prep' })
  return id
}
await parallel(IDS.map(id => () => prep(id).catch(() => null)))

phase('Capture')
const laneIds = LANES.map(() => [])
IDS.forEach((id, i) => laneIds[i % LANES.length].push(id))
const laneResults = await parallel(LANES.map((lane, li) => async () => {
  const out = []
  for (const id of laneIds[li]) {
    const D = dir(id)
    await agent(`QA capture engineer on LANE ${lane.dev} (mock host port ${lane.port}). Capture ${id}. Bash steps (adapt from "${D}/spec.json"/mock-config.json):
1. export JAVA_HOME="$(/usr/libexec/java_home)" ; adb -s ${lane.dev} reverse tcp:4010 tcp:${lane.port} (REQUIRED — reverse is not persistent and gets lost; re-assert it every run so the app reaches its mock)
2. curl -s -X POST http://localhost:${lane.port}/__mock/reset ; then seed curls from mock-config.json but ALWAYS target host port ${lane.port} (e.g. http://localhost:${lane.port}/__mock/seed/...). Skip if default.
3. rm -f "${D}"/*.png "${D}/${id}.mp4"
4. adb -s ${lane.dev} shell screenrecord --time-limit 180 /sdcard/${id}.mp4 >/dev/null 2>&1 &
5. timeout 180 maestro --device ${lane.dev} test "${D}/flow.yaml" 2>&1 | tee "${D}/maestro.log"
6. adb -s ${lane.dev} shell pkill -INT screenrecord ; sleep 3 ; adb -s ${lane.dev} pull /sdcard/${id}.mp4 "${D}/${id}.mp4" ; adb -s ${lane.dev} shell rm -f /sdcard/${id}.mp4
7. ls -la "${D}" (ignore ._*). Write "${D}/run-result.json"={id,lane:"${lane.dev}",maestro_exit_ok,screenshots:[real names],video_present,video_bytes,notes}. ${ENV} ${PILOT_LESSONS}\nReply 2-line status.`, { label: `capture:${id}@${lane.dev}`, phase: 'Capture', model: 'sonnet' })
    const so = await agent(`Product Owner sign-off ${id}. Read "${D}/spec.json","${D}/run-result.json"; ls "${D}" (IGNORE ._* sidecars). Verify a real screenshot for EVERY spec state + "${D}/${id}.mp4">10KB. Overwrite "${D}/signoff.md" with per-state PASS/FAIL + a VERDICT line containing PASS or FAIL. Append any NEW reusable lesson to "${SSD}/_lessons/batch.md". ${PILOT_LESSONS}\nReply: ${id} VERDICT=PASS|FAIL.`, { label: `signoff:${id}`, phase: 'Capture' })
    out.push({ id, lane: lane.dev, signoff: so })
  }
  return out
}))
return { batch: IDS, lanes: LANES.map(l => l.dev), results: laneResults.flat() }
