/// Starts a privacy-masked call between the two parties of a delivery.
abstract class MaskedCallRepository {
  /// Returns the masked-call session id.
  Future<String> startCall({required String orderId});
}
