export const meta = {
  name: 'screen-previews',
  description: 'Give each Screen a preview section in its own file, reusing the Screen Catalog fixtures as the single source of truth',
  whenToUse: 'One wave of the screen rollout. args = {repoRoot, batch:[{widget,source,area}]}. Each agent owns one screen.',
  phases: [
    { title: 'Write', detail: 'one agent per screen: extract the catalog fixture, add the preview section, render test' },
    { title: 'Integrate', detail: 'analyze + whole preview suite + catalog still builds' },
  ],
}

const input = typeof args === 'string' ? JSON.parse(args) : args || {}
const batch = input.batch || []
const repoRoot = input.repoRoot || '.'

if (batch.length === 0) {
  log('Nothing to do — the screen queue is empty.')
  return { written: [], failed: [], skipped: 'empty queue' }
}

log(`Screen wave: ${batch.length} — ${batch.map((w) => w.widget).join(', ')}`)

function snake(p) {
  return p.replace(/(?<=[a-z0-9])([A-Z])/g, '_$1').toLowerCase()
}

const RESULT = {
  type: 'object',
  additionalProperties: false,
  required: ['screen', 'status', 'previewCount', 'notes'],
  properties: {
    screen: { type: 'string' },
    status: { type: 'string', enum: ['written', 'failed', 'skipped-not-previewable'] },
    previewCount: { type: 'integer' },
    fixtureSource: {
      type: 'string',
      enum: ['catalog-extracted', 'catalog-absent-wrote-new'],
      description: 'whether a Screen Catalog entry existed to extract, or fixtures had to be written fresh',
    },
    states: { type: 'array', items: { type: 'string' } },
    findings: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}

function prompt(w) {
  return `Add a preview section to ONE screen, in the screen's own source file.

Working directory: ${repoRoot}
Screen class: ${w.widget}
Source file:  ${w.source}      <- the preview section goes at the BOTTOM of this file
Render test:  test/previews/${w.area}/${snake(w.widget)}_preview_test.dart

## Read first

1. \`lib/core/previews/README.md\` — conventions: the banner, the widget-name
   prefix rule on every top-level name, the import marker.
2. \`lib/features/home_client/presentation/widgets/client_home_greeting.dart\` —
   the reference preview section.
3. \`test/previews/home_client/client_home_greeting_preview_test.dart\` — the
   reference test.
4. \`${w.source}\` itself, plus any existing test for it (grep \`${w.widget}\`).

## The fixtures already exist — REUSE them, do not reinvent

\`lib/devtool/catalog/entries/batch_*.dart\` holds ~270 hand-built mocked states
across 67 screens: fake repositories with canned data, cubits seeded into a
designed state, typed failures. Grep those files for \`${w.widget}\`.

**If a catalog entry exists for this screen**, that is your fixture set, and the
states it names are the states to preview. Do NOT copy the code into the screen
file — extract it ONCE into

    lib/devtool/catalog/fixtures/${snake(w.widget)}_fixtures.dart

with the fakes made public (\`${w.widget}PreviewFixtures\` or per-fake names),
then have BOTH the catalog entry and your new preview section import that file.
One source of truth, so the catalog and the previews cannot drift apart. The
catalog must still compile and its states must still render — that is a
designer-facing tool and you are not allowed to break it.

Report \`fixtureSource: 'catalog-extracted'\`.

**If no catalog entry exists** (26 screens have none), write fixtures fresh into
the same \`fixtures/\` path so the next person finds them where they expect.
Report \`fixtureSource: 'catalog-absent-wrote-new'\`.

## Rules

- **Never a real repository.** Seed with an inert cubit (\`SomeCubit(seed: ...)\`,
  no repository) or a local fake implementing the repository interface. The host
  wrapper installs \`CatalogNetworkGuard\` as a net, not as the plan.
- **Screens own their Scaffold.** \`jeebPreviewHost\` already wraps the child in
  one, so a screen that returns its own Scaffold will nest two. Check what the
  reference host does and size the canvas to a real device
  (\`Size(390, 844)\` phone, \`Size(320, 568)\` compact) rather than the widget default.
- **Nothing above the banner may change.** No production edit. If the screen
  cannot be previewed without one — no injectable seam for its cubit — report
  \`failed\` and name the missing seam exactly. Do not add it.
- **Never leave the file half-edited.** A broken fixture below the banner errors
  the whole library and everything importing it.
- \`@JeebPreview(group: '${w.area}', name: '<state>', size: Size(w, h))\`.
  \`group\` must be exactly \`'${w.area}'\`. Add \`matrix: true\` to the ONE OR TWO
  states where EN/AR/200% side by side is the point.
- **Cover the states that break**: empty, loading, error, longest content, and any
  state an existing test or code comment flags as a past bug. A single happy path
  will be rejected.
- **The test must pin content** — \`expectedText\` with a DISTINCT string per state.
- Leave no scratch files. Do NOT \`git commit\` or \`git push\`.

## Verify before reporting

    flutter analyze --no-pub ${w.source} test/previews/${w.area}/${snake(w.widget)}_preview_test.dart
    flutter test test/previews/${w.area}/${snake(w.widget)}_preview_test.dart
    flutter test test/devtool/            # the catalog must still pass

Report \`written\` only if all three are clean. A false \`written\` is worse than a
failure — the ratchet bakes it in.

In \`findings\`, list REAL problems the preview exposed in the screen itself.
Empty if none. Not a summary of your work.`
}

phase('Write')

const results = await parallel(
  batch.map((w) => () =>
    agent(prompt(w), { label: `screen:${w.widget}`, phase: 'Write', schema: RESULT })
  )
)

const done = results.filter(Boolean)
const written = done.filter((r) => r.status === 'written')
const failed = done.filter((r) => r.status !== 'written')
log(`written ${written.length}/${batch.length} · failed ${failed.length} · errors ${results.length - done.length}`)

phase('Integrate')

const integration = await agent(
  `This wave's screen previews are on disk in ${repoRoot}. You are the gate.

Run:

    flutter analyze --no-pub lib/ test/ tool/
    flutter test test/previews/
    flutter test test/devtool/
    dart run tool/preview_coverage.dart

Then:

1. Fix anything that fails — preview/test/fixture files only, never a screen's
   production code above the banner.
2. **Confirm the Screen Catalog still works.** Agents extracted fixtures out of
   \`lib/devtool/catalog/entries/batch_*.dart\` into
   \`lib/devtool/catalog/fixtures/\` and repointed both consumers. If any catalog
   entry lost a state, or the catalog's screen/state counts dropped, that is a
   regression — say so explicitly with the before/after counts.
3. Lower \`_coverageFloor\` in \`test/previews/preview_structure_test.dart\` to the
   uncovered count the tool now reports.
4. Spot-check TWO preview sections against \`lib/core/previews/README.md\`. Reject
   and fix any that preview only a happy path, construct a real repository, or
   pass no \`expectedText\`.
5. \`git status\` must show no scratch/probe files.

Screens attempted: ${batch.map((w) => w.widget).join(', ')}.
${failed.length ? `Reported FAILED: ${failed.map((r) => r.screen).join(', ')} — diagnose and either finish or explain precisely.` : 'No agent reported a failure.'}

Report final analyze/test counts, the catalog's screen+state counts before and
after, the new coverage number and floor, and anything you repaired.`,
  { label: 'integrate', phase: 'Integrate' }
)

return {
  attempted: batch.length,
  written: written.map((r) => ({ screen: r.screen, previews: r.previewCount, fixtures: r.fixtureSource, states: r.states })),
  failed: failed.map((r) => ({ screen: r.screen, status: r.status, notes: r.notes })),
  findings: done.flatMap((r) => (r.findings || []).map((f) => `${r.screen}: ${f}`)),
  integration,
}
