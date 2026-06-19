# 65 — Wave 2 / Wave 2.5 Test Plan

> **Author:** Senior Principal QA Engineer (Sonnet). **Date:** 2026-06-18.
> **Status:** AUTHORED (flows are RED — test-first, pre-implementation).
>
> This plan covers every Wave 2 + Wave 2.5 JM item: JM-036 through JM-048
> (jeeber onboarding / KYC-gates-offering) and JM-051, JM-053, JM-054
> (mark-delivered, wallet hub, wallet charge-info). Each flow starts as a
> **jeeber** (jeeb.seam.session=jeeber_logged_in) plus the additional seam
> keys each AC requires (kycStatus variant, wallet state, journey seed).
>
> **All flows are STATUS: RED until the named JM item ships AND its required
> seam/mock seeds exist.** Partial-park notes call out which ACs additionally
> gate on a backend mock-fix (O1, W1m, K1, D1m, U1).
>
> Companion docs: `30_BACKLOG.md` (ACs), `62_SEAM_HARNESS.md` (seam contract),
> `50_EXECUTION_PLAN.md §WAVE 2`, `21_NAV_PLAN.md §B Batch W2`.

---

## 1. Master table

| JM | Flow file | Identifiers asserted / tapped | Navigation assertions | Required seam / mock test-data |
|---|---|---|---|---|
| **JM-036** | `jm-036-delivery-tab-kyc-gate.yaml` | `delivery_register_prompt`, `delivery_register_now_cta`, `delivery_tab_wallet_chip`, `delivery_tab_bell`, `jeeber_feed_root`, `notifications_root` | `shell_tab_dashboard` → `delivery_register_prompt` (not-approved); `delivery_register_now_cta` → `dm_onboarding_continue`; `shell_tab_dashboard` → `jeeber_feed_root` (approved); `delivery_tab_wallet_chip` → `wallet_available_balance`; `delivery_tab_bell` → `notifications_root` | `jeeb.seam.session=jeeber_logged_in` + **`jeeb.seam.kyc_status=none`** (new); **`jeeb.seam.kyc_status=approved`** (new); mock endpoint `GET /user-management/users/:userId/kyc` must return correct kycStatus per seed |
| **JM-037** | `jm-037-remove-vehicle-field.yaml` | `dm_onboarding_address_root`, `dm_onboarding_address_vehicle_number_field` (assertNotVisible), `dm_onboarding_address_state_field`, `dm_onboarding_address_country_field`, `dm_onboarding_address_street_field`, `dm_onboarding_address_field`, `dm_onboarding_continue`, `dm_onboarding_service_area_root` | `dm_onboarding_continue` → `dm_onboarding_address_root` (photo→address); `dm_onboarding_continue` → `dm_onboarding_service_area_root` (address→service-area) | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=none`; no new mock endpoints needed; requires JM-037 widget removal landed |
| **JM-038** | `jm-038-service-area-homebase-pin.yaml` | `dm_onboarding_service_area_root`, `dm_onboarding_distance_slider` (assertNotVisible), `service_area_map_pin`, `service_area_select_location`, `capture_location_pin_cta`, `dm_onboarding_continue`, `kyc_wizard_root` | `service_area_select_location` → `capture_location_pin_cta`; `dm_onboarding_continue` → `kyc_wizard_root` (service-area→kyc-identity) | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=none`; `POST /matching/v1/matching/find-jeebers` must accept home-base |
| **JM-039** | `jm-039-onboarding-photo-step-nav.yaml` | `dm_onboarding_continue`, `dm_onboarding_back`, `delivery_register_now_cta`, `delivery_register_prompt`, `dm_onboarding_address_root` | `dm_onboarding_back` → `delivery_register_prompt` (NOT random pop); `dm_onboarding_continue` → `dm_onboarding_address_root` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=none`; no new mock endpoints |
| **JM-040** | `jm-040-kyc-identity.yaml` | `kyc_wizard_root`, `kyc_vehicle_step` (assertNotVisible), `kyc_id_front_upload`, `kyc_submit_cta`, `funding_explainer` | `dm_onboarding_continue` (service-area) → `kyc_wizard_root`; `kyc_submit_cta` → `funding_explainer` (NOT standalone status view) | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=none`; **mock-fix K1** (KYC gateway path reconcile) must land; `POST /form-builder-service/v1/templates/jeeb_jeeber_v1/submit`; `POST /user-management/users/:userId/kyc-link` |
| **JM-041** | `jm-041-onboarding-funding.yaml` | `funding_explainer`, `funding_topup_cta`, `funding_continue_cta`, `charge_info_back_cta`, `kyc_status_root` | `funding_topup_cta` → `charge_info_back_cta`; `funding_continue_cta` → `kyc_status_root` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=pending` + **`jeeb.seam.journey=jeeber_kyc_submitted`** (new); route `/jeeber/onboarding/funding` must be registered (W2-INT); `GET /wallet-service/v1/jeeb/earnings` |
| **JM-042** | `jm-042-kyc-pending-status.yaml` | `kyc_status_root`, `kyc_status_topup_allowed_note`, `kyc_status_feed_cta`, `kyc_status_wallet_cta`, `kyc_status_topup_cta`, `kyc_status_view_rejection`, `jeeber_feed_root`, `wallet_available_balance`, `charge_info_back_cta`, `kyc_rejected_root` | `kyc_status_feed_cta` → `jeeber_feed_root`; `kyc_status_wallet_cta` → `wallet_available_balance`; `kyc_status_topup_cta` → `charge_info_back_cta`; `kyc_status_view_rejection` → `kyc_rejected_root` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved/pending/rejected` (all 3 variants); `GET /user-management/users/:userId/kyc`; route pin `jeeb.route=/profile/kyc?step=status` |
| **JM-043** | `jm-043-kyc-rejected.yaml` | `kyc_rejected_root`, `kyc_rejected_resubmit_cta` (assertNotVisible), `kyc_rejected_appeal_cta`, `kyc_rejected_back_cta`, `support_submit_cta`, `customer_profile_wallet_chip` | `kyc_rejected_appeal_cta` → `support_submit_cta`; `kyc_rejected_back_cta` → `customer_profile_wallet_chip` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=rejected`; route pin `jeeb.route=/kyc/rejected`; `GET /user-management/users/:userId/kyc` (status=rejected); route `/kyc/rejected` registered (W2-INT) |
| **JM-044** | `jm-044-offer-kyc-gate.yaml` | `offer_kyc_gate`, `gate_topup_note`, `gate_start_kyc_cta`, `gate_register_link`, `gate_back_cta`, `kyc_wizard_root`, `delivery_register_prompt`, `jeeber_feed_root`, `offer_composer_root`, `feed_make_offer_cta` | `feed_make_offer_cta` (unapproved) → `offer_kyc_gate`; `gate_start_kyc_cta` → `kyc_wizard_root`; `gate_register_link` → `delivery_register_prompt`; `gate_back_cta` → `jeeber_feed_root`; `feed_make_offer_cta` (approved) → `offer_composer_root` (gate skipped) | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=none/approved` + **`jeeb.seam.journey=jeeber_feed_with_request`** (new — stable id: req-feed-001); route `/jeeber/offer-gate` registered (W2-INT); `GET /user-management/users/:userId/kyc` |
| **JM-045** | `jm-045-offer-composer.yaml` | `offer_composer_root`, `offer_composer_fee_line`, `offer_composer_net_line`, `offer_composer_reserve_note`, `offer_composer_eta_dropdown`, `offer_composer_eta_option_0`, `offer_composer_order_ref`, `offer_composer_price_field`, `offer_composer_send_cta`, `jeeber_feed_root`, `insufficient_balance_sheet` | `offer_composer_send_cta` (sufficient) → `jeeber_feed_root`; `offer_composer_send_cta` (insufficient) → `insufficient_balance_sheet` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved` + **`jeeb.seam.wallet_state=sufficient/insufficient`** (new) + `jeeb.seam.journey=jeeber_feed_with_request`; `POST /offer-service/v1/offers`; **mock-fix O1** (402 path) for AC5; **mock-fix W1m** (wallet balance) for AC5 |
| **JM-046** | `jm-046-insufficient-balance-sheet.yaml` | `insufficient_balance_sheet`, `insufficient_balance_needed_amount`, `insufficient_balance_available_amount`, `insufficient_topup_cta`, `insufficient_keep_editing_cta`, `charge_info_back_cta`, `offer_composer_root`, `offer_composer_price_field` | `insufficient_topup_cta` → `charge_info_back_cta`; `insufficient_keep_editing_cta` → `offer_composer_root` (draft preserved) | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved` + `jeeb.seam.wallet_state=insufficient` + `jeeb.seam.journey=jeeber_feed_with_request`; **mock-fix O1** (402 `{needed,available}`); **mock-fix W1m** (wallet balance source) |
| **JM-047** | `jm-047-jeeber-pending-offers.yaml` | `jeeber_feed_root`, `jeeber_feed_pending_tab`, `pending_offer_0`, `pending_offer_0_price`, `pending_offer_0_eta`, `pending_offer_awaiting_label`, `pending_offer_0_withdraw_cta`, `pending_offers_back`, `shell_tab_dashboard` | `jeeber_feed_pending_tab` → `pending_offer_0`; `pending_offer_0_withdraw_cta` → offer removed; `pending_offers_back` → `shell_tab_dashboard` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved` + **`jeeb.seam.journey=jeeber_pending_offers`** (new — stable id: pending-offer-jeeber-001); `GET /offer-service/v1/offers?jeeberId=user-jeeber-002`; `DELETE /offer-service/v1/offers/:offerId` |
| **JM-048** | `jm-048-delivery-feed.yaml` | `jeeber_feed_root`, `feed_make_offer_cta`, `offer_kyc_gate`, `offer_composer_root`, `jeeber_feed_pending_tab`, `pending_offer_0` | `feed_make_offer_cta` (unapproved) → `offer_kyc_gate`; `feed_make_offer_cta` (approved) → `offer_composer_root`; `jeeber_feed_pending_tab` → `pending_offer_0` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=none/approved` + `jeeb.seam.journey=jeeber_feed_with_request` (and `jeeber_pending_offers` for AC3); `GET /delivery-service/v1/requests?status=`; `GET /offer-service/v1/offers?jeeberId=` |
| **JM-051** | `jm-051-mark-delivered.yaml` | `mark_delivered_root`, `mark_delivered_proof_photo`, `mark_delivered_cash_note`, `mark_delivered_cta`, `rating_submit_cta`, `phone_otp_verify_cta` (assertNotVisible) | `mark_delivered_cta` → `rating_submit_cta` (NOT `phone_otp_verify_cta`); route `/jeeber/deliveries/:id/active` reachable (seam pin confirms) | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved` + **`jeeb.seam.journey=jeeber_active_delivery`** (new — stable id: del-jeeber-002-active; route pin: `/jeeber/deliveries/del-jeeber-002-active/active`); **mock-fix D1m** (proof-photo upload sink); `POST /delivery-service/v1/delivery/status/transition` |
| **JM-053** | `jm-053-wallet-hub.yaml` | `wallet_available_balance`, `wallet_gift_badge`, `wallet_affordability_card`, `wallet_reserved_now`, `wallet_topup_cta`, `wallet_how_fees_work`, `wallet_how_fees_explainer`, `wallet_earnings_row`, `wallet_see_all_activity`, `wallet_kyc_pending_banner`, `charge_info_back_cta`, `earnings_total_cash`, `wallet_activity_root` | `wallet_topup_cta` → `charge_info_back_cta`; `wallet_how_fees_work` → `wallet_how_fees_explainer`; `wallet_earnings_row` → `earnings_total_cash`; `wallet_see_all_activity` → `wallet_activity_root` | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved/pending` + `jeeb.seam.wallet_state=sufficient/insufficient`; route `/wallet` replaced (W2-INT); **mock-fix W1m** (balance/affordability/reserved-now/gift endpoint); `GET /wallet-service/v1/jeeb/earnings` |
| **JM-054** | `jm-054-wallet-charge-info.yaml` | `charge_info_root`, `charge_info_store_step`, `charge_info_identity_step`, `charge_info_pay_cash_step`, `charge_info_auto_update_note`, `charge_info_fee_note`, `charge_info_back_cta`, `charge_info_card_input` (assertNotVisible), `charge_info_amount_field` (assertNotVisible), `charge_info_store_directory` (assertNotVisible), `wallet_available_balance` | `charge_info_back_cta` → `wallet_available_balance` (hub); no card/amount/directory visible | `jeeb.seam.session=jeeber_logged_in` + `jeeb.seam.kyc_status=approved`; route `/wallet/charge-info` registered (W2-INT); **no mock call** (static screen) |

