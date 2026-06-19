# 40 — Architecture Guardrails (jeeb-mobile)

> **Phase 2 deliverable (Senior Principal Engineer / Architecture Guardrail).** The canonical,
> copy-pasteable way to add a screen + feature to `jeeb-mobile`. Derived from the **real** code:
> `lib/core/router/app_router.dart`, `lib/core/di/injection_container.dart`,
> `lib/features/shell/shell_screen.dart`, `lib/main.dart`, `lib/app/app.dart`,
> `lib/core/network/mock_gateway_client.dart`, and the complete `lib/features/client_offers/`
> feature (data/domain/presentation + cubit/state). Companion to `00_CTO_BRIEF.md` (§6
> non-negotiables, §7 isolation), `01_CTO_DECISIONS.md`, `21_NAV_PLAN.md`, `30_BACKLOG.md`.
>
> **This is binding.** A diff that violates a DO-NOT below is rejected at review (CTO brief §10).
> If a rule blocks you and no CTO-D covers the gap, apply **CTO-D R-F** (most blueprint-consistent,
> least-surprising option; record the assumption inline) — never stall, never invent a product rule.

---

## 0. TL;DR — the 12 rules an engineer must internalize

1. **One feature = one folder** under `lib/features/<feature>/` with **`data/ domain/ presentation/`**
   (+ `application/` for the cubit/state). Clean Architecture, dependencies point inward.
2. **State = flutter_bloc `Cubit`** (not `Bloc`). State classes extend **`Equatable`**, are immutable,
   and expose **`copyWith`** with explicit `clear<X>` flags for nullable fields.
3. **Every async surface is a 4-state machine:** `initial/loading` → `loaded` | `failed` (+ `empty`
   as a loaded sub-state). Render with OMDS `OmdsLoadingState` / `OmdsErrorState` / `OmdsEmptyState`.
4. **Domain talks to an `abstract class <X>Repository`;** data implements `Dio<X>Repository`; the
   repo throws a **typed `<X>RepositoryException(<X>Failure)`** — the cubit maps failures to copy.
   The UI never sees a `DioException`.
5. **DI = GetIt (`sl`).** Register the **interface**, construct the **Dio impl**, in
   `configureDependencies()`. Screens resolve via `sl<T>()` with a **constructor override for tests**.
6. **Routing = GoRouter, named routes.** A `goNamed`/`go`/`push` target MUST be a registered route
   (CTO brief §6.7). Routes live **only** in `app_router.dart`. Payloads via `extra` (typed,
   defensively cast) or path/query params. Gates go in the central `redirect`.
7. **`app_router.dart`, `injection_container.dart`, `shell_screen.dart` (+ `tabs/`), and the
   l10n ARB files are SHARED FILES.** Only the **per-wave integrator** edits them, **batched first**
   (CTO brief §7; `21_NAV_PLAN.md §D`). You request an edge/route via the protocol in §9.
8. **OMDS only** (`package:omds/omds.dart`). No ad-hoc colors/spacing/typography. Use `Spacing.*`,
   `Sizes.*`, `OmdsBorderRadius.*`, `Theme.of(context).colorScheme/textTheme`. Missing component →
   build a local widget per `22_DESIGN_NOTES.md` (CTO-D R-D), do not block.
9. **i18n always.** Every user-facing string comes from `AppLocalizations.of(context)` (ARB). No
   hardcoded English/Arabic in widgets. RTL is automatic; use `EdgeInsetsDirectional`.
10. **Maestro-testable.** Every interactive/asserted widget carries a stable
    **`Semantics(identifier: '<screen-id>_<element>')`** (CTO brief §5/§6.6). Assert on identifiers,
    never visible text.
11. **Mock only, through Dio.** Paths are the **gateway contract** (`/v1/...`); the
    `MockGatewayClient` interceptor rewrites them to the `:4010` service prefix. Never hardcode a
    `:4010` URL or a service prefix in a repository.
12. **Don't break green.** `flutter analyze` clean + `flutter test` green + the item's Maestro flow
    passes before handoff (CTO brief §10).

---

## 1. Feature-folder layout (canonical)

Every feature is self-contained. The reference is `lib/features/client_offers/`:

