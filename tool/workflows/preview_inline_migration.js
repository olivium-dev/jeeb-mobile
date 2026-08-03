export const meta = {
  name: 'preview-inline-migration',
  description: 'Move every @JeebPreview from lib/previews/ into the widget its own source file, so the IDE preview panel shows it when that file is open',
  whenToUse: 'One-shot migration. args = {repoRoot, areas: ["chat", ["app","auth"], ...]} — each entry is one agent, a string or a list of areas. Plan, fan out, then repair the tooling and verify.',
  phases: [
    { title: 'Plan', detail: 'one agent writes the migration spec everyone follows' },
    { title: 'Migrate', detail: 'one agent per area group, owns every widget in it' },
    { title: 'Integrate', detail: 'rewrite coverage tool + guardrails, full verification' },
  ],
}

const input = typeof args === 'string' ? JSON.parse(args) : args || {}
const repoRoot = input.repoRoot
// Areas are disjoint across source files (verified: the only two multi-widget
// source files are both in home_client), so no two agents can ever open the same
// file. Each agent discovers its own widgets by listing lib/previews/<area>/ —
// passing 128 derivable rows through args would be pure bulk.
// Each entry is a LIST of areas one agent owns, so small areas can share an agent
// without ever sharing a file.
const groups = (input.areas || []).map((g) => (Array.isArray(g) ? g : [g]))

if (!repoRoot || groups.length === 0) {
  log('Nothing to migrate — args.areas was empty.')
  return { migrated: [], skipped: 'empty input' }
}

const areas = groups.flat()
log(`migrating ${areas.length} areas across ${groups.length} agents`)

phase('Plan')

const spec = await agent(
  `You are writing the migration spec that ~10 sibling agents will follow LITERALLY.
Be prescriptive and concrete. Working directory: ${repoRoot}

## The goal

Today every preview lives in \`lib/previews/<area>/<widget>_preview.dart\`. The IDE
preview panel filters by the **currently selected source file** — it matches the file
the \`@Preview\` function is DECLARED in (the generated scaffold stamps each preview
with a \`scriptUri\`). So a preview only appears when you open the *preview* file, not
the widget. We are moving each preview INTO its widget's own source file so that
opening e.g. \`client_home_greeting.dart\` in Android Studio shows its previews.

## Read before deciding

- \`lib/previews/README.md\` — the conventions being replaced.
- \`lib/previews/harness/jeeb_preview.dart\` — \`JeebPreview\` (group + matrix), the host
  wrapper, theme and l10n helpers.
- \`lib/previews/home_client/client_home_greeting_preview.dart\` and its test
  \`test/previews/home_client/client_home_greeting_preview_test.dart\` — the reference pair.
- \`tool/preview_coverage.dart\` — computes coverage as "owns
  lib/previews/<area>/<snake>_preview.dart". That rule DIES with this migration.
- \`test/previews/preview_structure_test.dart\` — two ratchets. One asserts nothing
  outside \`lib/previews/\` imports it. After this migration EVERY migrated widget file
  will import the harness, so that invariant must be redefined, not deleted silently.
- \`test/previews/preview_test_harness.dart\` — \`testPreviewsRender()\`; tests import
  preview functions by \`package:\` URI and those URIs all change.

## Decide and write down, with reasons

1. **Where the harness lives.** It currently sits under \`lib/previews/harness/\`. If
   production files import it, the "previews never leak into production" guardrail is
   false as written. Options: move it (e.g. \`lib/core/previews/\`), keep it and
   redefine the guardrail, or something better. Pick ONE and justify it.
2. **The exact in-file layout.** Where in the widget file do previews go (bottom,
   under a banner comment?), how are private fixtures named to avoid colliding with
   the widget file's existing privates (many preview files define \`_hosted\`), and what
   the required header comment says so a reader knows this code does not ship.
3. **Import handling.** Preview code needs imports the widget file may not have. State
   the rule for adding them and for avoiding duplicate/unused imports.
4. **The new coverage rule** for \`tool/preview_coverage.dart\`: a widget is covered
   when its OWN source file contains a \`@JeebPreview\` annotating a function that
   returns its widget. Write the precise detection you want.
5. **The new structural invariants** to replace the old ones. At minimum: previews
   still must not be referenced by shipping code paths, and coverage must still
   ratchet. Say exactly what to assert.
6. **Test file disposition** — do the tests stay in \`test/previews/<area>/\`, and what
   exactly changes in them (the import, and anything else)?
7. **Risks and non-obvious traps** the migrating agents must avoid. Think about: the
   \`part\`/\`part of\` files if any, files with existing top-level private names,
   \`library\` directives, widget files that are already large, and the fact that
   \`flutter analyze\` must stay clean.

## Verify, do not assume

Read the actual files. Try your proposed layout on ONE widget end-to-end
(\`ClientHomeGreeting\` is the reference) — actually make the edit, run
\`flutter analyze --no-pub <the file>\` and
\`flutter test test/previews/home_client/client_home_greeting_preview_test.dart\`,
confirm it passes, and then REVERT your change with git so the tree is clean for the
sibling agents. Report what you learned from doing it, not what you expect.

Return the spec as prose the other agents can follow without re-deriving anything.`,
  { label: 'plan', phase: 'Plan' }
)

log('Spec ready — fanning out by area')

