# Journey index

These are the shortest end-to-end paths a human can understand and execute.
Each path uses synthetic accounts and starts as NOT RUN.

| ID | Difficulty | Journey | Personas/devices | Mutation | Gate |
|---|---|---|---|---|---|
| [JMS-JHP-001](JMS-JHP-001-CUSTOMER-REQUEST.md) | Happy | New customer creates a request | One customer | R2 isolated write | Smoke |
| [JMS-JHP-002](JMS-JHP-002-JEEBER-KYC-OFFER.md) | Happy + approval boundary | Customer activates Jeeber capability, completes KYC, submits offer | One user + authorized test-state operator | R3 sensitive lifecycle | Regression |
| [JMS-JHP-003](JMS-JHP-003-TWO-PERSONA-COD.md) | Full product loop | Request through chat, delivery, OTP, COD receipt, rating | Customer + Jeeber, preferably two devices | R3 sensitive lifecycle | RC |

The journey files intentionally stay linear. Their negative and recovery
variants live in the feature and cross-cutting indexes.
