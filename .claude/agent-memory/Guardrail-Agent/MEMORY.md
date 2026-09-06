# Memory index

- [Shared wiring files are the collision surface](shared-wiring-files-are-the-collision-surface.md) — per-lane fences fence feature dirs and forget injection_container.dart / app.dart / Program.cs; assign those owners first
- [Guardrails KB location](guardrails-kb-location.md) — the KB I own is at /Users/oudaykhaled/Desktop/claude-ui/guardrails/, not in this repo; CLAUDE.md outranks it
- [Historical MSI-only ruling, superseded for approved staging](owner-ruling-msi-only-no-staging.md) — the 2026-07-26 b02 rule remains historical; owner-approved `.20` deployments resumed 2026-08-18 through the staging pipeline
- [Push service has no read API](push-service-has-no-read-api.md) — no GET on /register, so device-row prunes are unsnapshottable; blind `by-user` delete is banned
- [Dart `implements` widening trap](dart-implements-widening-trap.md) — 60+ jeeb-mobile interfaces have 3+ `implements` sites; adding one member breaks devtool catalog files outside every fence — use a mixin
- [jeeb-mobile fails open to production](jeeb-mobile-fails-open-to-production.md) — AppConfig.gatewayBaseUrl defaults to https://api.jeeb.app; a build without --dart-define GATEWAY_BASE_URL silently talks to prod
- [Negative control before fake-time evidence](negative-control-before-fake-time-evidence.md) — named mutation + expected RED reason + hash-verified revert; "tests pass" alone is a refusable submission
- [Lineage gate before any deploy](lineage-gate-before-any-deploy.md) — `merge-base --is-ancestor deployed candidate` or don't ship; health checks prove a build runs, only ancestry proves it isn't a regression
- [Verifier must not share the executor's sandbox](verifier-must-not-share-executor-sandbox.md) — a shared blind spot can't be fixed by testing harder; run gates from your own shell, and report denials rather than routing around them
- [Gates scope to the diff, not the tree](gates-scope-to-the-diff-not-the-tree.md) — blocking on inherited state gets the gate waived wholesale; LANE-INTRODUCED blocks, INHERITED reports, DEPLOY-GATE blocks only deploys
- [Instruments only observed succeeding are unproven](instruments-only-observed-succeeding.md) — 4 verification tools lied in one batch; require a positive control, never trust an exit code in either direction
- [flutter test needs --add-dir under codex exec](flutter-test-codex-sandbox-add-dir.md) — sandbox denies Flutter SDK cache + ~/.dart-tool writes → exit 255; dart analyze is unaffected so lanes look healthy until first test
- [Degenerate values at serialization boundaries](degenerate-values-at-serialization-boundaries.md) — build the test from the raw wire payload; fake-time tests construct their own input and never see a value that arrives already meaningless
- [Device validations leave no state](device-validation-leaves-no-state.md) — every device run records created ids to `CREATED.jsonl` and ends with `tool/device_validation_cleanup.sh sweep && audit`; a REPORT without a Residual-state section is rejected, and the two offer projections must be compared by liveness class, not status strings
