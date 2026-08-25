import 'package:clarity_flutter/clarity_flutter.dart';
import 'package:flutter/widgets.dart';

import '../domain/clarity_analytics_port.dart';

/// The only application adapter allowed to call Microsoft Clarity static APIs.
final class MicrosoftClarityAdapter implements ClarityAnalyticsPort {
  const MicrosoftClarityAdapter({required String projectId})
    : _projectId = projectId;

  final String _projectId;

  @override
  bool setSessionStartedCallback(VoidCallback onSessionStarted) =>
      Clarity.setOnSessionStartedCallback((_) => onSessionStarted());

  @override
  bool initialize(BuildContext context) => Clarity.initialize(
    context,
    ClarityConfig(projectId: _projectId, logLevel: LogLevel.None),
  );

  @override
  bool consent({required bool adsStorage, required bool analyticsStorage}) =>
      Clarity.consent(adsStorage, analyticsStorage);

  @override
  bool pause() => Clarity.pause();

  @override
  bool isPaused() => Clarity.isPaused();

  @override
  bool resume() => Clarity.resume();

  @override
  bool startNewSession() => Clarity.startNewSession((_) {});

  @override
  bool setScreenName(String? screenName) =>
      Clarity.setCurrentScreenName(screenName);
}
