# Complex and cross-cutting scenario index

These suites combine multiple screens, services, devices, or lifecycle states.
They are the most complicated paths and should run only after the feature happy
paths are green.

Each exact ID row is a normalized individual record under the
[scenario record contract](../RECORD-CONTRACT.md).

| Range | Focus | File | Default gate |
|---|---|---|---|
| JMS-RES-001–010 | Offline, retry, idempotency, concurrency, recovery | [RESILIENCE-CONCURRENCY.md](RESILIENCE-CONCURRENCY.md) | Regression / RC |
| JMS-PUSH-001–010 | Native push, deep links, lifecycle, process death | [PUSH-DEEP-LINK-LIFECYCLE.md](PUSH-DEEP-LINK-LIFECYCLE.md) | RC |
| JMS-LINK-001 | OS-verified Android App Link and iOS Universal Link | [JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md](JMS-LINK-001-OS-APP-UNIVERSAL-LINKS.md) | RC |
| JMS-XFN-001–012 | Locale, RTL, accessibility, security, performance | [LOCALE-ACCESSIBILITY-SECURITY.md](LOCALE-ACCESSIBILITY-SECURITY.md) | Regression / RC |

Run order:

1. Prove the happy path on a synthetic seam.
2. Prove the same path through authorized real transport where required.
3. Add one fault at a time.
4. Reconcile state before retrying an unknown result.
5. Finish with paired-device, process-death, and combined-fault paths.

`JMS-LINK-001` is intentionally separate from in-app push routing. It passes
only when the operating system hands a real HTTPS link to builds installed from
Play Internal Testing and TestFlight.