---

## 2. Identifier registry — grouped by screen

### JM-036 — DELIVERY Tab KYC Gate
| id | coined? | notes |
|---|---|---|
| `delivery_register_prompt` | existing (W1/W2 gate) | root id of the register-prompt widget in DELIVERY tab |
| `delivery_register_now_cta` | existing | CTA on register prompt → onboarding |
| `delivery_tab_wallet_chip` | **COINED** | wallet chip in DELIVERY tab header; analogous to `orders_home_wallet_chip` |
| `delivery_tab_bell` | **COINED** | bell in DELIVERY tab header; analogous to `orders_home_bell` |
| `jeeber_feed_root` | **COINED** | root of the jeeber request feed (JeeberFeedTabView); replaces `delivery_register_prompt` when approved |
| `notifications_root` | **COINED** | root of the notifications list screen (reused across W4 JM-057) |

### JM-037 — Remove Vehicle Field
| id | coined? | notes |
|---|---|---|
| `dm_onboarding_address_root` | **COINED** | root of the personal-details/address step in onboarding wizard |
| `dm_onboarding_address_vehicle_number_field` | existing (D20 removal target) | assertNotVisible after JM-037 ships |
| `dm_onboarding_address_state_field` | existing | state input in address step |
| `dm_onboarding_address_country_field` | existing | country input |
| `dm_onboarding_address_street_field` | existing | street input |
| `dm_onboarding_address_field` | existing | address input |
| `dm_onboarding_continue` | existing | wizard step continue CTA |
| `dm_onboarding_back` | existing | wizard step back CTA |
| `dm_onboarding_service_area_root` | **COINED** | root of the service-area step |

