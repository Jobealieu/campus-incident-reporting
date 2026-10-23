enum UserRole {
  student('Student'),
  staff('Staff'),
  admin('Admin');

  const UserRole(this.label);

  final String label;

  static UserRole fromName(String? name) => values.firstWhere(
    (role) => role.name == name,
    orElse: () => UserRole.student,
  );
}

/// Profile stored at `users/{uid}`. The role decides what a user may do.
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
    uid: uid,
    email: data['email'] as String? ?? '',
    displayName: data['displayName'] as String? ?? 'ALU member',
    role: UserRole.fromName(data['role'] as String?),
  );

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  /// Staff and admins both handle incidents; only admins manage roles.
  bool get isStaff => role != UserRole.student;
  bool get isAdmin => role == UserRole.admin;

  String get firstName => displayName.trim().split(' ').first;
}