```
lib/features/<feature>/
├── application/                     # flutter_bloc layer (cubit + state)
│   ├── <feature>_cubit.dart         # Cubit<<Feature>State>; owns lifecycle, polling, errors
│   └── <feature>_state.dart         # Equatable state + status enum + failure-driven copy
├── domain/                          # PURE Dart — no Flutter, no Dio, no GetIt imports
│   ├── <entity>.dart                # immutable entities/value objects
│   ├── <feature>_repository.dart    # abstract class + <Feature>Failure enum + <Feature>RepositoryException
│   └── <feature>_service.dart       # (optional) pure domain logic that isn't a repo call
├── data/
│   ├── dio_<feature>_repository.dart # implements the domain repository over Dio; maps DioException→Failure
│   └── fake_<feature>_repository.dart# (optional) in-memory test seam; NEVER the DI default
└── presentation/
    ├── <feature>_screen.dart         # StatelessWidget; owns BlocProvider; renders state machine
    └── widgets/                      # screen-private widgets (cards, sheets, banners)
```

**Layer rules (Clean Architecture — dependencies point inward):**

- `domain/` imports **nothing** from `data/`, `presentation/`, Flutter, Dio, or GetIt. Pure Dart +
  `equatable`. This is the contract everyone else depends on.
- `application/` (the cubit) imports **`domain/` only**. It receives a `<Feature>Repository`
  (the abstract type) by constructor injection. It does not import `data/` and does not touch `sl`.
- `data/` imports `domain/` + `dio`. It implements the repository and is the **only** place a
  `DioException` is caught and translated. It never imports `presentation/` or `application/`.
- `presentation/` imports `application/` + `domain/` + `omds` + `l10n`. The screen widget is the
  **only** layer allowed to touch `sl` (DI) and `context` (navigation). Widgets under `widgets/`
  are dumb: data in via constructor, events out via callbacks.

> **Note on existing naming drift:** older features use `application/` for the cubit; a few use
> `presentation/` only. **New features MUST use `application/` for the cubit/state.** The folder
> `lib/features/offers/` (offer *submission*) and `lib/features/client_offers/` (offer *review*)
> are distinct features — match the gap map / nav plan target file when extending, don't merge them.

---

## 2. State convention (flutter_bloc Cubit + state)

**Use `Cubit`, not `Bloc`.** Events are method calls on the cubit. The reference is
`client_offers_cubit.dart` + `client_offers_state.dart`.

### 2.1 The state class
- Extends **`Equatable`**, is **immutable** (`final` fields, `const` constructor).
- Carries a **`status` enum** with the canonical lifecycle:
  `initial`, `loading`, `loaded`, `failed`. (Add a domain sub-status enum for in-row actions, e.g.
  `AcceptStatus { idle, inFlight, succeeded }` — keep it separate from the screen `status`.)
- Carries a **typed `<Feature>Failure?` error** (never a raw exception/string).
- Exposes **`copyWith`** that, for each **nullable** field, takes a paired `bool clear<X>` flag so a
  caller can explicitly null it (you cannot null via `copyWith` otherwise). See `clearError`,
  `clearAcceptingOfferId` in the reference.
- Derived getters (e.g. `hasOffers`, `windowRemaining`) live on the state, computed from fields.
- Lists held in state should be `List.unmodifiable(...)` when the cubit owns ordering.

### 2.2 The cubit
- Constructor takes the **abstract repository** + identifiers + **injectable seams** (`now`,
  `pollTicks`, `clockTicks`) so tests drive time deterministically. Never `DateTime.now()` inline
  where a test needs to control it — inject `DateTime Function() now`.
- A single **`load()`** cold-entry that guards re-entry (`if (state.status != initial) return;`),
  emits `loading`, awaits the repo, emits `loaded`/`failed`. Re-invokable safely on remount.
- A **`refresh()`** that does NOT flip `status` to `loading` (UI shows pull indicator, not a
  full-screen spinner).
- Wrap every repo call in `try { } on <Feature>RepositoryException catch (e) { emit(...e.failure) }
  catch (_) { emit(...Failure.unknown) }`. **Background polls swallow transient errors** (don't
  flash a banner every tick) — only foreground actions (load/refresh/accept) surface them.
- One-shot error acknowledgement (`acknowledgeError()` → `copyWith(clearError: true)`) so a
  snackbar/banner replay doesn't loop.
- **`close()`** cancels every `StreamSubscription`/timer. Leaking a timer fails the test binding.

---

## 3. Error / empty / loading state conventions

Render the state machine with OMDS feedback widgets (real, in
`../omds-flutter/omds_library/lib/src/feedback/`):