const RESULT = {
  type: 'object',
  additionalProperties: false,
  required: ['area', 'migrated', 'failed', 'notes'],
  properties: {
    area: { type: 'string' },
    migrated: { type: 'array', items: { type: 'string' } },
    failed: { type: 'array', items: { type: 'string' } },
    deletedPreviewFiles: { type: 'integer' },
    notes: { type: 'string' },
  },
}

phase('Migrate')

const results = await parallel(
  groups.map((group) => () =>
    agent(
      `Migrate every widget preview in these areas into each widget's own source file:
**${group.join(', ')}**. Working directory: ${repoRoot}. You own these areas
exclusively — no other agent will touch these files.

## Follow this spec exactly

${spec}

## Your widgets — discover them yourself

Every file in ${group.map((a) => `\`lib/previews/${a}/\``).join(' and ')} is yours. For each \`<snake>_preview.dart\`:
the widget class is \`<snake>\` in PascalCase, and its source file is the one where
\`grep -rn "^class <Pascal> extends" lib/\` matches. Confirm each mapping before you
edit — do not guess from the import list, which often points at a domain or cubit
file rather than the widget.

NOTE: two source files hold more than one previewed widget —
\`pending_requests_tab.dart\` (3) and \`active_request_card.dart\` (2). If either is in
your list, merge ALL of their previews into that one file in a single pass; do not
process them independently.

## Per widget

1. Move the \`@JeebPreview\` functions AND their private fixtures/fakes out of the
   preview file and into the widget's source file, per the spec's layout.
2. Add whatever imports the moved code needs; remove none that the widget still uses.
3. Delete the now-empty preview file.
4. Update the corresponding test under \`test/previews/<area>/\` so it imports the
   preview functions from the widget's source file instead of the deleted preview file.
   Change NOTHING else about the test — its assertions are the safety net for this
   migration and must keep passing unchanged.
5. Preserve every \`group:\`, \`name:\`, \`size:\` and \`matrix:\` argument verbatim.

## Verify before reporting — this is the whole point

    flutter analyze --no-pub <each source file you edited> ${group.map((a) => `test/previews/${a}/`).join(' ')}
    flutter test ${group.map((a) => `test/previews/${a}/`).join(' ')}

Both must be clean. Report a widget under \`failed\` (with the real error text) rather
than reporting a green result you did not observe — the integration agent re-runs
everything and a false pass just wastes a round trip.

Do NOT change any widget's behaviour. This is a code MOVE. If a preview only compiles
after you alter the widget, that is a finding to report, not a change to make.

Leave no scratch files. Do NOT run `git commit` or `git push` — leave your work
staged in the tree. The orchestrator commits once, after the integration gate; agents
committing independently interleaves four unreviewed commits into the history.`,
      { label: `migrate:${group.join('+')}`, phase: 'Migrate', schema: RESULT }
    )
  )
)

const done = results.filter(Boolean)
const migrated = done.flatMap((r) => r.migrated || [])
const failed = done.flatMap((r) => r.failed || [])
log(`migrated ${migrated.length} · failed ${failed.length} · agent errors ${results.length - done.length}`)

// Barrier is correct: the tooling rewrite and the full-suite run need every area done.
phase('Integrate')

const integration = await agent(
  `Every area has migrated its previews into the widget source files. You are the gate.
Working directory: ${repoRoot}

The spec the migration followed:

${spec}

## Do

1. **Rewrite \`tool/preview_coverage.dart\`** to the new coverage rule from the spec
   (a widget is covered when its own source file carries a \`@JeebPreview\`). Keep the
   \`--json\` and \`--area\` flags working — a loop depends on them. Keep honouring
   \`tool/preview_exclusions.txt\` and the excluded path prefixes.
2. **Rewrite \`test/previews/preview_structure_test.dart\`** to the new invariants from
   the spec, and set the coverage floor to the honest number the tool now reports.
3. **Confirm \`lib/previews/\` holds only what the spec says it should** (the harness, if
   the spec kept it there). Every \`*_preview.dart\` under it should be gone. Report any
   stragglers rather than deleting something the spec did not account for.
4. **Update \`lib/previews/README.md\` and \`docs/previews/ROLLOUT_PLAN.md\`** so they
   describe where previews now live and WHY the move happened (the IDE panel filters by
   the declaring file). Do not leave instructions that send the next author to the old
   layout.
5. **Run the full check and fix what breaks** — preview/test files only, never widget
   behaviour:

       flutter analyze --no-pub lib/ test/ tool/
       flutter test test/previews/
       dart run tool/preview_coverage.dart

6. \`git status\` must show no scratch/probe files.

Areas migrated: ${areas.join(', ')}.
${failed.length ? `Widgets reported FAILED by their area agent: ${failed.join(', ')} — diagnose and either finish or report precisely why not.` : 'No area reported a failure.'}

Report: final analyze/test counts, the new coverage number and floor, anything you had
to repair, and any widget still not migrated.`,
  { label: 'integrate', phase: 'Integrate' }
)

return {
  areas: areas.length,
  migrated: migrated.length,
  failed,
  agentErrors: results.length - done.length,
  perArea: done.map((r) => ({ area: r.area, migrated: (r.migrated || []).length, failed: (r.failed || []).length, notes: r.notes })),
  spec,
  integration,
}
