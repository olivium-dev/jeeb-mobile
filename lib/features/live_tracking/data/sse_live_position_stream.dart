import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../domain/delivery_tracking_info.dart';
import '../domain/live_tracking_repository.dart';

/// b02 wave C — N7, position axis: the mobile **server-sent-events** consumer
/// for the jeeber's live position.
///
/// ## Why this is not a push, and not a poll
/// The live-tracking screen has TWO distinct data needs and they are NOT the
/// same shape:
///  * a status transition is an **EVENT** — discrete, rare, and exactly what a
///    `type=delivery` push is for. That axis is handled by
///    `LiveTrackingCubit`'s push subscription.
///  * the courier's position is a **STREAM** — continuous while en route. No
///    push carries it (and shouldn't: every one of the gateway's four send
///    endpoints attaches a notification block, so a position push would light
///    up the shade several times a minute).
///
/// Conflating the two is what produced the 5s `GET /deliveries/{id}/tracking`
/// this class deletes. Server-sent events are the right primitive for the second
/// axis and are **server-push**: the client opens ONE connection and the server
/// writes when it has something. That does not breach the no-long-polling rule —
/// there is no request per sample and no client-side cadence anywhere in here.
///
/// ## The endpoint already existed; the consumer did not
/// `GET /v1/geo/jeeb/stream/{deliveryId}`
/// (`jeeb-gateway/src/JeebGateway/Controllers/LocationController.cs:240`) →
/// `TrackOrPolylineAsync` (`:257`) → `StreamSseAsync` (`:368`). The gateway
/// resolves the delivery's parties and DENIES a non-party with 403 BEFORE
/// opening the upstream subscription, and it breaks its own loop on a terminal
/// status (`:392-397`), so a completed trip closes the socket server-side.
///
/// ## Content negotiation is load-bearing
/// The SAME route answers a non-SSE `Accept` with a ONE-SHOT JSON polyline
/// snapshot (`:293-301`). So an `Accept` header that does not contain
/// `text/event-stream` does not fail — it silently returns a single body and the
/// stream never opens. That is precisely the invisible-degradation shape this
/// batch keeps hitting, which is why the header is asserted in a test rather
/// than trusted.
///
/// ## Wire format
/// `EmitFrameAsync` (`:449-453`) writes `event: <name>\ndata: <json>\n\n`, one
/// `data:` line carrying the whole compact JSON. `<name>` is `position`, or
/// `last-seen` once the newest fix is older than `StaleThreshold` (2 min) —
/// BOTH still carry the last known fix, so both are surfaced. The JSON is
/// serialized with `JsonSerializerDefaults.Web` (camelCase) and is the same
/// `position` / `polyline` shape the one-shot snapshot uses, which is why
/// [DeliveryTrackingInfo.fromTrackingJson] parses either.
///
/// ## Failure policy: degrade, but never silently
/// Any transport failure ends the stream instead of faulting the screen — the
/// map keeps its last-known marker and the stepper is driven by the push axis
/// regardless. But a dead position stream IS a real degradation, so every
/// terminal outcome emits a `[jeeb-diag]` breadcrumb (`tracking_sse`). A frozen
/// marker with nothing in the journal is the failure mode that costs a whole
/// device run.
class SseLivePositionStream implements LivePositionStreamSource {
  SseLivePositionStream(this._dio);

  final Dio _dio;