| state | widget | rule |
|---|---|---|
| `initial` / `loading` | `OmdsLoadingState()` | full-screen on cold load only |
| `failed` | `OmdsErrorState(message:, retryLabel:, onRetry:)` | message comes from a **`_errorCopy(l10n, failure)`** switch over the typed `<Feature>Failure`; `onRetry` calls `cubit.refresh()` |
| `loaded` + empty list | `OmdsEmptyState(icon:, title:, subtitle:)` | empty is a **sub-state of loaded**, not a 5th status |
| transient mid-screen error (e.g. accept failed) | inline dismissible banner | dismiss → `cubit.acknowledgeError()` |

Copy-paste skeleton (from `client_offers_screen.dart`):

```dart
body: BlocConsumer<FooCubit, FooState>(
  listenWhen: (p, n) => p.actionStatus != n.actionStatus &&
      n.actionStatus == ActionStatus.succeeded,
  listener: (context, state) { /* fire one-shot side effects (nav, toast) here */ },
  builder: (context, state) {
    switch (state.status) {
      case FooStatus.initial:
      case FooStatus.loading:
        return const OmdsLoadingState();
      case FooStatus.failed:
        return OmdsErrorState(
          message: _errorCopy(l10n, state.error),
          retryLabel: l10n.commonRetry,
          onRetry: () => context.read<FooCubit>().refresh(),
        );
      case FooStatus.loaded:
        if (!state.hasItems) {
          return OmdsEmptyState(
            icon: Icons.inbox_outlined,
            title: l10n.fooEmptyTitle,
            subtitle: l10n.fooEmptyBody,
          );
        }
        return _LoadedBody(state: state);
    }
  },
),
```

> **Navigation belongs in the `listener`, never the `builder`.** A `context.go` inside `builder`
> fires on every rebuild. Side effects (nav, snackbar) go in `BlocListener`/`BlocConsumer.listener`
> gated by `listenWhen`.

---

## 4. Data sources (Dio) + the mock gateway protocol

- A data source implements the domain repository and holds a `final Dio _dio` (constructor-injected
  from `sl<Dio>()`). It is registered as a **`const`/lazy singleton** in DI.
- **Speak the gateway contract path** (`/v1/offers/:id/accept`, `/v1/requests/:id/offers`,
  `/user-management/users/me`, …). `MockGatewayClient`'s `_PathRewriteInterceptor` rewrites the
  `/v1/...` prefix to the `:4010` service prefix (`/offer-service/v1/...`). **Do NOT** hardcode a
  service prefix or a host in a repository — that is the interceptor's job (`mock_gateway_client.dart`).
- **Catch `DioException` only in `data/`.** Translate to a typed failure via a `Never _rethrow(...)`
  helper: connection/timeout → `Failure.network`; map known HTTP codes (`402`, `409`, `410`, …) to
  domain failures (see `dio_offers_repository.dart` `_rethrowAccept`). Everything else →
  `Failure.unknown`.
- **Parse defensively.** Accept `List` or `{ items: [...] }`, tolerate snake_case and camelCase
  (`deliveryId ?? delivery_id`), null-coalesce every field, normalise `''`→`null`. A malformed body
  must degrade gracefully (hide a CTA), never crash on a cast.
- **Mock gap?** If the endpoint/field doesn't exist on `:4010` yet, it's **backend work** (CTO-D2,
  CTO-D R-A) — flag it (B/W/O/K/S/R/U/T refs in `20_GAP_MAP.md`), build the UI shell + states, and
  let the data-bound AC validate once the mock lands. Do not invent a wire format that will diverge.

---

## 5. GoRouter route-registration pattern

All routes live in `app_router.dart`'s `routes: [...]`. **Named routes** (`name:`) are the contract
callers use (`context.goNamed('wallet')`); paths can change without touching call sites.

### 5.1 Plain screen
```dart
GoRoute(
  path: '/wallet/charge-info',
  name: 'wallet-charge-info',
  builder: (context, state) => const WalletChargeInfoScreen(),
),
```

### 5.2 Path + query params
```dart
GoRoute(
  path: '/orders/:id/feedback',
  name: 'feedback',
  builder: (context, state) {
    final deliveryId = state.pathParameters['id'] ?? '';
    final isClient = state.uri.queryParameters['mode'] != 'jeeber';
    return RatingScreen(deliveryId: deliveryId, isClient: isClient);
  },
),
```

