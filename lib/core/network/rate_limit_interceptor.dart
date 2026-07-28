import 'dart:async';
import 'dart:io' show HttpDate;
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// Global `429 Too Many Requests` back-off gate (F3 — offers polling storm).
///
/// The customer home tab polls `GET /requests`, `GET /deliveries` and
/// `GET /v1/offers` on a cadence. When the gateway's per-subscription rate
/// limiter trips (HTTP 429) the WORST thing the client can do is keep firing
/// scheduled polls into the closed window — that is exactly what turns a single
/// 429 into a sustained storm. This interceptor:
///
///   1. On any `429`, reads the `Retry-After` header (delta-seconds OR an
///      HTTP-date), adds a small random jitter (so a fleet of clients does not
///      re-stampede in lock-step), and opens a suppression window until that
///      instant (capped at [maxBackoff]).
///   2. While the window is open, it SHORT-CIRCUITS further idempotent reads
///      (`GET`) locally — they never touch the network — so the scheduled polls
///      quietly pause instead of hammering a rate-limited gateway. The rejection
///      is a normal [DioException] the callers already treat as a soft failure
///      (the home load degrades, it never crashes).
///   3. It NEVER retries a request on a schedule into a 429 — non-GET writes
///      (accept offer, create request) are always allowed straight through so a
///      user-initiated action is never silently swallowed by the back-off.
///
/// The window is purely time-based and self-heals: once `Retry-After` elapses,
/// reads flow again and the next poll tick resumes normally.
/// b02 P0 addendum — WHY THE WINDOW NEEDED A TRAILING EDGE.
///
/// Everything above is correct and stays. What it did not account for is the
/// world after the polling→push conversion. In the poll era a suppressed read
/// cost nothing: the next tick re-issued it. With the polls DELETED there is no
/// next tick, so a read rejected inside the window — or the 429'd read that
/// opened it — is simply never made again, and the surface keeps painting the
/// pre-429 snapshot with no error, no spinner and no way for the user to tell.
///
/// Measured, same session as the storm: after two 429s at 02:55:00.335Z the
/// device issued ZERO gateway reads for 5 m 49 s, recovering only when an
/// unrelated `delivery` push happened to arrive at 03:00:49Z. Had no push
/// arrived, the screen would have stayed stale indefinitely. That is the
/// concrete sense in which a 429 under push-only is worse than a 429 under
/// polling.
///
/// [RateLimitInterceptor.onBackoffWindowClosed] closes that hole: one callback
/// when the window elapses, wired in the DI container to a full refresh signal.
/// It is capped ([_maxConsecutiveCatchUps]) so a gateway that is genuinely
/// saturated cannot be turned into a slow oscillator by its own recovery path;
/// any 2xx clears the cap.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({
    this.onBackoffWindowClosed,
    DateTime Function()? clock,
    math.Random? random,
    Duration maxBackoff = const Duration(seconds: 120),
    Duration defaultBackoff = const Duration(seconds: 5),
    Duration maxJitter = const Duration(seconds: 1),
  })  : _now = clock ?? DateTime.now,
        _random = random ?? math.Random(),
        _maxBackoff = maxBackoff,
        _defaultBackoff = defaultBackoff,
        _maxJitter = maxJitter;

  final DateTime Function() _now;
  final math.Random _random;
  final Duration _maxBackoff;
  final Duration _defaultBackoff;
  final Duration _maxJitter;

  /// Fired ONCE, after the back-off window elapses, when at least one read was
  /// lost to that window (the 429'd read itself always counts). The DI
  /// container wires this to a full push-refresh signal so every live surface
  /// re-pulls exactly once and the screen catches up, instead of holding the
  /// pre-429 snapshot until some unrelated push happens along.
  ///
  /// `null` in bare tests / the mock client, in which case the interceptor
  /// behaves exactly as it did before this parameter existed.
  final void Function()? onBackoffWindowClosed;

  /// Instant until which idempotent reads are suppressed. `null` when no
  /// back-off window is open.
  DateTime? _suppressedUntil;

  /// Pending trailing-edge catch-up for the currently open window.
  Timer? _catchUpTimer;

  /// Consecutive catch-ups fired without an intervening successful response.
  /// Cleared by any 2xx. See [_maxConsecutiveCatchUps].
  int _consecutiveCatchUps = 0;

  /// Hard stop on the recovery path. Three catch-ups that each earn another
  /// 429 means the gateway is saturated, not that this device is behind; a
  /// fourth would be this client contributing to the saturation it is trying to
  /// recover from. After the cap the surfaces stay stale until a push, a real
  /// user action or a genuine app resume — all of which are user-visible
  /// events, unlike a silent timer.
  static const int _maxConsecutiveCatchUps = 3;

  /// Exposed for diagnostics/tests: is a back-off window currently open?
  bool get isSuppressed {
    final until = _suppressedUntil;
    return until != null && _now().isBefore(until);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final until = _suppressedUntil;
    // Only reads are suppressed. Writes (POST/PUT/PATCH/DELETE) — the money /
    // action path — always go through so a user action is never dropped.
    final isRead = options.method.toUpperCase() == 'GET';
    if (isRead && until != null && _now().isBefore(until)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'Suppressed by 429 back-off until '
              '${until.toIso8601String()} (Retry-After honored).',
        ),
        // callFollowingErrorInterceptor: false — this is a synthetic local
        // rejection, not a server error; do not re-enter onError handlers.
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // BUG-C: DO NOT clear the back-off window on a 2xx. The window is purely
    // time-based and self-heals the instant the honored Retry-After elapses
    // (onRequest gates on `_now().isBefore(until)`), so an early clear buys
    // nothing — but it is actively harmful under the customer-home fan-out.
    //
    // The pollers fire many reads near-simultaneously (up to ~10 `GET
    // /v1/offers?requestId` probes + `/deliveries` + `/requests` per cycle,
    // overlapping the waiting-nearby `/v1/requests/:id` poll). When the gateway
    // rate limits, ONE of that batch 429s and opens the window — but the OTHER
    // in-flight reads, which passed onRequest before the window opened, land as
    // 2xx a moment later and, with the old clear-on-success logic, immediately
    // wiped the window. The very next scheduled poll then hammered the still
    // rate-limited gateway again, 429'd, re-opened the window, was wiped by the
    // next success… a self-sustaining storm (run-26: 97/97 `/v1/requests/:id`
    // polls 429, never a single recovery). Letting the window stand for the full
    // Retry-After is exactly what the gateway asked for and is what actually
    // pauses the fleet of pollers long enough for the limiter to drain.
    // b02 P0: a successful response is the evidence that the limiter has
    // drained, so it clears the consecutive-catch-up cap. The suppression
    // WINDOW is still deliberately left alone (see the paragraphs above) —
    // only the recovery budget is refreshed.
    _consecutiveCatchUps = 0;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      final retryAfter = _parseRetryAfter(err.response);
      final capped = retryAfter > _maxBackoff ? _maxBackoff : retryAfter;
      final jitterMs = _maxJitter.inMilliseconds == 0
          ? 0
          : _random.nextInt(_maxJitter.inMilliseconds + 1);
      final window = capped + Duration(milliseconds: jitterMs);
      _suppressedUntil = _now().add(window);
      _scheduleCatchUp(window);
    }
    handler.next(err);
  }

  /// (Re)arm the trailing-edge catch-up for the window that was just opened or
  /// extended. A later 429 inside an open window replaces the pending timer
  /// rather than adding a second one, so N 429s still produce ONE catch-up.
  void _scheduleCatchUp(Duration window) {
    final callback = onBackoffWindowClosed;
    if (callback == null) return;
    if (_consecutiveCatchUps >= _maxConsecutiveCatchUps) return;
    _catchUpTimer?.cancel();
    // A hair past the window so the refresh it triggers is not itself rejected
    // by `onRequest`'s `isBefore(until)` check on a boundary tick.
    _catchUpTimer = Timer(window + const Duration(milliseconds: 250), () {
      _catchUpTimer = null;
      _consecutiveCatchUps++;
      callback();
    });
  }

  /// Release the pending catch-up timer. Call from a client teardown so a
  /// disposed Dio does not fire a refresh into a closed app.
  void dispose() {
    _catchUpTimer?.cancel();
    _catchUpTimer = null;
  }

  /// Parse `Retry-After`: an integer delta-seconds OR an HTTP-date. Falls back
  /// to [_defaultBackoff] when the header is absent or unparseable. Never
  /// returns a negative duration.
  Duration _parseRetryAfter(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after')?.trim();
    if (raw == null || raw.isEmpty) return _defaultBackoff;

    final asSeconds = int.tryParse(raw);
    if (asSeconds != null) {
      return asSeconds <= 0 ? Duration.zero : Duration(seconds: asSeconds);
    }

    try {
      final date = HttpDate.parse(raw);
      final delta = date.difference(_now());
      return delta.isNegative ? Duration.zero : delta;
    } catch (_) {
      return _defaultBackoff;
    }
  }
}