### JM-038 — Service-Area Home-Base Pin
| id | coined? | notes |
|---|---|---|
| `dm_onboarding_service_area_root` | COINED (see JM-037) | root of the service-area wizard step |
| `dm_onboarding_distance_slider` | existing (D51 removal target) | assertNotVisible after JM-038 ships |
| `service_area_map_pin` | **COINED** | the home-base map pin widget in service-area step |
| `service_area_select_location` | **COINED** | "Select location" / map-pin CTA in service-area step |
| `capture_location_pin_cta` | existing | confirm CTA on location-map-pin screen |
| `kyc_wizard_root` | existing | root of the KYC wizard screen |

### JM-039 — Onboarding Photo Step Nav
| id | coined? | notes |
|---|---|---|
| `dm_onboarding_continue` | existing | continue CTA (photo step) |
| `dm_onboarding_back` | existing | back CTA (photo step) → delivery_register_prompt |
| `delivery_register_prompt` | existing | confirmed landing target on back |
| `delivery_register_now_cta` | existing | confirms we're on register prompt |
| `dm_onboarding_address_root` | COINED (JM-037) | confirms wizard advanced to personal-details |

### JM-040 — KYC Identity
| id | coined? | notes |
|---|---|---|
| `kyc_wizard_root` | existing | root of KYC wizard |
| `kyc_vehicle_step` | existing (D20 removal target) | assertNotVisible after JM-040 ships |
| `kyc_id_front_upload` | existing | gov-ID front photo upload widget |
| `kyc_id_back_upload` | **COINED** | gov-ID back photo upload widget (implied by AC2) |
| `kyc_selfie_upload` | **COINED** | selfie capture widget (implied by AC2) |
| `kyc_submit_cta` | existing | KYC wizard submit CTA |
| `funding_explainer` | **COINED** | root / explainer widget on onboarding-funding screen |

