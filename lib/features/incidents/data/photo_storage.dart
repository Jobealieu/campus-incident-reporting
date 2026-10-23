import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class UploadedPhoto {
  const UploadedPhoto({required this.url, required this.path});

  final String url;
  final String path;
}

/// Stores incident photos in Firebase Storage under `incidents/{uid}/`.
class PhotoStorage {
  PhotoStorage(this._storage);

  final FirebaseStorage _storage;

  static const _maxDimension = 1600;
  static const _jpegQuality = 75;

  /// Re-encodes the photo as a smaller JPEG and drops EXIF metadata so GPS
  /// coordinates and device details never leave the phone.
  Future<UploadedPhoto> upload({
    required String ownerId,
    required String incidentId,
    required Uint8List bytes,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
      quality: _jpegQuality,
      keepExif: false,
    );
    final path = 'incidents/$ownerId/$incidentId.jpg';
    final ref = _storage.ref(path);
    await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return UploadedPhoto(url: await ref.getDownloadURL(), path: path);
  }

  Future<void> delete(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}
