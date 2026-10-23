import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../application/admin_providers.dart';

/// Admin-only screen for granting and removing staff access.
class ManageUsersScreen extends ConsumerStatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  ConsumerState<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends ConsumerState<ManageUsersScreen> {
  String _query = '';

  Future<void> _changeRole(AppUser user, UserRole role) async {
    final confirmed = await context.confirm(
      title: 'Make ${user.firstName} ${role.label.toLowerCase()}?',
      message: switch (role) {
        UserRole.student =>
          '${user.displayName} will lose access to staff tools.',
        UserRole.staff =>
          '${user.displayName} will be able to see all reports, including '
              'private ones, and update their status.',
        UserRole.admin =>
          '${user.displayName} will also be able to manage other users.',
      },
      confirmLabel: 'Change role',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(userDirectoryRepositoryProvider).setRole(user.uid, role);
      if (!mounted) return;
      context.showSnack('${user.displayName} is now ${role.label}');
    } catch (error) {
      if (mounted) context.showSnack(describeError(error), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final users = ref.watch(allUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage staff access')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: 'Search by name or email',
              leading: const Icon(Icons.search_rounded),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: AsyncValueView(
              value: users,
              onRetry: () => ref.invalidate(allUsersProvider),
              data: (users) {
                final matches = users
                    .where(
                      (u) =>
                          u.displayName.toLowerCase().contains(_query) ||
                          u.email.contains(_query),
                    )
                    .toList();
                if (matches.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No users found',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: matches.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final user = matches[index];
                    final isMe = user.uid == me?.uid;
                    return Card(
                      child: ListTile(
                        leading: UserAvatar(name: user.displayName),
                        title: Text(
                          isMe ? '${user.displayName} (you)' : user.displayName,
                        ),
                        subtitle: Text(user.email),
                        trailing: DropdownButton<UserRole>(
                          value: user.role,
                          underline: const SizedBox.shrink(),
                          onChanged: isMe
                              ? null
                              : (role) {
                                  if (role != null && role != user.role) {
                                    _changeRole(user, role);
                                  }
                                },
                          items: [
                            for (final role in UserRole.values)
                              DropdownMenuItem(
                                value: role,
                                child: Text(role.label),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
