import 'dart:typed_data';

import 'package:equatable/equatable.dart';

/// Source the user picked the photo from. Used for analytics and to drive the
/// permission rationale the platform layer surfaces.
enum PhotoSource { camera, gallery }

/// Immutable record of a single photo attachment.
///
/// [bytes] is the post-compression payload — it is the only form the request
/// pipeline ever sends to the server, so the invariant `bytes.length <=
/// maxSizeBytes` is preserved by the cubit on every emit.
class PhotoAttachment extends Equatable {
  const PhotoAttachment({
    required this.id,
    required this.bytes,
    required this.originalSizeBytes,
    required this.source,
  });

  /// Stable per-attachment id used as a List key and for [hashCode]/[==]. The
  /// cubit generates a monotonic counter so removal-by-id is unambiguous even
  /// if two captures happen to produce identical bytes.
  final String id;

  /// Compressed JPEG bytes. Always ≤ 2 MB once the cubit has accepted the
  /// attachment.
  final Uint8List bytes;

  /// Size of the source image before compression. Kept for analytics and so
  /// the UI can render "compressed from N MB" hints later.
  final int originalSizeBytes;

  final PhotoSource source;

  int get sizeBytes => bytes.length;

  @override
  List<Object?> get props => [id, bytes.length, originalSizeBytes, source];
}
