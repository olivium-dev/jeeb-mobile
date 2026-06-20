export const meta = {
  name: 'jeeb-capture-pipeline',
  description: 'Phase B-2 PIPELINED: 6 lanes, each runs spec(opus)->capture+verify(sonnet) with 1-ahead lookahead (spec next while capturing current); drains the whole backlog with no phase barriers',
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
const ENV = `ENV: appId app.jeeb.mobile.dev; assert by Semantics id ONLY (no visible-text asserts). Gate every screenshot behind extendedWaitUntil on the state id (25000ms post-network-submit, else 12000ms). No fixed sleeps. AP-9 cross-wave CTAs.`
const RECIPE = `RECIPE: Valid login test@jeeb.app / Password123! (NOT returning@jeeb.app); customer-home id shell_tab_requests. Signup: fresh unique email + Password123!. Signup AND social-no-phone land on registration PHONE-ENTRY first (not OTP): wait id _register_hero (25000ms), screenshot; then tap the phone field by text/index and tap by text "Send code" (registration.phoneField & registration.sendCode are Flutter Keys, NOT Semantics ids — NEVER use an id: selector for them); inputText 70123456; then wait id phone_otp_root (25000ms), screenshot. OTP ids: phone_otp_root/phone_otp_input/phone_otp_verify_cta/phone_otp_resend_cta. Social: jeeb.seam.social_login=facebook_no_phone, tap login_social_facebook. DO NOT invent state-suffixed ids (no *_revealed/_hidden); a toggle keeps the SAME id in both states; differentiate by screenshot content. Every asserted id must exist in SEMANTICS_IDS.md or lib. ERROR/500/offline states: mock supports fault injection — put a curl in mock_seed BEFORE the failing action: POST http://localhost:<laneport>/__mock/fault {"pathPattern":"<substr of failing endpoint>","status":500,"times":1}; then act and assert the error id (contract _lessons/mock-fault-injection.md). OFF-SCREEN/below-fold elements: use scrollUntilVisible {element:{id:<id>},direction:DOWN,timeout:15000} before takeScreenshot/tapOn (extendedWaitUntil does NOT scroll). If a loading/error state has NO distinct Semantics id, note it in spec _notes as structural app limitation, do not invent an id.`

async function spec(id) {
  const D = dir(id)
  await agent(`Spec engineer for Jeeb scenario ${id}. FIRST: if BOTH "${D}/spec.json" and "${D}/flow.yaml" exist and are complete (valid Maestro flow, takeScreenshot per state), reply only "done" without rewriting (idempotent). Otherwise read ONLY ${SSD}/_planning/scenarios/${id}.json + ${SSD}/_planning/SEMANTICS_IDS.md (only grep ${M}/jeeb-mobile/lib if a needed id is absent there). Write TWO files via Write tool:
1. "${D}/spec.json" = { id, title, seam_args:{} , mock_seed:[curl steps targeting the lane mock or "default"], states:[{order,name,semantics_id_to_assert,action_to_reach}...] }.
2. "${D}/flow.yaml" = Maestro flow: appId header line (appId: app.jeeb.mobile.dev), then ---, then launchApp clearState:true arguments=seam_args; for EACH state in order: extendedWaitUntil id visible (25000 post-network else 12000), takeScreenshot ABSOLUTE "${D}/<order>_<name>", then action_to_reach. id selectors only (text/index for the registration phone Keys); no sleeps.
${RECIPE} ${ENV}\nReply "done".`, { label: `spec:${id}`, phase: 'Spec', model: 'opus' })
  return id
}
async function cap(id, lane) {
  const D = dir(id)
  const so = await agent(`QA capture+verify on LANE ${lane.dev} (mock host port ${lane.port}) for ${id}. Bash, then deterministic sign-off.
1. export JAVA_HOME="$(/usr/libexec/java_home)" ; adb -s ${lane.dev} reverse tcp:4010 tcp:${lane.port} (REQUIRED every run)
2. curl -s -X POST http://localhost:${lane.port}/__mock/reset ; then seed curls from "${D}/spec.json" mock_seed targeting http://localhost:${lane.port}/__mock/... (skip if default)
3. rm -f "${D}"/*.png "${D}/${id}.mp4"
4. adb -s ${lane.dev} shell screenrecord --time-limit 180 /sdcard/${id}.mp4 >/dev/null 2>&1 &
5. JAVA_HOME="$(/usr/libexec/java_home)" timeout 180 maestro --device ${lane.dev} test "${D}/flow.yaml" 2>&1 | tee "${D}/maestro.log"  (JAVA_HOME inline on this exact command)
6. adb -s ${lane.dev} shell pkill -INT screenrecord ; sleep 3 ; adb -s ${lane.dev} pull /sdcard/${id}.mp4 "${D}/${id}.mp4" ; adb -s ${lane.dev} shell rm -f /sdcard/${id}.mp4
7. Read "${D}/spec.json" states[]. Verify: one REAL png (ignore ._* sidecars, >10KB) per state, "${D}/${id}.mp4">10KB, no FAILED assertion in maestro.log. Write "${D}/run-result.json" and "${D}/signoff.md" with a per-state PASS/FAIL table and a final line exactly "VERDICT=PASS" (all states have a real screenshot AND mp4>10KB AND no FAILED) else "VERDICT=FAIL" + reason. ${ENV}\nReply: ${id} VERDICT=PASS|FAIL.`, { label: `cap:${id}@${lane.dev}`, phase: 'Capture', model: 'sonnet' })
  return { id, lane: lane.dev, signoff: so }
}

// Shard ids round-robin across lanes; each lane runs a 1-ahead pipeline: spec(next) overlaps capture(current).
const laneIds = LANES.map(() => [])
IDS.forEach((id, i) => laneIds[i % LANES.length].push(id))
const laneResults = await parallel(LANES.map((lane, li) => async () => {
  const ids = laneIds[li]
  const out = []
  if (!ids.length) return out
  let specPromise = spec(ids[0]).catch(() => null)
  for (let k = 0; k < ids.length; k++) {
    await specPromise
    const nextSpec = (k + 1 < ids.length) ? spec(ids[k + 1]).catch(() => null) : null
    try { out.push(await cap(ids[k], lane)) } catch (e) { out.push({ id: ids[k], lane: lane.dev, signoff: 'ERROR' }) }
    specPromise = nextSpec
  }
  return out
}))
const flat = laneResults.flat()
return { total: flat.length, pass: flat.filter(r => /VERDICT=PASS/i.test(r.signoff || '')).length, lanes: LANES.map(l => l.dev) }
