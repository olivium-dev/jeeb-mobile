export const meta = {
  name: 'preview-rollout',
  description: 'Write @JeebPreview previews + render tests for a batch of uncovered widgets',
  whenToUse: 'One wave of the widget-preview rollout. Pass args = the batch from `dart run tool/preview_coverage.dart --json`. Each agent owns exactly one widget and writes two new files, so agents never touch the same file.',
  phases: [
    { title: 'Write', detail: 'one agent per widget: preview file + render test, self-verified' },
    { title: 'Integrate', detail: 'analyze + run the whole preview suite together' },
  ],
}

// args: { batch: [{widget, source, area, previewPath}], repoRoot: string }
// Tolerate args arriving as a JSON string — some callers stringify it, and a
// silently-empty batch looks identical to "nothing left to do".
const input = typeof args === 'string' ? JSON.parse(args) : args || {}
const batch = input.batch || []
const repoRoot = input.repoRoot || '.'

if (batch.length === 0) {
  log('Nothing to do — the coverage queue is empty.')
  return { written: [], failed: [], skipped: 'empty queue' }
}

log(`Rollout wave: ${batch.length} widgets — ${batch.map((w) => w.widget).join(', ')}`)

const RESULT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['widget', 'status', 'previewCount', 'notes'],
  properties: {
    widget: { type: 'string' },
    status: {
      type: 'string',
      enum: ['written', 'failed', 'skipped-not-previewable'],
      description: 'skipped-not-previewable ONLY for widgets with no renderable output of their own',
    },
    previewCount: { type: 'integer', description: 'number of @JeebPreview functions written' },
    states: { type: 'array', items: { type: 'string' } },
    findings: {
      type: 'array',
      items: { type: 'string' },
      description: 'real layout/RTL/a11y problems the preview exposed — not a summary of the work',
    },
    notes: { type: 'string' },
  },
}

function writePrompt(w) {
  return `You are adding a Flutter widget preview for ONE widget in the jeeb-mobile repo.

Working directory: ${repoRoot}
Widget class:  ${w.widget}
Source file:   ${w.source}
Write preview: ${w.previewPath}
Write test:    test/previews/${w.area}/${snake(w.widget)}_preview_test.dart

## Read these first, in this order

1. \`lib/previews/README.md\` — the conventions you must follow.
2. \`lib/previews/home_client/client_home_greeting_preview.dart\` — the reference
   preview. Copy its shape: a private \`_hosted(...)\` helper, then one annotated
   top-level function per state, each with a doc comment saying WHY that state
   matters.
3. \`test/previews/home_client/client_home_greeting_preview_test.dart\` — the
   reference test. It is short because \`testPreviewsRender()\` does the work.
4. \`${w.source}\` — the widget itself, and any existing test for it under
   \`test/\` (grep for \`${w.widget}\`). Existing tests are the best source of
   realistic fixture data; reuse their values rather than inventing new ones.

## Rules

- **Two new files only.** Do NOT modify \`${w.source}\` or any other production
  code. If the widget genuinely cannot be previewed without a production change
  (e.g. it has no injectable seam for its dependency), return
  status \`failed\` and explain exactly what seam is missing. Do not add the seam.
- **Leave no debris.** If you write a throwaway probe/scratch test to measure a
  layout, DELETE it before you finish. The last wave left five \`*_probe_test.dart\`
  files behind for the integration agent to sweep up. \`git status\` must show only
  your two intended files.
- **No network, ever.** Seed state with an inert cubit (\`SomeCubit(seed: ...)\`,
  no repository) or a local fake class implementing the repository interface with
  canned data. Never construct a Dio-backed repository.
- **Import the harness** as \`import '../harness/jeeb_preview.dart';\` and annotate
  with \`@JeebPreview(group: '${w.area}', name: '<state>', size: Size(w, h))\`.
  \`group\` is REQUIRED and must be exactly \`'${w.area}'\` — the canvas renders one
  collapsible section per group, and that is what keeps ~700 previews navigable.
  Pick a \`size\` that actually fits the widget — a row wants something short and
  wide, a card wants near phone width (390 logical px).
- **Add \`matrix: true\`** to the ONE OR TWO states where seeing EN light, AR RTL
  dark and EN 200% side by side is the point (a Row of text + actions, an
  RTL-sensitive layout, copy whose length swings by locale). Leave it off
  elsewhere: all three for every state is a slow, unreadable canvas. AR is still
  asserted on every state by \`testPreviewsRender()\` regardless, so this changes
  what a reviewer LOOKS at, not what is checked.
- **Cover the states that BREAK**, not just the happy path. Aim for 3–6:
  empty / loading / error / longest-plausible-content / any state a existing test
  or code comment flags as a past bug. One preview of the default state is not
  enough and will be rejected.
- **The test must pin content.** Pass \`expectedText\` to \`testPreviewsRender()\`
  with a distinct string per state. A test that only checks "something rendered"
  passes even when every preview shows the same widget — that exact failure has
  already bitten this project once.

## Verify before you report — do not skip this

Run both, from ${repoRoot}, and fix anything they surface:

    flutter analyze --no-pub ${w.previewPath} test/previews/${w.area}/${snake(w.widget)}_preview_test.dart
    flutter test test/previews/${w.area}/${snake(w.widget)}_preview_test.dart

Report status \`written\` ONLY if both are clean. If you cannot make them pass,
report \`failed\` with the actual error text — a false \`written\` is worse than a
failure, because the ratchet will bake it in.

In \`findings\`, list any REAL problem the preview exposed in the widget itself
(text overflowing at 200%, layout not mirroring in RTL, hardcoded English,
contrast). Leave it empty if there were none. Do not put a summary of your work
there.`
}