### JM-041 — Onboarding Funding
| id | coined? | notes |
|---|---|---|
| `funding_explainer` | COINED (JM-040) | explainer body widget on funding screen |
| `funding_topup_cta` | **COINED** | "Top up wallet" / charge CTA on funding screen → wallet-charge-info |
| `funding_continue_cta` | **COINED** | "Continue" CTA on funding screen → kyc-pending-status |
| `charge_info_back_cta` | COINED (JM-054) | back CTA on wallet-charge-info screen |
| `kyc_status_root` | existing | root of KYC status view |

### JM-042 — KYC Pending Status
| id | coined? | notes |
|---|---|---|
| `kyc_status_root` | existing | root of KYC status view |
| `kyc_status_topup_allowed_note` | **COINED** | note "top-up allowed while pending" shown on pending variant |
| `kyc_status_feed_cta` | **COINED** | "Go to feed" CTA visible on approved variant |
| `kyc_status_wallet_cta` | **COINED** | "Wallet" CTA on approved variant |
| `kyc_status_topup_cta` | **COINED** | "Top up" CTA on pending/approved variant |
| `kyc_status_view_rejection` | **COINED** | "View rejection details" CTA on rejected variant |
| `jeeber_feed_root` | COINED (JM-036) | confirmed landing target |
| `wallet_available_balance` | COINED (JM-053) | landing target in wallet-hub |
| `charge_info_back_cta` | COINED (JM-054) | landing target in wallet-charge-info |
| `kyc_rejected_root` | **COINED** | root of kyc-rejected screen |

### JM-043 — KYC Rejected
| id | coined? | notes |
|---|---|---|
| `kyc_rejected_root` | COINED (JM-042) | root of kyc-rejected screen |
| `kyc_rejected_resubmit_cta` | existing (D52/D87 removal target) | assertNotVisible |
| `kyc_rejected_appeal_cta` | **COINED** | appeal via support-ticket CTA |
| `kyc_rejected_back_cta` | **COINED** | back → customer-profile CTA |
| `support_submit_cta` | existing (W4 JM-063) | landing target on support-ticket |
| `customer_profile_wallet_chip` | existing (W1 JM-035) | landing target on customer-profile |

### JM-044 — Offer KYC Gate
| id | coined? | notes |
|---|---|---|
| `feed_make_offer_cta` | **COINED** | "Make Offer" CTA on a request row in the jeeber feed |
| `offer_kyc_gate` | **COINED** | root of the offer-kyc-gate interstitial screen |
| `gate_topup_note` | **COINED** | "top-up still allowed" note on gate screen |
| `gate_start_kyc_cta` | **COINED** | "Start KYC" CTA on gate → kyc-identity |
| `gate_register_link` | **COINED** | "Register first" link on gate → delivery-register-prompt |
| `gate_back_cta` | **COINED** | back CTA on gate → jeeber-requests-home |
| `kyc_wizard_root` | existing | confirmed landing target |
| `delivery_register_prompt` | existing | confirmed landing target |
| `jeeber_feed_root` | COINED (JM-036) | confirmed landing target |
| `offer_composer_root` | **COINED** | root of the offer composer screen |

