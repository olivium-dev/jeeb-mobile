# Jeeb Mobile — Navigation / CTA Revision

**Date:** 2026-06-13 · **Result:** ✅ Done · **Tests:** 959/959 green · `dart analyze lib` 0 errors/0 warnings

## Problem
Many built screens had no entry point (orphaned routes), one CTA pointed at a non-existent route, and the order-detail hub was a placeholder.

## What was done

| Area | Fix |
|---|---|
| **Order-detail hub** | `delivery_detail_screen` placeholder → real OMDS action hub: Track · Chat · Confirm OTP · Rate · Report issue · Cancel |
| **Broken CTA** | OTP "Report issue" `/orders/:id/dispute` (dead) → `/orders/:id/escalate` |
| **Broken route name** | In-progress "Track" → corrected to `live-tracking` |
| **KYC entry** | Now opens the real `KycWizardScreen` (was a dead stub) |
| **Client create-flow** | Made continuous: Request type → **Continue** → Summary → **Submit** → Requests; voice CTA added on home |
| **Jeeber** | Request-detail placeholder → real screen with **Make offer** + Decline |
| **Earnings/Settings/Profiles** | Earnings → **Settlement**; Settings rows (Edit profile / Become a Jeeber / Addresses / Notifications); chat avatar → counterpart profile |
| **Jeeber active-delivery** (last orphan) | `ChatDetailScreen` made role-aware → jeeber sees **"Start delivery"** CTA on the accepted banner → `/jeeber/deliveries/:id/active`. Fixed the hidden bug that prod `/chat/:id` was hardcoded client-only |
| **OMDS guardrail** | Raw `CircularProgressIndicator` → `OmdsLoadingState` |

## Process
- Ran a multi-agent workflow (audit → plan → implement → verify); stopped its QA agent when it overstepped, then verified directly.
- Pre-existing 12 red tests (otp_handover ×11, kyc ×1) fixed: `pumpAndSettle` (hangs on OMDS spinner) → explicit `pump()`.
- 5 stale assertions re-pointed to intended new behavior (label `DELIVERY→Delivery`, Track→`onTrack`, tier cubit error→AC3 offline-fallback).

## Output
- **959/959 tests pass**, `lib/` compiles clean.
- Navigation graph closed except 2 **intentional** non-wires (open product decision): `/orders/:id/mutual-rate` (hub uses `/feedback`) and `/orders/:id/rate` (frozen push-only stub).
- **Not committed** — changes live in the working tree (commingled with prior finalization debt).
