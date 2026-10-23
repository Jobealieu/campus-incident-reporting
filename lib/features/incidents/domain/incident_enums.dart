enum IncidentCategory {
  facilities('Facilities'),
  water('Water'),
  electricity('Electricity'),
  furniture('Furniture'),
  sanitation('Sanitation'),
  safety('Safety'),
  internet('Internet & IT'),
  other('Other');

  const IncidentCategory(this.label);

  final String label;

  /// Safety reports may identify people, so only the reporter and staff see
  /// them. Enforced again in `firestore.rules`.
  bool get isAlwaysPrivate => this == IncidentCategory.safety;

  static IncidentCategory fromName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => IncidentCategory.other,
  );
}

/// Lifecycle: submitted → underReview → inProgress → resolved, or rejected
/// (duplicate, out of scope) at any point by staff.
enum IncidentStatus {
  submitted('Submitted'),
  underReview('Under review'),
  inProgress('In progress'),
  resolved('Resolved'),
  rejected('Rejected');

  const IncidentStatus(this.label);

  final String label;

  bool get isOpen => this != resolved && this != rejected;

  /// The happy-path steps shown on the status timeline.
  static const timeline = [submitted, underReview, inProgress, resolved];

  static IncidentStatus fromName(String? name) => values.firstWhere(
    (value) => value.name == name,
    orElse: () => IncidentStatus.submitted,
  );
}

enum IncidentPriority {
  low('Low'),
  medium('Medium'),
  high('High');

  const IncidentPriority(this.label);

  final String label;

  static IncidentPriority? fromName(String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
