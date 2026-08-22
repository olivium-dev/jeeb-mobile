import '../../application/client_home_state.dart';
import '../../domain/client_home_request.dart';

/// The two facets the filter sheet stages and the home screen commits. The
/// default is unfiltered, which is what [isActive] answers.
class ClientRequestFilter {
  const ClientRequestFilter({
    this.bucket = ClientHomeTab.all,
    this.offerStatus,
  });

  /// Which slice of the merged list to render.
  final ClientHomeTab bucket;

  /// Narrows to `state.offerStatusRequests`; null leaves the bucket alone.
  final ClientOfferStatus? offerStatus;

  bool get isActive =>
      bucket != ClientHomeTab.all || offerStatus != null;

  @override
  bool operator ==(Object other) =>
      other is ClientRequestFilter &&
      other.bucket == bucket &&
      other.offerStatus == offerStatus;

  @override
  int get hashCode => Object.hash(bucket, offerStatus);
}
