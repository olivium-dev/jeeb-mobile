import 'dart:typed_data';

/// Reduces JPEG payloads until they fit under the ticket's 2 MB ceiling. The
/// real implementation will re-encode at progressively lower quality via the
/// `image` package (landing with the camera plugin in a later ticket); the
/// default implementation shipped here halves the payload until it fits,
/// which is enough to exercise the cubit's "compress on add" path in tests
/// and against the synthetic byte-streams used by the UI-only milestone.
abstract class PhotoCompressor {
  /// Maximum allowed size after compression, per ticket T-mobile-009.
  static const int maxSizeBytes = 2 * 1024 * 1024;

  /// Returns [bytes] unchanged when already small enough; otherwise emits a
  /// shrunk payload whose length is ≤ [maxSizeBytes]. Implementations must
  /// preserve the invariant on every successful return — callers rely on it.
  Future<Uint8List> compress(Uint8List bytes);
}

/// Default implementation used by the MVP and by widget tests. Iteratively
/// halves the payload until it fits, which models a quality-step JPEG
/// re-encode well enough for behavioural testing without pulling in a native
/// image codec.
class HalvingPhotoCompressor implements PhotoCompressor {
  const HalvingPhotoCompressor();

  @override
  Future<Uint8List> compress(Uint8List bytes) async {
    if (bytes.length <= PhotoCompressor.maxSizeBytes) return bytes;
    var current = bytes;
    while (current.length > PhotoCompressor.maxSizeBytes) {
      final next = Uint8List(current.length ~/ 2);
      // Stride-copy preserves a deterministic pattern in the shrunk payload
      // so test assertions about post-compression content stay stable.
      for (var i = 0; i < next.length; i++) {
        next[i] = current[i * 2];
      }
      current = next;
    }
    return current;
  }
}