### 5.3 Typed `extra` payload (defensively cast — a cold deep-link has no extra)
```dart
GoRoute(
  path: '/request-summary',
  name: 'request-summary',
  builder: (context, state) {
    final extra = state.extra;
    if (extra is! RequestDraft) return const RequestSummaryUnavailableScreen();
    return BlocProvider<RequestSummaryCubit>(
      create: (_) => RequestSummaryCubit(sl<RequestSubmissionService>())..setDraft(extra),
      child: const RequestSummaryScreen(),
    );
  },
),
```
**Rule:** a route that requires `extra` MUST render a graceful unavailable screen when `extra` is
absent/wrong-typed (push notification / cold deep-link / dev-seam capture all land without it).

### 5.4 Cubit provisioning at the route
The route is where DI meets the widget tree. Two valid patterns:
- **Screen self-provides** (preferred for simple cases): the `Screen` is a `StatelessWidget` whose
  `build` wraps a `BlocProvider` and resolves `sl<Repository>()` itself (see `ClientOffersScreen`),
  with an optional constructor `repository`/`cubitFactory` override for tests.
- **Route provides** (when the cubit needs path params): wrap the screen in a `BlocProvider` in the
  route builder, resolving deps from `sl<T>()` (see `/orders/:id/tracking`, `/orders/:id/escalate`).

### 5.5 Redirect gates (auth / biometric / account-status)
Gates are **centralized** in the single top-level `redirect:` closure, evaluated in order:
1. dev-seam pins (debug only),
2. `_firstRunRedirect` (onboarding + session/JWT, FR-P0-1/3),
3. biometric lock gate (`/lock`),
4. **(W4) account-status gate** (JM-066, D5): when `getMe.status ∈ {suspended,locked}`, force
   `/account-status` and block all tabs.

Redirects re-run via `refreshListenable` (`_MergedRefreshListenable` over the onboarding, biometric,
and session cubits). **A new gate must be added to the redirect by the integrator, not bolted onto a
screen** — screens must not police their own reachability.

> **Splash is not a `GoRoute`** — it is bootstrap + the `_firstRunRedirect` branch (JM-006). Shell
> **tabs** (`customer-orders-home`, `delivery-requests`, `earnings`, etc.) are **not routes** — they
> are `ShellScreen` bodies reached via the bottom nav + `RoleCubit` index (`21_NAV_PLAN.md §A`).
> Sheets/dialogs (`offer-accept-confirm`, `cancel-request-confirm`, `offer-insufficient-balance`)
> are **not routes** — they are `showModalBottomSheet`/dialogs.

---

## 6. GetIt DI registration

Everything is registered in `configureDependencies()` in `injection_container.dart`. `sl` is the
global `GetIt.instance`.

- Register the **interface**, construct the **Dio impl**:
  ```dart
  sl.registerLazySingleton<WalletRepository>(() => DioWalletRepository(sl<Dio>()));
  ```
- **`registerLazySingleton`** for stateless repos/services (default). **`registerFactory`** only
  when each consumer needs a fresh instance owning a resource (e.g. `VoiceRecorder` holds the mic;
  `ChatGateway` is conversation-scoped). **`registerSingleton`** only for the eager
  `SharedPreferences`/`CrashReporter` handed in at bootstrap.
- Pure/stateless domain services that the router resolves are `const` lazy singletons
  (`OfferSubmissionService`, `ProhibitedItemReportService`) — they swap to a Dio-backed impl later
  without touching the route.
- **Fakes are NEVER registered in DI.** A `Fake<X>Repository` is a constructor-injected **test seam**
  only (CTO brief §6.4; see the `DioOffersRepository` vs `FakeOffersRepository` note in DI).
- **Tag your registration** with the owning JM id in a comment (matches existing `T-MOB-###` style),
  so the integrator can audit the wave's DI batch.

---

## 7. Naming conventions

