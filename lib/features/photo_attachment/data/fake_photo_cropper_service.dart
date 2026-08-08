import 'dart:typed_data';

import '../domain/photo_cropper_service.dart';

/// Test-only [PhotoCropperService]. Passthrough by default (no real crop UI
/// exists in a widget-test host) — set [cancels] to simulate the user
/// dismissing the crop screen.
class FakePhotoCropperService implements PhotoCropperService {
  FakePhotoCropperService({this.cancels = false});

  final bool cancels;
  int cropCalls = 0;
  Uint8List? lastInput;

  @override
  Future<Uint8List?> crop(Uint8List bytes) async {
    cropCalls++;
    lastInput = bytes;
    return cancels ? null : bytes;
  }
}
