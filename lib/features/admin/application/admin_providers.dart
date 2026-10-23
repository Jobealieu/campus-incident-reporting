import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../auth/domain/app_user.dart';
import '../data/user_directory_repository.dart';

final userDirectoryRepositoryProvider = Provider<UserDirectoryRepository>(
  (ref) => UserDirectoryRepository(ref.watch(firestoreProvider)),
);

final allUsersProvider = StreamProvider.autoDispose<List<AppUser>>(
  (ref) => ref.watch(userDirectoryRepositoryProvider).watchAll(),
);
