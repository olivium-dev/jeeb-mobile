---
name: guardrails-kb-location
description: The guardrails knowledge base I own lives outside this repo, at /Users/oudaykhaled/Desktop/claude-ui/guardrails/ (README.md is the index)
metadata:
  type: reference
---

The guardrails knowledge base this agent owns is **not** in `jeeb-workspace` — it lives at `/Users/oudaykhaled/Desktop/claude-ui/guardrails/`, indexed by `README.md` (files `01-…` … `19-…`). `/Users/oudaykhaled/jeeb-workspace/CLAUDE.md` → `AGENTS.md` carries the workspace's locked policies and OUTRANKS the KB when they disagree.

Added 2026-07-26: `19-client-lifecycle-and-di-ownership.md` — Flutter client rules mined from the Jeeb b02/FM-3 F1 defect (only the creator disposes; never dispose a GetIt singleton; background pollers must CANCEL not skip; all five `AppLifecycleState`s; adding a member to a Dart interface is breaking because `implements` forces re-implementation of every member).

Batch guardrail briefs for Jeeb delivery batches are written to `/Users/oudaykhaled/jeeb-workspace/docs/batches/<batch-id>/planning/<FM-id>-guardrails.md`.
