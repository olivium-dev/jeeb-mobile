export const meta = {
  name: 'jeeb-capture-6lane-fast',
  description: 'Phase B-2 FAST (10x): 1 opus spec agent (+templates flow.yaml, lean reads) then 1 sonnet capture+verify, across 6 lanes',
  phases: [{ title: 'Spec' }, { title: 'Capture' }],
}
const M = '/Users/oudaykhaled/Desktop/olivium/jeeb'
const SSD = '/Volumes/Extreme Pro/jeeb-scenarios'
let _A = args
if (typeof _A === 'string') { try { _A = JSON.parse(_A) } catch (e) { _A = {} } }
const INPUT = Array.isArray(_A) ? { ids: _A } : (_A || {})
const IDS = INPUT.ids || []
const dir = id => `${SSD}/_captures/${id}`
const ALL_LANES = [
  { dev: 'emulator-5554', port: 4010 },
  { dev: 'emulator-5556', port: 4011 },
  { dev: 'emulator-5558', port: 4012 },
  { dev: 'emulator-5560', port: 4013 },
  { dev: 'emulator-5562', port: 4014 },
  { dev: 'emulator-5564', port: 4015 },
]
const LANES = INPUT.lanes ? ALL_LANES.filter(l => INPUT.lanes.includes(l.dev)) : ALL_LANES

// Inline cheat-sheet — agents must NOT read the big docs (SCENARIOS.json monolith, batch.md, 62_SEAM_HARNESS.md, blueprint.json). Everything needed is here.
const ENV = `ENV: appId app.jeeb.mobile.dev; assert by Semantics id ONLY (no visible-text asserts). Gate every screenshot behind extendedWaitUntil on the state id (25000ms for post-network-submit states, else 12000ms). No fixed sleeps. AP-9 cross-wave CTAs.`
const RECIPE = `RECIPE: Valid login test@jeeb.app / Password123! (NOT returning@jeeb.app); customer-home id shell_tab_requests. Signup: fresh unique email + Password123!. Signup AND social-no-phone land on registration PHONE-ENTRY first (not OTP): wait id _register_hero (25000ms), screenshot; then tap the phone field by text/index and tap by text "Send code" (registration.phoneField & registration.sendCode are Flutter Keys, NOT Semantics ids — NEVER use an id: selector for them); inputText 70123456; then wait id phone_otp_root (25000ms), screenshot. OTP ids: phone_otp_root/phone_otp_input/phone_otp_verify_cta/phone_otp_resend_cta. Social: jeeb.seam.social_login=facebook_no_phone, tap login_social_facebook. DO NOT invent state-suffixed ids (no *_revealed/_hidden); a toggle keeps the SAME id in both states; differentiate states by screenshot content. Every asserted id must exist in SEMANTICS_IDS.md or lib. ERROR/500/offline states: the mock supports fault injection — put a curl in mock_seed BEFORE the failing action: POST http://localhost:<laneport>/__mock/fault JSON {"pathPattern":"<substring of failing endpoint e.g. saved-locations>","status":500,"times":1} (optional "method"); then act and assert the error id (contract: /Volumes/Extreme Pro/jeeb-scenarios/_lessons/mock-fault-injection.md). If a required loading/error state has NO distinct Semantics id in the app, record it in spec _notes as a structural app limitation rather than inventing an id. OFF-SCREEN/BELOW-THE-FOLD elements: if an asserted id or tapOn target may be below the fold on a scrollable screen (e.g. links/CTAs at the bottom of earnings/profile/settings/long lists), the flow MUST scroll to it first — use scrollUntilVisible with element {id: <the id>}, direction: DOWN, timeout: 15000 BEFORE the takeScreenshot or tapOn (plain extendedWaitUntil does NOT scroll, so off-screen targets time out). Prefer scrollUntilVisible for any link/button that is not guaranteed to be in the initial viewport.`

