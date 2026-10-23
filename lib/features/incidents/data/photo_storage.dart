import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../../../core/errors/app_exception.dart';

class UploadedPhoto {
  const UploadedPhoto({required this.path, this.url});

  /// Where the photo lives: a Storage object path or a Firestore doc path.
  final String path;

  /// Download URL for Storage photos; null for photos kept in Firestore.
  final String? url;
}

/// Saves and removes incident photos. Every implementation re-encodes the
/// image as JPEG and drops EXIF metadata so GPS coordinates and device
/// details never leave the phone.
abstract interface class PhotoStore {
  Future<UploadedPhoto> upload({
    required String ownerId,
    required String incidentId,
    required Uint8List bytes,
  });

  Future<void> delete(String path);
}

Future<Uint8List> _compress(
  Uint8List bytes, {
  required int size,
  required int quality,
}) => FlutterImageCompress.compressWithList(
  bytes,
  minWidth: size,
  minHeight: size,
  quality: quality,
  keepExif: false,
);

/// Firebase Storage, at `incidents/{uid}/{incidentId}.jpg`.
class StoragePhotoStore implements PhotoStore {
  StoragePhotoStore(this._storage);

  final FirebaseStorage _storage;

  @override
  Future<UploadedPhoto> upload({
    required String ownerId,
    required String incidentId,
    required Uint8List bytes,
  }) async {
    final compressed = await _compress(bytes, size: 1600, quality: 75);
    final path = 'incidents/$ownerId/$incidentId.jpg';
    final ref = _storage.ref(path);
    await ref.putData(compressed, SettableMetadata(contentType: 'image/jpeg'));
    return UploadedPhoto(path: path, url: await ref.getDownloadURL());
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _storage.ref(path).delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') rethrow;
    }
  }
}

/// Cloud Firestore, at `incidentPhotos/{incidentId}`, for projects on the
/// free Spark plan where a Storage bucket is not available.
// ponytail: one photo per document, capped below Firestore's 1 MiB doc limit.
// Switch to StoragePhotoStore (USE_STORAGE_BUCKET) once billing is enabled.
class FirestorePhotoStore implements PhotoStore {
  FirestorePhotoStore(this._firestore);

  final FirebaseFirestore _firestore;

  static const collection = 'incidentPhotos';
  static const maxBytes = 900 * 1024;

  @override
  Future<UploadedPhoto> upload({
    required String ownerId,
    required String incidentId,
    required Uint8List bytes,
  }) async {
    var compressed = await _compress(bytes, size: 1280, quality: 70);
    if (compressed.length > maxBytes) {
      compressed = await _compress(bytes, size: 800, quality: 50);
    }
    if (compressed.length > maxBytes) {
      throw const AppException('That photo is too large. Try another one.');
    }
    final path = '$collection/$incidentId';
    await _firestore.doc(path).set({
      'ownerId': ownerId,
      'image': Blob(compressed),
      'contentType': 'image/jpeg',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return UploadedPhoto(path: path);
  }

  /// Reads the JPEG bytes of a photo stored by [upload].
  Future<Uint8List?> read(String path) async {
    final doc = await _firestore.doc(path).get();
    return (doc.data()?['image'] as Blob?)?.bytes;
  }

  @override
  Future<void> delete(String path) => _firestore.doc(path).delete();
}
