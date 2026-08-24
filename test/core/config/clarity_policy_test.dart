import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';

void main() {
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
}
