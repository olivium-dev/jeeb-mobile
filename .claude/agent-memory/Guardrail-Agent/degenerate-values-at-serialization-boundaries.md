---
name: degenerate-values-at-serialization-boundaries
description: Any value crossing a serialization boundary needs a test built from the actual wire representation — a non-nullable DateTimeOffset serializes "missing" as 0001-01-01 and every layer downstream accepts it
metadata:
  type: project
---

**Any value crossing a serialization boundary needs a degenerate-value test built from the
ACTUAL WIRE REPRESENTATION — not from a test-constructed object.**

The trap: a non-nullable `DateTimeOffset` serializes a *missing* upstream value as
`0001-01-01T00:00:00+00:00`. `DateTime.tryParse` accepts it happily. Downstream logic then
silently disables itself while looking entirely correct — no exception, no null, no log line.

**Why this defeats mutation/negative-control testing.** Every fake-time test **constructs
its own input**, so it never crosses the real wire boundary and never sees the degenerate
value. Negative controls prove *an implementation can fail*; they say nothing about *a
value that arrives already meaningless*. Two different halves of one risk — neither
substitutes for the other.

This is the same shape as the b01 `{"valueKind":1}` husk: a serializer emitting a
structurally valid, semantically empty value that every layer downstream accepts.

**Highest exposure in this fleet:** gateway `MapRow` / `ExtractRows` fallbacks on the
Newtonsoft `JObject` boundary, then the chat and delivery DTOs.

**How to apply:** build at least one case per DTO from a raw wire string / `JObject` /
captured payload, covering absent field, `null`, empty string,
`0001-01-01T00:00:00+00:00`, `default(T)`, `{}`, `[]`, `{"valueKind":1}`. Assert the
consumer **rejects or flags** the value — "doesn't crash" is the failure mode, not the
pass condition. Companion rule: before treating any DTO as authoritative, trace the route
to the handler and confirm you are reading the *routed* DTO, not merely a *plausible* one
— the plausible DTO usually also compiles, is referenced, and has its own passing tests,
so nothing about it looks wrong. Related:
[[negative-control-before-fake-time-evidence]], [[lineage-gate-before-any-deploy]].
