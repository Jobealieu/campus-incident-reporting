/// Build-time switches, set with `--dart-define`.
abstract final class AppConfig {
  /// Talk to the local Firebase emulators instead of the live project.
  static const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  /// Store photos in a Firebase Storage bucket. The live project is on the
  /// free Spark plan, which has no bucket, so photos go to Firestore unless
  /// this is set (or the emulators, which include Storage, are in use).
  static const usePhotoBucket =
      useEmulators || bool.fromEnvironment('USE_STORAGE_BUCKET');
}
