import 'package:url_launcher/url_launcher.dart';

import '../domain/phone_dialer.dart';

/// `url_launcher`-backed [PhoneDialer] (orders-masked-call).
///
/// Opens the native dialer with a `tel:` URL pre-filled with the masked proxy
/// number. We use `LaunchMode.externalApplication` so the OS dialer takes over;
/// the user still presses the call button (we never auto-dial).
class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  @override
  Future<bool> dial(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
