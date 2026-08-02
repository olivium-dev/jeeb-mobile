import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

abstract class ProfilePhotoStore {
  Future<String> persist(Uint8List bytes);
}

class AppDirProfilePhotoStore implements ProfilePhotoStore {
  const AppDirProfilePhotoStore();

  @override
  Future<String> persist(Uint8List bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/profile_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

class FakeProfilePhotoStore implements ProfilePhotoStore {
  FakeProfilePhotoStore({this.path = '/tmp/fake_profile_avatar.jpg'});

  final String path;
  Uint8List? lastBytes;
  int persistCalls = 0;

  @override
  Future<String> persist(Uint8List bytes) async {
    persistCalls++;
    lastBytes = bytes;
    return path;
  }
}
