# Feature scenario index

Every feature suite starts as NOT RUN. Execute one scenario at a time using the
[per-scenario checklist](../checklists/PER-SCENARIO.md), then record evidence
instead of editing the expected outcome to match observed behavior.

Each exact ID row is a normalized individual record under the
[scenario record contract](../RECORD-CONTRACT.md).

| Domain | Scenario range | File | Existing automation is |
|---|---|---|---|
| Auth and session | JMS-AUTH-001–008 | [AUTH-SESSION.md](AUTH-SESSION.md) | Partial |
| KYC and Jeeber capability | JMS-KYC-001–009 | [KYC-ROLE.md](KYC-ROLE.md) | Mostly seam-level; live KYC gaps remain |
| Request and offer | JMS-REQ-001–008 | [REQUEST-OFFER.md](REQUEST-OFFER.md) | Partial |
| Delivery, chat, and COD | JMS-DEL-001–012 | [DELIVERY-CHAT-COD.md](DELIVERY-CHAT-COD.md) | Screen-level partial; paired loop missing |
| Settings, notifications, and support | JMS-OPS-001–010 | [SETTINGS-NOTIFICATIONS-SUPPORT.md](SETTINGS-NOTIFICATIONS-SUPPORT.md) | Partial |
| Microsoft Clarity and privacy | JMS-CLR-001–012 | [CLARITY-PRIVACY.md](CLARITY-PRIVACY.md) | Focused unit/widget coverage plus manual dashboard gates |

Coverage labels:

- Documented: scenario exists only in this pack.
- Widget: in-process rendering/state test.
- Seam: controlled app/mock route and state.
- Live-single: real transport on one authorized synthetic device/account.
- Live-paired: receiver-side proof across customer and Jeeber devices/accounts.