### JM-045 — Offer Composer
| id | coined? | notes |
|---|---|---|
| `offer_composer_root` | COINED (JM-044) | root of offer composer |
| `offer_composer_fee_line` | **COINED** | "Platform fee: X%" line (D37/D44) |
| `offer_composer_net_line` | **COINED** | "You earn (cash)" net-per-offer line (D44) |
| `offer_composer_reserve_note` | **COINED** | "Reserved now / charged if win / released if not" copy (D1) |
| `offer_composer_eta_dropdown` | **COINED** | ETA picker bounded by tier SLA (D14) |
| `offer_composer_eta_option_0` | **COINED** | first ETA option in dropdown (generic index) |
| `offer_composer_order_ref` | **COINED** | "Your offer · ORD-…" header |
| `offer_composer_price_field` | **COINED** | offer price input field |
| `offer_composer_send_cta` | **COINED** | send / submit offer CTA |
| `jeeber_feed_root` | COINED (JM-036) | landing target after successful send |
| `insufficient_balance_sheet` | **COINED** | insufficient-balance bottom sheet root |

### JM-046 — Insufficient Balance Sheet
| id | coined? | notes |
|---|---|---|
| `insufficient_balance_sheet` | COINED (JM-045) | bottom sheet root |
| `insufficient_balance_needed_amount` | **COINED** | "Needed: X.XX" amount display |
| `insufficient_balance_available_amount` | **COINED** | "Available: Y.YY" amount display |
| `insufficient_topup_cta` | **COINED** | "Top up" CTA → wallet-charge-info |
| `insufficient_keep_editing_cta` | **COINED** | "Keep editing" CTA → composer (draft preserved) |
| `charge_info_back_cta` | COINED (JM-054) | confirmed landing target |
| `offer_composer_root` | COINED (JM-044) | confirmed on keep-editing return |
| `offer_composer_price_field` | COINED (JM-045) | draft preservation check |

### JM-047 — Jeeber Pending Offers
| id | coined? | notes |
|---|---|---|
| `jeeber_feed_pending_tab` | **COINED** | pending-response sub-tab chip in jeeber feed |
| `pending_offer_0` | **COINED** | first pending offer row (index 0 of list) |
| `pending_offer_0_price` | **COINED** | price on first pending offer row |
| `pending_offer_0_eta` | **COINED** | ETA on first pending offer row |
| `pending_offer_awaiting_label` | **COINED** | "Awaiting customer decision" label (shared across rows) |
| `pending_offer_0_withdraw_cta` | **COINED** | per-row withdraw CTA [D15] |
| `pending_offers_back` | **COINED** | back from pending offers sub-tab / screen → delivery-requests |

### JM-048 — Delivery Feed
| id | coined? | notes |
|---|---|---|
| `jeeber_feed_root` | COINED (JM-036) | feed root confirmed by approved-KYC seam |
| `feed_make_offer_cta` | COINED (JM-044) | per-request-row make-offer CTA |
| `offer_kyc_gate` | COINED (JM-044) | gate landing when unapproved |
| `offer_composer_root` | COINED (JM-044) | composer landing when approved |
| `jeeber_feed_pending_tab` | COINED (JM-047) | pending tab chip |
| `pending_offer_0` | COINED (JM-047) | first pending offer row |

### JM-051 — Mark Delivered
| id | coined? | notes |
|---|---|---|
| `mark_delivered_root` | **COINED** | root of the jeeber active-delivery / mark-delivered screen |
| `mark_delivered_proof_photo` | **COINED** | proof photo capture widget [D3] |
| `mark_delivered_cash_note` | **COINED** | "customer confirms receipt + pays cash" copy |
| `mark_delivered_cta` | **COINED** | "Mark as delivered" CTA |
| `rating_submit_cta` | existing (W1 JM-034) | landing target on feedback-rate-delivery |
| `phone_otp_verify_cta` | existing (W0 JM-009) | assertNotVisible (OTP handover must not appear) |