phase('Spec')
async function spec(id) {
  const D = dir(id)
  await agent(`Spec engineer for Jeeb scenario ${id}. FIRST: if BOTH "${D}/spec.json" and "${D}/flow.yaml" already exist and are non-empty/complete (valid Maestro flow with a takeScreenshot per state), reply only "done" WITHOUT rewriting them (idempotent — saves work). Otherwise: Read ONLY these two small files: ${SSD}/_planning/scenarios/${id}.json (the scenario) and ${SSD}/_planning/SEMANTICS_IDS.md (screen->id reference). Do NOT read the big catalog, batch.md, seam-harness, or blueprint. Only if a needed semantics id is absent from SEMANTICS_IDS.md, grep ${M}/jeeb-mobile/lib for that ONE id.
Produce TWO files with the Write tool:
1. "${D}/spec.json" = { id, title, seam_args:{<jeeb.seam.*>:val or {}}, mock_seed:[curl steps targeting the lane mock, or "default"], states:[{order,name,semantics_id_to_assert,action_to_reach}...in capture order] }.
2. "${D}/flow.yaml" = a Maestro flow templated from the states: first line appId header (appId: app.jeeb.mobile.dev), then '---', then launchApp with clearState:true and arguments=seam_args; then for EACH state in order: extendedWaitUntil the state's semantics id visible (timeout 25000 if the state is reached after a network submit/login/signup/social/sendCode, else 12000), then takeScreenshot with ABSOLUTE path "${D}/<order>_<name>" (Maestro appends .png), then the action_to_reach steps for the next state (id selectors, or text/index for the registration phone Keys). No fixed sleeps, no text asserts.
${RECIPE} ${ENV}\nReply only "done".`, { label: `spec:${id}`, phase: 'Spec', model: 'opus' })
  return id
}
await parallel(IDS.map(id => () => spec(id).catch(() => null)))

phase('Capture')
const laneIds = LANES.map(() => [])
IDS.forEach((id, i) => laneIds[i % LANES.length].push(id))
const laneResults = await parallel(LANES.map((lane, li) => async () => {
  const out = []
  for (const id of laneIds[li]) {
    const D = dir(id)
    const so = await agent(`QA capture+verify on LANE ${lane.dev} (mock host port ${lane.port}) for ${id}. Run with Bash, then sign off deterministically.
CAPTURE:
1. export JAVA_HOME="$(/usr/libexec/java_home)" ; adb -s ${lane.dev} reverse tcp:4010 tcp:${lane.port} (REQUIRED every run — reverse is not persistent)
2. curl -s -X POST http://localhost:${lane.port}/__mock/reset ; then any seed curls from "${D}/mock-config.json"/spec.json mock_seed, ALWAYS targeting http://localhost:${lane.port}/__mock/... (skip if default)
3. rm -f "${D}"/*.png "${D}/${id}.mp4"
4. adb -s ${lane.dev} shell screenrecord --time-limit 180 /sdcard/${id}.mp4 >/dev/null 2>&1 &
5. JAVA_HOME="$(/usr/libexec/java_home)" timeout 180 maestro --device ${lane.dev} test "${D}/flow.yaml" 2>&1 | tee "${D}/maestro.log"  (JAVA_HOME MUST be inline on this exact command — a separate export in another Bash call does NOT persist in subagent shells)
6. adb -s ${lane.dev} shell pkill -INT screenrecord ; sleep 3 ; adb -s ${lane.dev} pull /sdcard/${id}.mp4 "${D}/${id}.mp4" ; adb -s ${lane.dev} shell rm -f /sdcard/${id}.mp4
VERIFY (deterministic):
7. Read "${D}/spec.json" states[]. Check: exactly one REAL png (ignore ._* sidecars, size>10KB) exists for EACH state (match by <order>_<name>.png), AND "${D}/${id}.mp4" exists >10KB, AND maestro.log has no FAILED assertion.
8. Write "${D}/run-result.json"={id,lane:"${lane.dev}",maestro_exit_ok:bool,screenshots:[real names],video_bytes,missing_states:[...]}.
9. Write "${D}/signoff.md": a short per-state PASS/FAIL table + a final line exactly "VERDICT=PASS" if every state has a real screenshot AND mp4>10KB AND no FAILED assertion, else "VERDICT=FAIL" with the reason. ${ENV}\nReply: ${id} VERDICT=PASS|FAIL (one line).`, { label: `cap:${id}@${lane.dev}`, phase: 'Capture', model: 'sonnet' })
    out.push({ id, lane: lane.dev, signoff: so })
  }
  return out
}))
return { batch: IDS, lanes: LANES.map(l => l.dev), results: laneResults.flat() }
