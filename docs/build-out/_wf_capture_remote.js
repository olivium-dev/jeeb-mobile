export const meta = {
  name: 'jeeb-capture-remote',
  description: 'Phase B-2 REMOTE: 5 Mac-Studio lanes; spec(opus) on this Mac, capture via _remote_capture.sh (ssh maestro on Mac Studio + rsync back), verify locally. Pipelined 1-ahead per lane.',
  phases: [{ title: 'Spec' }, { title: 'RemoteCapture' }],
}
const M = '/Users/oudaykhaled/Desktop/olivium/jeeb'
const SSD = '/Volumes/Extreme Pro/jeeb-scenarios'
const HELPER = `${M}/jeeb-mobile/docs/build-out/_remote_capture.sh`
let _A = args
if (typeof _A === 'string') { try { _A = JSON.parse(_A) } catch (e) { _A = {} } }
const INPUT = Array.isArray(_A) ? { ids: _A } : (_A || {})
const IDS = INPUT.ids || []
const dir = id => `${SSD}/_captures/${id}`
// Remote Mac Studio lanes: emulator console port + its host mock port (on the Mac Studio).
const LANES = [
  { port: 5554, mock: 4010 },
  { port: 5556, mock: 4011 },
  { port: 5558, mock: 4012 },
]
const ENV = `ENV: appId app.jeeb.mobile.dev; assert by Semantics id ONLY (no text). Gate every screenshot behind extendedWaitUntil on the state id (25000ms post-network else 12000ms). No sleeps. AP-9 cross-wave CTAs.`
const RECIPE = `RECIPE: login test@jeeb.app/Password123! (NOT returning@jeeb.app); customer-home id shell_tab_requests. Signup: fresh unique email+Password123!. Signup AND social-no-phone land on registration PHONE-ENTRY first: wait id _register_hero (25000ms), screenshot; tap phone field by text/index + tap text "Send code" (registration.phoneField/sendCode are Flutter Keys — NEVER id: selector); inputText 70123456; wait id phone_otp_root (25000ms), screenshot. OTP ids phone_otp_root/phone_otp_input/phone_otp_verify_cta/phone_otp_resend_cta. Social: jeeb.seam.social_login=facebook_no_phone, tap login_social_facebook. No invented *_revealed/_hidden ids; differentiate by screenshot content; every id must exist in SEMANTICS_IDS.md/lib. ERROR/500 states: mock_seed curl POST http://localhost:<laneport>/__mock/fault {"pathPattern":"<substr>","status":500,"times":1} before the failing action (contract _lessons/mock-fault-injection.md). OFF-SCREEN: scrollUntilVisible {element:{id:<id>},direction:DOWN,timeout:15000} before takeScreenshot/tapOn. Loading/error with no distinct id → note structural limit in spec _notes.`

async function spec(id) {
  const D = dir(id)
  await agent(`Spec engineer for Jeeb scenario ${id}. If BOTH "${D}/spec.json" and "${D}/flow.yaml" exist and complete, reply "done" (idempotent). Else read ONLY ${SSD}/_planning/scenarios/${id}.json + ${SSD}/_planning/SEMANTICS_IDS.md (grep ${M}/jeeb-mobile/lib only if an id is missing). Write "${D}/spec.json" {id,title,seam_args:{},mock_seed:[curls or "default"],states:[{order,name,semantics_id_to_assert,action_to_reach}...]} and "${D}/flow.yaml" (appId header; launchApp clearState:true arguments=seam_args; per state: extendedWaitUntil id (25000 post-network else 12000), takeScreenshot ABSOLUTE "${D}/<order>_<name>", then action_to_reach; id selectors only). ${RECIPE} ${ENV}\nReply "done".`, { label: `spec:${id}`, phase: 'Spec', model: 'opus' })
  return id
}
async function cap(id, lane) {
  const D = dir(id)
  const so = await agent(`QA capture+verify for ${id} on the REMOTE Mac-Studio lane emulator-${lane.port} (mock ${lane.mock}). Steps with Bash:
1. Run: bash "${HELPER}" ${id} ${lane.port} ${lane.mock}   (this rewrites the flow's screenshot paths, scps the flow to the Mac Studio, runs maestro there on emulator-${lane.port} with gtimeout, and rsyncs *.png + ${id}.mp4 + maestro.log back to "${D}/"). It prints REMOTE_CAPTURE_DONE and the png count + mp4 size.
2. VERIFY locally (deterministic): read "${D}/spec.json" states[]. Confirm one REAL png (ignore ._* sidecars, >10KB) exists for EACH state (by <order>_<name>.png), AND "${D}/${id}.mp4">10KB, AND "${D}/maestro.log" has no FAILED assertion.
3. Write "${D}/run-result.json" {id,lane:"remote-emulator-${lane.port}",screenshots:[names],video_bytes,missing_states:[]} and "${D}/signoff.md" with a per-state PASS/FAIL table + final line exactly "VERDICT=PASS" (all states have real screenshot AND mp4>10KB AND no FAILED) else "VERDICT=FAIL" + reason.
NOTE: if the helper output shows 0 png or the rsync failed, the remote adb may have dropped — note it; VERDICT=FAIL. ${ENV}\nReply: ${id} VERDICT=PASS|FAIL.`, { label: `rcap:${id}@rs-${lane.port}`, phase: 'RemoteCapture', model: 'sonnet' })
  return { id, lane: `remote-${lane.port}`, signoff: so }
}

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
    try { out.push(await cap(ids[k], lane)) } catch (e) { out.push({ id: ids[k], lane: `remote-${lane.port}`, signoff: 'ERROR' }) }
    specPromise = nextSpec
  }
  return out
}))
const flat = laneResults.flat()
return { total: flat.length, pass: flat.filter(r => /VERDICT=PASS/i.test(r.signoff || '')).length, node: 'mac-studio' }