### JM-053 — Wallet Hub
| id | coined? | notes |
|---|---|---|
| `wallet_available_balance` | **COINED** | available balance display widget |
| `wallet_gift_badge` | **COINED** | gift/starter-credit badge (post-KYC, D42) |
| `wallet_affordability_card` | **COINED** | affordability state card (D43 — copy only, no capacity number) |
| `wallet_reserved_now` | **COINED** | live-reserves sum widget (D1) |
| `wallet_topup_cta` | **COINED** | "Top up" CTA → wallet-charge-info |
| `wallet_how_fees_work` | **COINED** | "How fees work" link/button |
| `wallet_how_fees_explainer` | **COINED** | fees explainer content (sheet or inline) |
| `wallet_earnings_row` | **COINED** | earnings row → earnings-fees-dashboard |
| `wallet_see_all_activity` | **COINED** | "See all activity" → wallet-activity-list |
| `wallet_kyc_pending_banner` | **COINED** | KYC-pending informational banner |
| `wallet_activity_root` | **COINED** | root of wallet-activity-list screen [JM-055] |
| `earnings_total_cash` | **COINED** | earnings total on earnings-fees-dashboard [JM-052] |
| `charge_info_back_cta` | COINED (JM-054) | landing target in wallet-charge-info |

### JM-054 — Wallet Charge Info
| id | coined? | notes |
|---|---|---|
| `charge_info_root` | **COINED** | root of wallet-charge-info screen |
| `charge_info_store_step` | **COINED** | "Go to authorized store" instruction step |
| `charge_info_identity_step` | **COINED** | "Give phone/ID" instruction step |
| `charge_info_pay_cash_step` | **COINED** | "Pay cash" instruction step |
| `charge_info_auto_update_note` | **COINED** | "Balance auto-updates" note |
| `charge_info_fee_note` | **COINED** | "10% fees from pre-charged balance" note |
| `charge_info_back_cta` | **COINED** | back → wallet-hub CTA |
| `charge_info_card_input` | assertNotVisible — must NOT exist | no card UI |
| `charge_info_amount_field` | assertNotVisible — must NOT exist | no amount input |
| `charge_info_store_directory` | assertNotVisible — must NOT exist | no store directory |
| `wallet_available_balance` | COINED (JM-053) | confirmed landing target after back |

---

## 3. Consolidated NEW seam / mock seeds W2 needs

> All items below are **net-new** — not present in the existing W0/W1 seam contract
> (`62_SEAM_HARNESS.md`). Flag for the seam/backender owner. Grouped by type.

### 3.1 New `jeeb.seam.kyc_status` key (app + mock)

| key | value | what it seeds | owner |
|---|---|---|---|
| `jeeb.seam.kyc_status` | `"none"` | mock returns `kycStatus=none` for user-jeeber-002 on `GET /user-management/users/:userId/kyc`; `SessionSeamBootstrap` sets a kycStatus store value so the app's DELIVERY-tab gate reads "not approved" | app (seam harness) + backenders |
| `jeeb.seam.kyc_status` | `"pending"` | mock returns `kycStatus=pending` | app + backenders |
| `jeeb.seam.kyc_status` | `"approved"` | mock returns `kycStatus=approved` | app + backenders |
| `jeeb.seam.kyc_status` | `"rejected"` | mock returns `kycStatus=rejected` | app + backenders |

**Implementation note:** add `kycStatus` to the `jeeb.seam.*` whitelist in `MainActivity.kt`; add a typed `KycStatusSeed` enum to `DevSeamConfig`; add a `POST /__mock/seed/kyc { kycStatus, userId }` endpoint to the mock backend (or override the `GET /user-management/users/:userId/kyc` fixture). `SessionSeamBootstrap.seed()` writes the kycStatus to whatever store the `KycStatusCubit`/`KycStatusRepository` reads (once that store exists, per U1 mock-fix).

### 3.2 New `jeeb.seam.wallet_state` key (mock only)

| key | value | what it seeds | owner |
|---|---|---|---|
| `jeeb.seam.wallet_state` | `"sufficient"` | mock returns `availableBalance > reserve_needed`, `affordabilityState="enough"` from `GET /wallet-service/v1/jeeb/wallet` (W1m) | backenders |
| `jeeb.seam.wallet_state` | `"insufficient"` | mock returns `availableBalance < reserve_needed`, `affordabilityState="empty"` or `"low"`; `POST /offer-service/v1/offers` returns 402 `{needed, available}` (O1) | backenders |
| `jeeb.seam.wallet_state` | `"empty"` | mock returns `availableBalance=0`, `affordabilityState="all_reserved"` or `"empty"` | backenders |

**Implementation note:** add `wallet_state` to `jeeb.seam.*` whitelist; add `POST /__mock/seed/wallet { state, userId }` endpoint. Reads from W1m endpoint so W1m must be defined first.

### 3.3 New `jeeb.seam.journey` values (mock seed endpoint)

All added to `src/fixtures/journey-seed.ts` `seedJourney()` switch, served via the existing `POST /__mock/seed/journey` endpoint:

| value | what the mock seeds | stable id(s) | route pin | owner |
|---|---|---|---|---|
| `jeeber_kyc_submitted` | user-jeeber-002 kycStatus=pending (KYC just submitted); enables `/jeeber/onboarding/funding` as valid landing | (no delivery/request row) | `/jeeber/onboarding/funding` | backenders |
| `jeeber_feed_with_request` | 1 open request visible to user-jeeber-002 in the delivery feed | `req-feed-001` | none (lands on shell; flow navigates to feed tab) | backenders |
| `jeeber_pending_offers` | 1 offer submitted by user-jeeber-002 with status=submitted (awaiting customer decision) | `pending-offer-jeeber-001` | none (lands on shell; flow navigates via pending tab) | backenders |
| `jeeber_active_delivery` | 1 delivery for user-jeeber-002 with status=InTransit; 1:1 chat exists | `del-jeeber-002-active` | `/jeeber/deliveries/del-jeeber-002-active/active` | backenders |

### 3.4 Mock-fixes W2 depends on (already tracked in `42_GUARDRAILS_MOCK.md`)

| ref | gates | status as of 2026-06-18 |
|---|---|---|
| **K1** | JM-040 (KYC gateway path reconcile) | UNKNOWN — backenders |
| **O1** | JM-045 AC5, JM-046 (offer 402 + reserve/capture/release ledger rows) | UNKNOWN — backenders |
| **W1m** | JM-045 AC5, JM-046, JM-053 (wallet balance/affordability/reserved-now/gift endpoint) | UNKNOWN — backenders |
| **D1m** | JM-051 (proof-photo upload sink — shared with W1 JM-033) | UNKNOWN — backenders |
| **U1** | JM-036, JM-044 (getMe surfaces role kycStatus — W0 mock-fix) | UNKNOWN — backenders |

> ACs that gate on the above are **PARTIAL-parked** until the named fix lands.
> JM-036/044 fully gate on U1 for the live app path; the seam override
> (`jeeb.seam.kyc_status`) lets the Maestro flow bypass the real KYC endpoint,
> so flows can go GREEN without U1 as long as the seam key is wired.
> JM-045 AC5 / JM-046 fully gate on O1 + W1m — no seam bypass is possible for
> the 402 response path (the mock must actually return 402).

---

## 4. Coined identifiers summary (for engineering review)

The following identifiers are **not yet in any existing screen** (coined by QA for W2).
Engineers must place `Semantics(identifier: '<id>')` on the matching widget when
implementing the named JM item. Each id follows the `<screen-id>_<element>` convention
from `30_BACKLOG.md §Identifier convention`.

