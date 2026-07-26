import 'dart:async';

typedef KycPollIntervalResolver =
    Duration? Function({
      required Duration elapsed,
      required int scheduledProbes,
    });

enum _ProbeSource { scheduled, resume, manual }

/// Owns the bounded, single-flight runtime for KYC status polling.
///
/// The cubit is intentionally not guarded: it also serves user-driven callers,
/// which a blanket cubit-level in-flight guard could silently drop.
class KycStatusPollController {
  KycStatusPollController({
    required KycPollIntervalResolver intervalAt,
    required int maxResumeProbes,
    required Future<bool> Function() probe,
    void Function()? onChanged,
  }) : _intervalAt = intervalAt,
       _maxResumeProbes = maxResumeProbes,
       _probe = probe,
       _onChanged = onChanged;

  final KycPollIntervalResolver _intervalAt;
  final int _maxResumeProbes;
  final Future<bool> Function() _probe;
  void Function()? _onChanged;

  Timer? _timer;
  Duration _elapsed = Duration.zero;
  int _scheduledProbes = 0;
  int _resumeProbes = 0;
  bool _foreground = true;
  bool _started = false;
  bool _stopped = false;
  bool _disposed = false;
  bool _expired = false;
  bool _inFlight = false;

  bool get isExpired => _expired;
  bool get isInFlight => _inFlight;
  int get scheduledProbes => _scheduledProbes;
  int get resumeProbes => _resumeProbes;

  void start() {
    if (_started || _stopped || _disposed) return;
    _started = true;
    _armNext();
  }

  void pause() {
    if (!_foreground || _disposed) return;
    _foreground = false;
    _cancelTimer();
    _notify();
  }

  void resume() {
    if (_foreground || _stopped || _disposed || !_started) return;
    _foreground = true;
    _notify();
    if (_inFlight || !_canIssue(_ProbeSource.resume)) {
      _armNext();
      return;
    }
    unawaited(_runProbe(_ProbeSource.resume));
  }

  Future<void> checkNow() async {
    if (!_canIssue(_ProbeSource.manual)) return;
    _cancelTimer();
    await _runProbe(_ProbeSource.manual);
  }

  void stop() {
    if (_stopped || _disposed) return;
    _stopped = true;
    _cancelTimer();
    _notify();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _stopped = true;
    _cancelTimer();
    _onChanged = null;
  }

  bool get _canArm {
    return _started &&
        _foreground &&
        !_stopped &&
        !_disposed &&
        !_expired &&
        !_inFlight &&
        _timer == null;
  }

  bool _canIssue(_ProbeSource source) {
    if (!_started || !_foreground || _stopped || _disposed || _inFlight) {
      return false;
    }
    return switch (source) {
      _ProbeSource.scheduled => !_expired,
      _ProbeSource.resume => _resumeProbes < _maxResumeProbes,
      _ProbeSource.manual => true,
    };
  }

  void _armNext() {
    if (!_canArm) return;
    final interval = _intervalAt(
      elapsed: _elapsed,
      scheduledProbes: _scheduledProbes,
    );
    if (interval == null) {
      _expire();
      return;
    }
    _timer = Timer(interval, () => _onScheduledTimer(interval));
  }

  void _onScheduledTimer(Duration interval) {
    _timer = null;
    if (!_canIssue(_ProbeSource.scheduled)) return;
    _elapsed += interval;
    unawaited(_runProbe(_ProbeSource.scheduled));
  }

  Future<void> _runProbe(_ProbeSource source) async {
    if (!_canIssue(source)) return;
    _inFlight = true;
    _increment(source);
    _notify();
    late final bool pending;
    try {
      pending = await _probe();
    } finally {
      _inFlight = false;
      _notify();
    }
    if (_disposed || _stopped) return;
    if (!pending) {
      stop();
      return;
    }
    _armNext();
  }

  void _increment(_ProbeSource source) {
    switch (source) {
      case _ProbeSource.scheduled:
        _scheduledProbes++;
      case _ProbeSource.resume:
        _resumeProbes++;
      case _ProbeSource.manual:
        return;
    }
  }

  void _expire() {
    if (_expired || _stopped || _disposed) return;
    _expired = true;
    _cancelTimer();
    _notify();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _notify() {
    if (!_disposed) _onChanged?.call();
  }
}
