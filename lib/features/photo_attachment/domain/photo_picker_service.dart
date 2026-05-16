import 'dart:typed_data';

import 'photo_attachment.dart';

/// Raw photo straight from the camera or gallery, before compression.
class RawPhoto {
  const RawPhoto({required this.bytes, required this.source});

  final Uint8List bytes;
  final PhotoSource source;
}

/// Reasons a pick request can fail to produce a photo. The cubit maps these
/// onto user-visible state so the screen can render the right copy without
/// the service layer knowing anything about localisation.
enum PhotoPickFailure {
  /// User dismissed the camera/gallery without choosing anything.
  cancelled,

  /// OS permission denied (or permanently denied). The screen will route the
  /// user to settings.
  permissionDenied,

  /// Camera unavailable, file unreadable, etc. — catch-all hardware/IO bucket.
  unavailable,
}

/// Thrown by [PhotoPickerService] when the underlying platform pick fails.
/// Kept as an exception (not an Either) to match the lightweight surface area
/// the voice_request feature uses for its own audio service.
class PhotoPickException implements Exception {
  const PhotoPickException(this.failure);

  final PhotoPickFailure failure;

  @override
  String toString() => 'PhotoPickException(${failure.name})';
}

/// Platform-agnostic photo picker. The mobile shell binds this to
/// `image_picker` (T-mobile-040 follow-up); tests bind it to a deterministic
/// in-memory implementation that returns canned bytes.
abstract class PhotoPickerService {
  /// Capture a single photo from the device camera. Implementations must
  /// throw [PhotoPickException] with [PhotoPickFailure.cancelled] when the
  /// user backs out without taking a shot — returning null was rejected so
  /// the cubit's add() flow is a single try/catch.
  Future<RawPhoto> pickFromCamera();

  /// Pick a single photo from the system gallery. Same failure contract as
  /// [pickFromCamera].
  Future<RawPhoto> pickFromGallery();
}