| coined id | owning JM | widget description |
|---|---|---|
| `delivery_tab_wallet_chip` | JM-036 | Wallet chip in DELIVERY tab header |
| `delivery_tab_bell` | JM-036 | Bell icon in DELIVERY tab header |
| `jeeber_feed_root` | JM-036 | Root semantic node of JeeberFeedTabView |
| `notifications_root` | JM-036 | Root of NotificationsListScreen (also needed by JM-057) |
| `dm_onboarding_address_root` | JM-037 | Root of personal-details wizard step |
| `dm_onboarding_service_area_root` | JM-037/038 | Root of service-area wizard step |
| `service_area_map_pin` | JM-038 | Home-base map pin widget |
| `service_area_select_location` | JM-038 | "Select location" CTA in service-area step |
| `kyc_id_back_upload` | JM-040 | Gov-ID back photo upload widget |
| `kyc_selfie_upload` | JM-040 | Selfie capture widget |
| `funding_explainer` | JM-040/041 | Explainer body on onboarding-funding screen (root) |
| `funding_topup_cta` | JM-041 | "Top up wallet" CTA on funding screen |
| `funding_continue_cta` | JM-041 | "Continue" CTA on funding screen |
| `kyc_status_topup_allowed_note` | JM-042 | "Top-up allowed while pending" note |
| `kyc_status_feed_cta` | JM-042 | "Go to feed" CTA (approved variant) |
| `kyc_status_wallet_cta` | JM-042 | "Wallet" CTA (approved variant) |
| `kyc_status_topup_cta` | JM-042 | "Top up" CTA (pending/approved variant) |
| `kyc_status_view_rejection` | JM-042 | "View rejection" CTA (rejected variant) |
| `kyc_rejected_root` | JM-042/043 | Root of kyc-rejected screen |
| `kyc_rejected_appeal_cta` | JM-043 | "Appeal via support" CTA |
| `kyc_rejected_back_cta` | JM-043 | Back → customer-profile CTA |
| `feed_make_offer_cta` | JM-044/048 | Per-request-row "Make Offer" CTA |
| `offer_kyc_gate` | JM-044 | Root of offer-kyc-gate interstitial |
| `gate_topup_note` | JM-044 | "Top-up still allowed" note on gate |
| `gate_start_kyc_cta` | JM-044 | "Start KYC" CTA on gate |
| `gate_register_link` | JM-044 | "Register first" link on gate |
| `gate_back_cta` | JM-044 | Back CTA on gate |
| `offer_composer_root` | JM-044/045 | Root of OfferSubmissionScreen |
| `offer_composer_fee_line` | JM-045 | "Platform fee: 10%" economics line |
| `offer_composer_net_line` | JM-045 | "You earn (cash)" net-per-offer line |
| `offer_composer_reserve_note` | JM-045 | Reserve/charge/release copy |
| `offer_composer_eta_dropdown` | JM-045 | ETA picker dropdown |
| `offer_composer_eta_option_0` | JM-045 | First ETA option (index 0) |
| `offer_composer_order_ref` | JM-045 | "Your offer · ORD-…" header |
| `offer_composer_price_field` | JM-045 | Price input field |
| `offer_composer_send_cta` | JM-045 | Send / submit offer CTA |
| `insufficient_balance_sheet` | JM-045/046 | Insufficient-balance bottom sheet root |
| `insufficient_balance_needed_amount` | JM-046 | "Needed: X.XX" amount |
| `insufficient_balance_available_amount` | JM-046 | "Available: Y.YY" amount |
| `insufficient_topup_cta` | JM-046 | "Top up" CTA on sheet |
| `insufficient_keep_editing_cta` | JM-046 | "Keep editing" CTA on sheet |
| `jeeber_feed_pending_tab` | JM-047/048 | Pending-response sub-tab chip |
| `pending_offer_0` | JM-047/048 | First pending offer row |
| `pending_offer_0_price` | JM-047 | Price on pending offer row |
| `pending_offer_0_eta` | JM-047 | ETA on pending offer row |
| `pending_offer_awaiting_label` | JM-047 | "Awaiting customer decision" shared label |
| `pending_offer_0_withdraw_cta` | JM-047 | Per-row withdraw CTA |
| `pending_offers_back` | JM-047 | Back from pending offers |
| `mark_delivered_root` | JM-051 | Root of ActiveDeliveryJeeberScreen |
| `mark_delivered_proof_photo` | JM-051 | Proof photo capture widget |
| `mark_delivered_cash_note` | JM-051 | "Customer confirms receipt + pays cash" copy |
| `mark_delivered_cta` | JM-051 | "Mark as delivered" CTA |
| `wallet_available_balance` | JM-053 | Available balance widget |
| `wallet_gift_badge` | JM-053 | Gift/starter-credit badge |
| `wallet_affordability_card` | JM-053 | Affordability state card |
| `wallet_reserved_now` | JM-053 | Live-reserves sum widget |
| `wallet_topup_cta` | JM-053 | "Top up" CTA |
| `wallet_how_fees_work` | JM-053 | "How fees work" link |
| `wallet_how_fees_explainer` | JM-053 | Fees explainer content |
| `wallet_earnings_row` | JM-053 | Earnings row |
| `wallet_see_all_activity` | JM-053 | "See all activity" link |
| `wallet_kyc_pending_banner` | JM-053 | KYC-pending banner |
| `wallet_activity_root` | JM-053 | Root of wallet-activity-list (JM-055) |
| `earnings_total_cash` | JM-053 | Earnings total on dashboard (JM-052) |
| `charge_info_root` | JM-054 | Root of wallet-charge-info screen |
| `charge_info_store_step` | JM-054 | "Go to store" instruction |
| `charge_info_identity_step` | JM-054 | "Give phone/ID" instruction |
| `charge_info_pay_cash_step` | JM-054 | "Pay cash" instruction |
| `charge_info_auto_update_note` | JM-054 | "Balance auto-updates" note |
| `charge_info_fee_note` | JM-054 | "10% fees from pre-charged balance" note |
| `charge_info_back_cta` | JM-054 | Back → wallet-hub CTA |

---

## 5. Wave EXIT checklist

All items below must be true before W2/W2.5 EXITs (per `50_EXECUTION_PLAN.md §WAVE 2`):

- [ ] All W2 JM items SIGNED (or PARTIAL-parked with documented gate: O1 / W1m / K1 / D1m)
- [ ] `--include-tags w2` Maestro suite GREEN on `jeeb_test`
- [ ] `--include-tags w2_5` (JM-053/054) suite GREEN
- [ ] `--include-tags w0` and `--include-tags w1` regression suites still GREEN
- [ ] `flutter analyze` clean on wave branch
- [ ] `flutter test` all green on wave branch
- [ ] W1m, K1, O1, D1m, U1 closed — or dependent ACs explicitly PARTIAL-parked in `signoffs/*.md`
- [ ] New seam keys `jeeb.seam.kyc_status`, `jeeb.seam.wallet_state` whitelisted in `MainActivity.kt`
- [ ] New `jeeb.seam.journey` values (jeeber_kyc_submitted, jeeber_feed_with_request,
      jeeber_pending_offers, jeeber_active_delivery) implemented in `journey-seed.ts` and tested
- [ ] All 50 coined identifiers placed as `Semantics(identifier:)` on the implementing screens
- [ ] No existing W0/W1 flow files modified
