/// Port over the native phone dialer (orders-masked-call).
///
/// The masked-call flow brokers a proxy number then asks the OS to open the
/// dialer pre-filled with it (`tel:` URL). Kept behind a port so the cubit and
/// its tests stay platform-free; DI binds the `url_launcher`-backed impl.
abstract class PhoneDialer {
  const PhoneDialer();

  /// Opens the native dialer for [phoneNumber] (E.164). Returns `true` when the
  /// dialer was launched, `false` when no dialer is available on the device.
  Future<bool> dial(String phoneNumber);
}