| thing | convention | example |
|---|---|---|
| feature folder | `snake_case`, singular domain noun | `client_offers/`, `wallet/` |
| screen widget | `<Name>Screen` (or `<Name>Sheet` for a sheet) | `WalletHubScreen`, `OfferAcceptSheet` |
| screen file | `<name>_screen.dart` | `wallet_hub_screen.dart` |
| cubit / state | `<Feature>Cubit` / `<Feature>State` | `WalletHubCubit` / `WalletHubState` |
| status enum | `<Feature>Status` (or screen-scoped) | `OffersScreenStatus` |
| repository (abstract) | `<Feature>Repository` in `domain/` | `OffersRepository` |
| repository (impl) | `Dio<Feature>Repository` in `data/` | `DioOffersRepository` |
| failure enum / exception | `<Feature>Failure` / `<Feature>RepositoryException` | `OffersFailure` |
| route name | `kebab-case`, == blueprint id where possible | `'wallet-charge-info'` |
| route path | `kebab-case`, REST-ish, nest under parent | `/wallet/charge-info`, `/recover/verify` |
| Semantics identifier | `<screen-id>_<element>` (snake) | `wallet_hub_topup_cta`, `login_email_field` |
| l10n key | `<feature><Element>` camelCase | `walletAvailableBalance`, `offersRetryAction` |

`<screen-id>` is the **blueprint id** (`21_NAV_PLAN.md §A`). Identifier element suffixes follow
`30_BACKLOG.md §"Identifier convention"`: fields `_field`, CTAs `_cta`, links `_link`, toggles
`_toggle`, rows `_row`, tabs `shell_tab_<id>`, sheet elements `<screen-id>_sheet_<element>`.

---

## 8. Maestro / Semantics convention (standing guardrail — CTO brief §5/§6.6)

- Semantics export is forced on at boot in `main.dart`
  (`SemanticsBinding.instance.ensureSemantics()`) — **do not remove it.**
- Every widget a Maestro flow taps or asserts carries
  **`Semantics(identifier: '<screen-id>_<element>')`**. Identifiers are locale-independent; the
  matching Maestro flow under `.maestro/flows/` keys on the **identifier**, never visible text
  (i18n-safe).
  ```dart
  Semantics(
    identifier: 'wallet_hub_topup_cta',
    button: true,
    child: OmdsPrimaryButton(label: l10n.walletTopUp, onPressed: _onTopUp),
  );
  ```
- **`identifier:` is required; `label:` alone is not sufficient.** Some legacy widgets (e.g.
  `offer_card.dart`, `offer_submission_screen.dart`) currently pass only `Semantics(label:)` —
  that predates this guardrail. New/edited widgets MUST set `identifier:`; when you touch such a
  widget for a JM item, add the `identifier:` as part of the diff.
- A change is **not done** until its Maestro flow passes on the emulator against the mock
  (CTO brief §10).

---

## 9. SHARED-FILE protocol (CTO brief §7; `21_NAV_PLAN.md §D`)

These files are edited by **exactly one per-wave integrator**, in a **batch landed first**, before
per-screen engineers wire their call sites. A per-screen engineer **never** edits them directly.

| shared file | what the integrator batches | who else may touch |
|---|---|---|
| `lib/core/router/app_router.dart` | all route `ADD`/`REPLACE` for the wave (`21_NAV_PLAN.md §B`) + any redirect-gate logic | nobody else |
| `lib/core/di/injection_container.dart` | new repo/service registrations the wave needs | nobody else |
| `lib/features/shell/shell_screen.dart` + `lib/features/shell/tabs/*` | tab-body swaps (e.g. real `CustomerProfileScreen` into Profile tab; KYC gate into DELIVERY tab) | nobody else |
| `lib/l10n/app_en.arb` + `lib/l10n/app_ar.arb` | new keys for the wave (both locales, with `@key` descriptions) | nobody else |
| `jeeb-mock-backend` mounts | backenders only (CTO-D2/R-A) | backenders |

### Wave order within a wave (must hold)
1. **Integrator** lands the batched router routes + redirect gates + DI registrations + ARB keys.
2. **Per-screen engineers** build their `lib/features/<feature>/` screen and wire their **own**
   call-site edges (the `context.goNamed(...)` / `context.push(...)` in their feature files — these
   touch feature files, not the router).
3. **Integrator** lands tab-body swaps (`shell_screen.dart` / `tabs/*`).

### How to request a route or edge be added
You do **not** open `app_router.dart`. Instead, in your JM item's branch/handoff note (and against
the row already enumerated in `21_NAV_PLAN.md §B/§C`), state to the wave integrator:

```
ROUTE REQUEST — JM-0NN
  name:    <kebab-route-name>            # e.g. wallet-charge-info
  path:    /<path>                       # e.g. /wallet/charge-info
  screen:  <ScreenWidget> (lib/features/<feature>/presentation/<file>.dart)
  payload: extra=<Type> | pathParam :id | query ?mode=...   (or "none")
  cubit:   self-provided | route-provided via sl<XRepository>()
  deps DI: <new sl<...> registrations needed>   (or "none")
  gate:    <redirect rule, if any>       (e.g. block when getMe.status==suspended)
  cites:   21_NAV_PLAN.md §B batch W<n>, JM-0NN, CTO-D#, D##
```

