# Traceability and production-screen coverage

This table maps all 60 explicit Clarity production screen names to one or more
JMS scenarios. Mapping means planned coverage; it does not mean the screen has
been physically reached or processed by Microsoft.

The current route-to-screen source is the
[Clarity navigator allowlist](../../lib/core/analytics/clarity/presentation/clarity_navigator_observer.dart).

| Domain | Canonical screen | Primary scenario | Evidence status |
|---|---|---|---|
| Bootstrap/auth | onboarding | JMS-AUTH-001 | NOT RUN |
| Bootstrap/auth | register | JMS-AUTH-001, JMS-AUTH-002 | NOT RUN |
| Bootstrap/auth | biometric-lock | JMS-AUTH-004 | NOT RUN |
| Bootstrap/auth | set-password | JMS-AUTH-005 | NOT RUN |
| Bootstrap/auth | account-status | JMS-AUTH-007 | NOT RUN |
| Shell | shell | JMS-JHP-001, JMS-JHP-002 | NOT RUN |
| Request | voice-request | JMS-REQ-002 | NOT RUN |
| Request | transcription | JMS-REQ-002 | NOT RUN |
| Request | compose-dictation | JMS-REQ-002 | NOT RUN |
| Request | compose-dictation-review | JMS-REQ-002 | NOT RUN |
| Request | request-type | JMS-REQ-001 | NOT RUN |
| Request | client-location | JMS-REQ-001, JMS-REQ-003 | NOT RUN |
| Request | capture-location | JMS-REQ-003 | NOT RUN |
| Request | request-summary | JMS-REQ-001 | NOT RUN |
| Request | waiting-no-coverage | JMS-REQ-004 | NOT RUN |
| Request | offer-review | JMS-REQ-005, JMS-RES-003 | NOT RUN |
| Jeeber/KYC | delivery-register-prompt | JMS-KYC-001 | NOT RUN |
| Jeeber/KYC | jeeber-onboarding | JMS-KYC-002 | NOT RUN |
| Jeeber/KYC | onboarding-funding | JMS-KYC-003 | NOT RUN |
| Jeeber/KYC | kyc-status | JMS-KYC-004 | NOT RUN |
| Jeeber/KYC | kyc-rejected | JMS-KYC-005 | NOT RUN |
| Jeeber/KYC | offer-kyc-gate | JMS-KYC-007 | NOT RUN |
| Jeeber/KYC | jeeber-request-detail | JMS-KYC-008 | NOT RUN |
| Jeeber/KYC | jeeber-offer-submission | JMS-KYC-008 | NOT RUN |
| Jeeber/KYC | jeeber-pending-offers | JMS-KYC-009 | NOT RUN |
| Jeeber/KYC | jeeber-active-delivery | JMS-DEL-004, JMS-JHP-003 | NOT RUN |
| Delivery | order-summary | JMS-DEL-001 | NOT RUN |
| Delivery | delivery-detail | JMS-DEL-001 | NOT RUN |
| Delivery | live-tracking | JMS-DEL-003 | NOT RUN |
| Delivery | otp-handover | JMS-DEL-006 | NOT RUN |
| Delivery | delivered-receipt | JMS-DEL-008 | NOT RUN |
| Delivery | delivery-cancel | JMS-DEL-009 | NOT RUN |
| Delivery | feedback | JMS-DEL-010 | NOT RUN |
| Delivery | mutual-rating | JMS-DEL-010 | NOT RUN |
| Delivery | rating-prompt | JMS-DEL-010 | NOT RUN |
| Delivery | escalate | JMS-DEL-011 | NOT RUN |
| Chat/profile | chat-detail | JMS-DEL-002, JMS-RES-004 | NOT RUN |
| Chat/profile | customer-profile | JMS-OPS-002 | NOT RUN |
| Chat/profile | delivery-man-profile | JMS-OPS-003 | NOT RUN |
| Chat/profile | reviews-list | JMS-OPS-003 | NOT RUN |
| Chat/profile | reviews-list-by-id | JMS-OPS-003 | NOT RUN |
| Balance/earnings | wallet | JMS-OPS-004 | NOT RUN |
| Balance/earnings | customer-wallet | JMS-OPS-004 | NOT RUN |
| Balance/earnings | wallet-charge-info | JMS-OPS-004 | NOT RUN |
| Balance/earnings | wallet-activity | JMS-OPS-004 | NOT RUN |
| Balance/earnings | transaction-detail | JMS-OPS-004 | NOT RUN |
| Balance/earnings | earnings | JMS-OPS-005 | NOT RUN |
| Notification/support | notifications | JMS-OPS-001, JMS-PUSH-001 | NOT RUN |
| Notification/support | support-ticket | JMS-OPS-006 | NOT RUN |
| Notification/support | support-ticket-detail | JMS-OPS-006 | NOT RUN |
| Notification/support | support-ticket-detail-legacy | JMS-OPS-006 | NOT RUN |
| Notification/support | dispute-status | JMS-DEL-012 | NOT RUN |
| Settings | settings | JMS-OPS-007, JMS-CLR-001 | NOT RUN |
| Settings | settings-profile | JMS-OPS-002 | NOT RUN |
| Settings | settings-addresses | JMS-OPS-008 | NOT RUN |
| Settings | address-detail | JMS-OPS-008 | NOT RUN |
| Settings | settings-notifications | JMS-OPS-009 | NOT RUN |
| Settings | settings-diagnostics | JMS-OPS-010 | NOT RUN |
| Settings | language-settings | JMS-XFN-001 | NOT RUN |
| Settings | password-security | JMS-AUTH-005 | NOT RUN |

The development-only unknown fallback is covered by JMS-CLR-010. It must never
contain a URI, query, route parameter, semantic identifier, or user-entered text.

## Native OS entry-point coverage

`JMS-LINK-001` covers the operating-system boundary that the Clarity screen
allowlist cannot represent: Android domain verification and iOS Associated
Domains must hand `https://app.jeeb.fds-1.com/chat/<synthetic-id>` to the exact
store-delivered app. Its in-app target is `chat-detail`, but reaching that
screen through an in-app router, custom scheme, direct intent, or sideload does
not cover the OS association contract.

## Retired or historical flows

- Separate email login, sign-up, recover, and recovery-verification routes are
  not current end-user routes. Current auth is phone OTP plus Apple/Google on
  register; set-password is for an authenticated social-only account.
- The old customer/Jeeber mode toggle is not the current happy path. Jeeber is
  an additive capability; the five shell tabs remain mounted and server role
  capability controls the live bodies.
- Vehicle registration is not part of current KYC submission.
- Final KYC rejection goes to support appeal. A general reset/resubmit path is
  not assumed; only a backend-directed field resubmission is tested.