function snake(pascal) {
  return pascal.replace(/(?<=[a-z0-9])([A-Z])/g, '_$1').toLowerCase()
}

phase('Write')

const results = await parallel(
  batch.map((w) => () =>
    agent(writePrompt(w), {
      label: `preview:${w.widget}`,
      phase: 'Write',
      schema: RESULT_SCHEMA,
    })
  )
)

const done = results.filter(Boolean)
const written = done.filter((r) => r.status === 'written')
const failed = done.filter((r) => r.status !== 'written')
const died = results.length - done.length

log(`Written ${written.length}/${batch.length} · failed ${failed.length} · agent errors ${died}`)

// Barrier is correct here: the integration check is about the suite AS A WHOLE
// (cross-file analyze + the ratchet), which needs every writer finished.
phase('Integrate')

const integration = await agent(
  `All preview work for this wave is on disk in ${repoRoot}. Verify the repo is
coherent — you are the gate before this gets committed.

Run, from ${repoRoot}:

    flutter analyze --no-pub lib/ test/previews/ tool/
    flutter test test/previews/
    dart run tool/preview_coverage.dart

Then:

1. If \`flutter analyze\` or \`flutter test\` fail, FIX the offending preview or
   test files (never production code) until both are clean. Report what you fixed.
2. Lower \`_coverageFloor\` in \`test/previews/preview_structure_test.dart\` to the
   uncovered count that \`preview_coverage.dart\` now reports, so the ratchet holds
   the new ground. Re-run \`flutter test test/previews/preview_structure_test.dart\`.
3. Spot-check TWO of the preview files written this wave against
   \`lib/previews/README.md\`. Reject-and-fix any that: preview only a happy path,
   construct a real repository, or pass no \`expectedText\` in its test.

Widgets attempted this wave: ${batch.map((w) => w.widget).join(', ')}.

Report the final analyze/test status, the new floor, and anything you had to fix.`,
  { label: 'integrate', phase: 'Integrate' }
)

return {
  attempted: batch.length,
  written: written.map((r) => ({ widget: r.widget, states: r.states, previews: r.previewCount })),
  failed: failed.map((r) => ({ widget: r.widget, status: r.status, notes: r.notes })),
  agentErrors: died,
  findings: done.flatMap((r) => (r.findings || []).map((f) => `${r.widget}: ${f}`)),
  integration,
}