```
EDGE REQUEST — JM-0NN
  from:    <source screen-id / your feature>
  to:      <target route name>           # MUST already be registered
  control: <semantics identifier of the control>  # e.g. wallet_hub_topup_cta
  call:    context.goNamed('<name>', extra: ...) | context.push('/...')
  cites:   21_NAV_PLAN.md §C, JM-0NN
```

If the target route isn't registered yet, the edge is **blocked on the target's JM** — note it; the
integrator sequences the route batch first. **Navigation honesty (CTO brief §6.7): never wire a
call site to an unregistered name.**

---

## 10. End-to-end skeleton — a new feature + route (copy-paste)

Worked example: **`wallet-charge-info`** (JM-054, `21_NAV_PLAN.md §B batch W3`). A static screen is
used so the skeleton stays minimal; a data-backed feature adds the `data/` + cubit exactly as §1–§4.
The static-vs-data variant is annotated.

### 10.1 `domain/` — repository + failure (omit for a static screen; shown for the data variant)
`lib/features/wallet/domain/wallet_repository.dart`
```dart
// PURE Dart. No Flutter / Dio / GetIt imports.
class WalletBalance {
  const WalletBalance({required this.available, required this.reservedNow});
  final double available;
  final double reservedNow;
}

enum WalletFailure { network, unknown }

class WalletRepositoryException implements Exception {
  const WalletRepositoryException(this.failure, [this.message]);
  final WalletFailure failure;
  final String? message;
}

abstract class WalletRepository {
  Future<WalletBalance> fetchBalance(); // W1m — backend-owned (CTO-D2)
}
```

### 10.2 `data/` — Dio impl
`lib/features/wallet/data/dio_wallet_repository.dart`
```dart
import 'package:dio/dio.dart';
import '../domain/wallet_repository.dart';

class DioWalletRepository implements WalletRepository {
  const DioWalletRepository(this._dio);
  final Dio _dio;

  @override
  Future<WalletBalance> fetchBalance() async {
    try {
      // Gateway-contract path; MockGatewayClient rewrites the prefix to :4010.
      final res = await _dio.get<Map<String, dynamic>>('/v1/jeeb/wallet');
      final d = res.data ?? const {};
      return WalletBalance(
        available: (d['availableBalance'] as num?)?.toDouble() ?? 0.0,
        reservedNow: (d['reservedNow'] as num?)?.toDouble() ?? 0.0,
      );
    } on DioException catch (e) {
      throw WalletRepositoryException(_map(e));
    }
  }

  WalletFailure _map(DioException e) =>
      (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout)
          ? WalletFailure.network
          : WalletFailure.unknown;
}
```

### 10.3 `application/` — cubit + state (data variant)
`lib/features/wallet/application/wallet_hub_state.dart`
```dart
import 'package:equatable/equatable.dart';
import '../domain/wallet_repository.dart';

enum WalletHubStatus { initial, loading, loaded, failed }

class WalletHubState extends Equatable {
  const WalletHubState({
    this.status = WalletHubStatus.initial,
    this.balance,
    this.error,
  });

  final WalletHubStatus status;
  final WalletBalance? balance;
  final WalletFailure? error;

  WalletHubState copyWith({
    WalletHubStatus? status,
    WalletBalance? balance,
    WalletFailure? error,
    bool clearError = false,
  }) =>
      WalletHubState(
        status: status ?? this.status,
        balance: balance ?? this.balance,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, balance, error];
}
```
`lib/features/wallet/application/wallet_hub_cubit.dart`
```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/wallet_repository.dart';
import 'wallet_hub_state.dart';

class WalletHubCubit extends Cubit<WalletHubState> {
  WalletHubCubit({required WalletRepository repository})
      : _repository = repository,
        super(const WalletHubState());
  final WalletRepository _repository;

  Future<void> load() async {
    if (state.status != WalletHubStatus.initial) return;
    emit(state.copyWith(status: WalletHubStatus.loading, clearError: true));
    try {
      final balance = await _repository.fetchBalance();
      emit(state.copyWith(status: WalletHubStatus.loaded, balance: balance));
    } on WalletRepositoryException catch (e) {
      emit(state.copyWith(status: WalletHubStatus.failed, error: e.failure));
    } catch (_) {
      emit(state.copyWith(status: WalletHubStatus.failed, error: WalletFailure.unknown));
    }
  }

  Future<void> refresh() async {
    try {
      emit(state.copyWith(balance: await _repository.fetchBalance(), clearError: true));
    } on WalletRepositoryException catch (e) {
      emit(state.copyWith(error: e.failure));
    } catch (_) {
      emit(state.copyWith(error: WalletFailure.unknown));
    }
  }
}
```