  @override
  Stream<DeliveryLivePosition> watchLivePosition({
    required String deliveryId,
  }) {
    final controller = StreamController<DeliveryLivePosition>();
    StreamSubscription<Uint8List>? byteSub;
    CancelToken? cancelToken;

    Future<void> shutdown(String reason, {Object? detail}) async {
      Diag.event('tracking_sse', <String, Object?>{
        'deliveryId': deliveryId,
        'state': reason,
        if (detail != null) 'detail': detail.toString(),
      });
      await byteSub?.cancel();
      byteSub = null;
      if (!controller.isClosed) await controller.close();
    }

    controller.onListen = () async {
      cancelToken = CancelToken();
      try {
        final response = await _dio.get<ResponseBody>(
          '/v1/geo/jeeb/stream/${Uri.encodeComponent(deliveryId)}',
          cancelToken: cancelToken,
          options: Options(
            responseType: ResponseType.stream,
            // The route content-negotiates: without this the gateway returns a
            // ONE-SHOT polyline snapshot and no stream ever opens.
            headers: <String, Object?>{
              Headers.acceptHeader: 'text/event-stream',
            },
            // The app-wide Dio sets receiveTimeout: 15s. A held connection must
            // disable it or Dio tears the stream down mid-delivery. `zero` is
            // Dio's "no timeout".
            receiveTimeout: Duration.zero,
            // The gateway answers 403 (not a party) / 404 (no such delivery)
            // with a body we want to READ rather than throw on, so we can log
            // the status and close cleanly.
            validateStatus: (_) => true,
          ),
        );

        final body = response.data;
        if (body == null || response.statusCode != 200) {
          await shutdown('rejected', detail: response.statusCode);
          return;
        }

        Diag.event('tracking_sse', <String, Object?>{
          'deliveryId': deliveryId,
          'state': 'open',
        });

        // SSE frames are delimited by a BLANK LINE, and a TCP chunk boundary can
        // fall anywhere — including mid-JSON. Buffer until a delimiter is
        // actually present; parsing per chunk drops every split frame.
        var buffer = '';
        byteSub = body.stream.listen(
          (chunk) {
            buffer += utf8.decode(chunk, allowMalformed: true);
            while (true) {
              final split = _nextFrameBreak(buffer);
              if (split == null) break;
              final frame = buffer.substring(0, split.start);
              buffer = buffer.substring(split.end);
              final position = _parseFrame(frame);
              // A frame with neither a fix nor a route has nothing to overlay.
              // Emitting an empty one would let the screen blank a marker it
              // already has (the pre-first-fix case).
              if (position != null &&
                  !position.isEmpty &&
                  !controller.isClosed) {
                controller.add(position);
              }
            }
          },
          onError: (Object e) => shutdown('error', detail: e.runtimeType),
          onDone: () => shutdown('closed'),
          cancelOnError: true,
        );
      } catch (e) {
        await shutdown('error', detail: e.runtimeType);
      }
    };

    controller.onCancel = () async {
      // The subscriber (screen close / terminal delivery) walked away. Cancel
      // the HTTP request too, or the gateway keeps writing into a socket nobody
      // reads for the rest of the trip.
      cancelToken?.cancel('live-tracking position stream released');
      await byteSub?.cancel();
      byteSub = null;
    };

    return controller.stream;
  }

  /// Locates the next frame delimiter, tolerating both `\n\n` and `\r\n\r\n`.
  /// Returns the frame's end offset and the offset to resume from.
  static ({int start, int end})? _nextFrameBreak(String buffer) {
    final lf = buffer.indexOf('\n\n');
    final crlf = buffer.indexOf('\r\n\r\n');
    if (lf < 0 && crlf < 0) return null;
    if (crlf >= 0 && (lf < 0 || crlf < lf)) {
      return (start: crlf, end: crlf + 4);
    }
    return (start: lf, end: lf + 2);
  }

  /// Extracts the overlay from one SSE frame. Returns null when the frame has no
  /// parseable `data:` payload — a malformed frame is SKIPPED, never fatal: the
  /// connection is worth more than any single sample.
  static DeliveryLivePosition? _parseFrame(String frame) {
    final dataLines = <String>[];
    for (final raw in frame.split('\n')) {
      final line = raw.endsWith('\r')
          ? raw.substring(0, raw.length - 1)
          : raw;
      // Comment/heartbeat lines start with ':' and carry no payload.
      if (line.startsWith(':')) continue;
      if (!line.startsWith('data:')) continue;
      dataLines.add(line.substring(5).trimLeft());
    }
    if (dataLines.isEmpty) return null;
    try {
      final decoded = jsonDecode(dataLines.join('\n'));
      if (decoded is! Map<String, dynamic>) return null;
      // Reuses the SNAPSHOT parser deliberately: `TrackingFrameDto` and
      // `TrackingPolylineDto` carry the same camelCase `position` / `polyline`
      // pair, so one parser cannot drift from the other.
      final info = DeliveryTrackingInfo.fromTrackingJson(
        (decoded['deliveryId'] as String?) ?? '',
        decoded,
      );
      return DeliveryLivePosition(
        jeeberPosition: info.jeeberPosition,
        polyline: info.polyline,
      );
    } on FormatException {
      return null;
    } catch (_) {
      // A shape surprise (a null lat, a string where a number was promised)
      // must not take the socket down with it.
      return null;
    }
  }
}
