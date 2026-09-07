import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';

void main() {
  test('internal staging authorization cannot enable any other runtime', () {
    bool staging({
      AppBuildMode mode = AppBuildMode.release,
      bool approved = true,
      bool internal = true,
      String flavor = 'staging',
      String gateway = 'https://app.jeeb.fds-1.com',
      String realtime = 'wss://app.jeeb.fds-1.com/socket/websocket',
      String project = 'y6laxxj143',
    }) => AppConfig.clarityPolicyAllowsCapture(
      buildMode: mode,
      enabled: true,
      privacyApproved: false,
      projectId: project,
      stagingInternalApproved: approved,
      internalRelease: internal,
      flavor: flavor,
      gateway: gateway,
      realtime: realtime,
    );
    expect(staging(), isTrue);
    expect(staging(approved: false), isFalse);
    expect(staging(internal: false), isFalse);
    expect(staging(flavor: 'production'), isFalse);
    expect(staging(flavor: 'dev'), isFalse);
    expect(staging(gateway: 'https://example.com'), isFalse);
    expect(staging(realtime: 'wss://example.com'), isFalse);
    expect(staging(project: 'abc123'), isFalse);
    expect(staging(mode: AppBuildMode.debug), isFalse);
    expect(staging(mode: AppBuildMode.profile), isFalse);
  });
  const validProjectId = 'y6laxxj143';

  bool allows({
    AppBuildMode mode = AppBuildMode.release,
    bool enabled = true,
    bool approved = true,
    String projectId = validProjectId,
  }) => AppConfig.clarityPolicyAllowsCapture(
    buildMode: mode,
    enabled: enabled,
    privacyApproved: approved,
    projectId: projectId,
  );

  test('only a fully approved release configuration allows capture', () {
    expect(allows(), isTrue);
    expect(allows(mode: AppBuildMode.debug), isFalse);
    expect(allows(mode: AppBuildMode.profile), isFalse);
    expect(allows(enabled: false), isFalse);
    expect(allows(approved: false), isFalse);
  });

  test('project ID must be non-empty, trimmed, lowercase alphanumeric', () {
    for (final invalid in <String>[
      '',
      ' ',
      ' y6laxxj143',
      'y6laxxj143 ',
      'Y6LAXXJ143',
      'y6laxxj-143',
      'y6laxxj_143',
    ]) {
      expect(allows(projectId: invalid), isFalse, reason: invalid);
    }
    expect(allows(projectId: 'abc123'), isTrue);
  });

  test('test runtime remains unable to start Clarity', () {
    expect(AppConfig.clarityAvailable, isFalse);
  });

  test('compile-time defaults keep Clarity completely unconfigured', () {
    expect(AppConfig.clarityEnabled, isFalse);
    expect(AppConfig.clarityPrivacyApproved, isFalse);
    expect(AppConfig.clarityProjectId, isEmpty);
    expect(AppConfig.clarityBuildConfigured, isFalse);
  });
}
