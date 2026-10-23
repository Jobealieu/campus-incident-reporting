import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../data/incident_repository.dart';
import '../data/photo_storage.dart';
import '../domain/incident.dart';
import '../domain/incident_enums.dart';
import '../domain/incident_filter.dart';
import '../domain/incident_summary.dart';

final photoStoreProvider = Provider<PhotoStore>(
  (ref) => AppConfig.usePhotoBucket
      ? StoragePhotoStore(ref.watch(firebaseStorageProvider))
      : FirestorePhotoStore(ref.watch(firestoreProvider)),
);

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepository(
    ref.watch(firestoreProvider),
    ref.watch(photoStoreProvider),
  ),
);

/// JPEG bytes of a photo kept in Firestore, cached for the session so list
/// thumbnails don't refetch while scrolling.
final incidentPhotoBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, path) {
      ref.keepAlive();
      return FirestorePhotoStore(ref.watch(firestoreProvider)).read(path);
    });

final _uidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((user) => user.value?.uid)),
);

final _isStaffProvider = Provider<bool>(
  (ref) => ref.watch(
    currentUserProvider.select((user) => user.value?.isStaff ?? false),
  ),
);

final myIncidentsProvider = StreamProvider<List<Incident>>((ref) {
  final uid = ref.watch(_uidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(incidentRepositoryProvider).watchReportedBy(uid);
});

final _publicIncidentsProvider = StreamProvider<List<Incident>>((ref) {
  if (ref.watch(_uidProvider) == null) return Stream.value(const []);
  return ref.watch(incidentRepositoryProvider).watchPublic();
});

final _allIncidentsProvider = StreamProvider<List<Incident>>((ref) {
  if (!ref.watch(_isStaffProvider)) return Stream.value(const []);
  return ref.watch(incidentRepositoryProvider).watchAll();
});

/// Everything the current user may browse: all reports for staff; public
/// reports plus their own (including private ones) for students.
final visibleIncidentsProvider = Provider<AsyncValue<List<Incident>>>((ref) {
  if (ref.watch(_isStaffProvider)) return ref.watch(_allIncidentsProvider);

  final public = ref.watch(_publicIncidentsProvider);
  final mine = ref.watch(myIncidentsProvider);
  if (public.hasError) return public;
  if (mine.hasError) return mine;
  if (!public.hasValue || !mine.hasValue) return const AsyncLoading();

  final byId = {
    for (final incident in [...public.requireValue, ...mine.requireValue])
      incident.id: incident,
  };
  final merged = byId.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return AsyncData(merged);
});

class IncidentFilterNotifier extends Notifier<IncidentFilter> {
  @override
  IncidentFilter build() => const IncidentFilter();

  void setQuery(String query) => state = state.copyWith(query: query);

  void setStatus(IncidentStatus? status) =>
      state = state.copyWith(status: () => status);

  void setCategory(IncidentCategory? category) =>
      state = state.copyWith(category: () => category);

  void clear() => state = const IncidentFilter();
}

final incidentFilterProvider =
    NotifierProvider<IncidentFilterNotifier, IncidentFilter>(
      IncidentFilterNotifier.new,
    );

final filteredIncidentsProvider = Provider<AsyncValue<List<Incident>>>((ref) {
  final filter = ref.watch(incidentFilterProvider);
  return ref.watch(visibleIncidentsProvider).whenData(filter.apply);
});

/// Students see a summary of their own reports; staff see the whole campus.
final dashboardSummaryProvider = Provider<AsyncValue<IncidentSummary>>((ref) {
  final source = ref.watch(_isStaffProvider)
      ? ref.watch(_allIncidentsProvider)
      : ref.watch(myIncidentsProvider);
  return source.whenData(IncidentSummary.of);
});

final incidentProvider = StreamProvider.autoDispose.family<Incident?, String>(
  (ref, id) => ref.watch(incidentRepositoryProvider).watchIncident(id),
);

final incidentUpdatesProvider = StreamProvider.autoDispose
    .family<List<StatusUpdate>, String>(
      (ref, id) => ref.watch(incidentRepositoryProvider).watchUpdates(id),
    );

/// Runs incident mutations and exposes their loading/error state to the UI.
class IncidentActions extends AsyncNotifier<void> {
  IncidentRepository get _repository => ref.read(incidentRepositoryProvider);

  AppUser get _user {
    final user = ref.read(currentUserProvider).value;
    if (user == null) throw const AppException('Please sign in again.');
    return user;
  }

  @override
  FutureOr<void> build() {}

  /// Returns the new incident id, or null on failure.
  Future<String?> submit(IncidentDraft draft, Uint8List? photo) async {
    String? id;
    final ok = await _run(() async {
      id = await _repository.create(
        draft: draft,
        reporter: _user,
        photo: photo,
      );
    });
    return ok ? id : null;
  }

  Future<bool> updateDetails(
    String incidentId, {
    required String title,
    required String description,
    required String location,
  }) => _run(
    () => _repository.updateDetails(
      incidentId: incidentId,
      title: title,
      description: description,
      location: location,
    ),
  );

  Future<bool> toggleUpvote(Incident incident) => _run(() {
    final uid = _user.uid;
    return _repository.setUpvote(
      incidentId: incident.id,
      uid: uid,
      upvoted: !incident.hasUpvoted(uid),
    );
  });

  Future<bool> updateStatus(
    String incidentId, {
    required IncidentStatus status,
    required IncidentPriority? priority,
    String? note,
  }) => _run(() {
    final staff = _user;
    if (!staff.isStaff) {
      throw const AppException('Only campus staff can update a status.');
    }
    return _repository.updateStatus(
      incidentId: incidentId,
      status: status,
      priority: priority,
      staff: staff,
      note: note,
    );
  });

  Future<bool> delete(Incident incident) =>
      _run(() => _repository.delete(incident));

  Future<bool> _run(Future<void> Function() action) async {
    state = const AsyncLoading();
    final result = await AsyncValue.guard(action);
    if (ref.mounted) state = result;
    return !result.hasError;
  }
}

final incidentActionsProvider = AsyncNotifierProvider<IncidentActions, void>(
  IncidentActions.new,
);