### 10.4 `presentation/` — screen (static variant of JM-054; OMDS + l10n + Semantics)
`lib/features/wallet/presentation/wallet_charge_info_screen.dart`
```dart
import 'package:flutter/material.dart';
import 'package:omds/omds.dart';
import '../../../l10n/app_localizations.dart';

/// wallet-charge-info (JM-054). Static, no-payment instructional screen
/// (D92/D93): charge at an authorized store, give phone/ID, pay cash, balance
/// auto-updates, 10% fees come from the pre-charged balance. NO card/amount.
class WalletChargeInfoScreen extends StatelessWidget {
  const WalletChargeInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: OMDSAppBar(title: l10n.walletChargeInfoTitle, showBackButton: true),
      body: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.medium, Spacing.medium, Spacing.medium, Spacing.xLarge),
        children: [
          Text(l10n.walletChargeInfoBody, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: Spacing.large),
          Semantics(
            identifier: 'wallet_charge_info_back_cta',
            button: true,
            child: OmdsPrimaryButton(
              label: l10n.commonBack,
              // EDGE: wallet-charge-info → wallet-hub (21_NAV_PLAN.md §C, JM-054).
              onPressed: () => context.canPop() ? context.pop() : context.goNamed('wallet'),
            ),
          ),
        ],
      ),
    );
  }
}
```
> Data variant: wrap the body in `BlocProvider(create: (_) => WalletHubCubit(repository:
> sl<WalletRepository>())..load(), child: _WalletHubView())` and render the §3 state-machine switch.

### 10.5 l10n — ARB keys (integrator batches into BOTH locales)
`lib/l10n/app_en.arb` (+ matching `app_ar.arb`)
```json
"walletChargeInfoTitle": "Add funds",
"@walletChargeInfoTitle": { "description": "wallet-charge-info app bar title" },
"walletChargeInfoBody": "Charge your wallet at any authorized store. Give your phone number or ID, pay cash, and your balance updates automatically. The 10% platform fee is taken from your pre-charged balance — there is no in-app payment.",
"@walletChargeInfoBody": { "description": "wallet-charge-info instructional body (D92/D93)" }
```

### 10.6 DI (integrator batches into `injection_container.dart` — data variant only)
```dart
// JM-053/054: wallet balance/affordability (W1m — backend-owned, CTO-D2).
sl.registerLazySingleton<WalletRepository>(() => DioWalletRepository(sl<Dio>()));
```

### 10.7 Route (integrator batches into `app_router.dart`, §5.1)
```dart
GoRoute(
  path: '/wallet/charge-info',
  name: 'wallet-charge-info',
  builder: (context, state) => const WalletChargeInfoScreen(),
),
```

### 10.8 Wire the inbound edges (per-screen engineers of the SOURCE screens)
The owners of `wallet-hub` (JM-053), `onboarding-funding` (JM-041),
`offer-insufficient-balance` (JM-046), `kyc-pending-status` (JM-042) add, in their feature files:
```dart
context.goNamed('wallet-charge-info'); // on their *_topup_cta / funding_topup_cta etc.
```

### 10.9 Maestro flow (QA — Sonnet, CTO-D R-E) keyed by identifier
`.maestro/flows/jm054_wallet_charge_info.yaml`
```yaml
appId: ${APP_ID}
---
- launchApp
# (navigate to wallet-hub, then tap wallet_hub_topup_cta — omitted)
- assertVisible: { id: "wallet_charge_info_back_cta" }
- tapOn: { id: "wallet_charge_info_back_cta" }
- assertVisible: { id: "wallet_hub_topup_cta" }   # back on wallet-hub
```

### 10.10 Definition of done for this item (CTO brief §10)
Matches blueprint `wallet-charge-info` + D92/D93 · OMDS only · inbound edges wired both ways ·
no network (static) / wired to `:4010` (data variant) · `Semantics(identifier:)` present ·
Maestro flow green on emulator · `flutter analyze` clean + `flutter test` green · reviewer approved ·
PO signed off against JM-054 AC.

