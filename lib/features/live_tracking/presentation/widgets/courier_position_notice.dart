import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../domain/delivery_tracking_info.dart';
import '../live_tracking_l10n.dart';

class CourierPositionNotice extends StatelessWidget {
  const CourierPositionNotice({super.key, required this.info});

  final DeliveryTrackingInfo info;

  static const String semanticsId = 'tracking_position_notice';

  static bool shows(DeliveryTrackingInfo info) =>
      info.positionStatus?.isUnvouched ?? false;

  @override
  Widget build(BuildContext context) {
    if (!shows(info)) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final lost = info.positionLost;
    return Semantics(
      identifier: semanticsId,
      container: true,
      child: OmdsChip(
        label: _label(context),
        isSelected: true,
        icon: Icon(
          lost ? Icons.location_off_outlined : Icons.schedule_outlined,
          size: Sizes.small,
          color: lost ? scheme.onErrorContainer : scheme.onSecondaryContainer,
        ),
        selectedColor: lost ? scheme.errorContainer : scheme.secondaryContainer,
        selectedTextColor:
            lost ? scheme.onErrorContainer : scheme.onSecondaryContainer,
      ),
    );
  }

  String _label(BuildContext context) {
    final l10n = LiveTrackingL10n.of(context);
    final minutes = _ageMinutes;
    if (info.positionLost) {
      return minutes == null
          ? l10n.positionLostNoticeNoAge
          : l10n.positionLostNotice(minutes);
    }
    return l10n.positionStaleNotice(minutes ?? 0);
  }

  int? get _ageMinutes {
    final seconds = info.positionAgeSeconds;
    if (seconds == null) return null;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    return minutes < 1 ? null : minutes;
  }
}