---

## 11. DO

- DO put each feature in `lib/features/<feature>/{data,domain,presentation,application}/` and keep
  `domain/` pure Dart.
- DO use a `Cubit` + `Equatable` immutable state with a `status` enum and `copyWith(... clear<X>)`.
- DO render the 4-state machine with `OmdsLoadingState`/`OmdsErrorState`/`OmdsEmptyState`; treat
  empty as a sub-state of loaded.
- DO define an abstract `<Feature>Repository` + typed `<Feature>Failure`/exception in `domain/`;
  implement `Dio<Feature>Repository` in `data/`; map `DioException` to failures there and nowhere else.
- DO register the interface (impl = Dio) in `injection_container.dart`, tagged with the JM id, and
  expose a constructor test seam on screens (`repository`/`cubitFactory`).
- DO speak gateway-contract paths (`/v1/...`) and let `MockGatewayClient` rewrite them.
- DO use **named** GoRoutes; defensively type-check `extra` and render an unavailable screen on miss.
- DO put navigation side-effects in a `BlocListener`/`listener` (gated by `listenWhen`), never `builder`.
- DO put every gate in the central `redirect` (auth, biometric, account-status), wired via
  `refreshListenable`.
- DO localize every string (ARB, both locales) and use `EdgeInsetsDirectional` for RTL safety.
- DO add `Semantics(identifier: '<screen-id>_<element>')` to every interactive/asserted widget and a
  matching Maestro flow keyed by identifier.
- DO request routes/edges/DI/ARB/tab-swaps from the per-wave integrator via the §9 protocol.
- DO cite blueprint ids, `JM-###`, `CTO-D#`, and `D##` in code comments for non-obvious decisions.
- DO cancel every subscription/timer in `Cubit.close()`.
- DO keep `flutter analyze` clean and `flutter test` green before handoff.

## 12. DO-NOT

- DO NOT edit `app_router.dart`, `injection_container.dart`, `shell_screen.dart`/`tabs/*`, or the
  ARB files unless you are the wave's designated integrator. (CTO brief §7.) Request via §9.
- DO NOT `goNamed`/`push` a route name that isn't registered (navigation dishonesty, CTO brief §6.7).
- DO NOT import `data/` from `application/` or `presentation/`; DO NOT import Flutter/Dio/GetIt into
  `domain/`. DO NOT let a widget under `widgets/` reach into `sl` or `context.go` — pass callbacks.
- DO NOT register a `Fake*` repository in DI — it is a constructor test seam only.
- DO NOT hardcode a `:4010` host or a service prefix (`/offer-service/...`) in a repository — use the
  `/v1/...` contract path and the interceptor.
- DO NOT catch `DioException` outside `data/`, and DO NOT surface raw exceptions/strings to the UI —
  map to a typed `<Feature>Failure`.
- DO NOT call `context.go` from inside a `builder` (fires every rebuild) — use the `listener`.
- DO NOT hardcode user-facing strings or use `EdgeInsets.only(left/right)` (breaks RTL).
- DO NOT use raw colors/spacing/`TextStyle()` — use OMDS tokens (`Spacing.*`, `Sizes.*`,
  `OmdsBorderRadius.*`, `Theme.of(context).colorScheme/textTheme`).
- DO NOT assert on visible text in a Maestro flow (i18n-breaks) — assert on `Semantics(identifier:)`.
- DO NOT add a fifth `status` value for "empty" — empty is `loaded` + an empty collection.
- DO NOT police a screen's reachability inside the screen — gates belong in the central `redirect`.
- DO NOT remove `SemanticsBinding.instance.ensureSemantics()` from `main.dart` (kills Maestro).
- DO NOT invent a product rule or a wire format. Spec silent + no CTO-D → apply CTO-D R-F, record the
  assumption inline, proceed. Mock missing → flag it as backend work (CTO-D2), build the shell.
- DO NOT reuse a near-miss screen against the gap map's explicit "do NOT reuse" notes (e.g.
  `cancellation_screen.dart` for `cancel-request-confirm`, `dispute_screen.dart` for
  `dispute-open-evidence` — `20_GAP_MAP.md` reconciliation notes 7–8).
- DO NOT merge `lib/features/offers/` (offer submission) with `lib/features/client_offers/` (offer
  review) — they are distinct features with distinct targets.
```
