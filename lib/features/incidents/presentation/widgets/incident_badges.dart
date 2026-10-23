import 'package:flutter/material.dart';

import '../../domain/incident_enums.dart';

extension IncidentCategoryStyle on IncidentCategory {
  IconData get icon => switch (this) {
    IncidentCategory.facilities => Icons.apartment_rounded,
    IncidentCategory.water => Icons.water_drop_outlined,
    IncidentCategory.electricity => Icons.bolt_rounded,
    IncidentCategory.furniture => Icons.chair_outlined,
    IncidentCategory.sanitation => Icons.delete_outline_rounded,
    IncidentCategory.safety => Icons.shield_outlined,
    IncidentCategory.internet => Icons.wifi_rounded,
    IncidentCategory.other => Icons.more_horiz_rounded,
  };
}

extension IncidentStatusStyle on IncidentStatus {
  Color get color => switch (this) {
    IncidentStatus.submitted => const Color(0xFFE8A317),
    IncidentStatus.underReview => const Color(0xFF2F80ED),
    IncidentStatus.inProgress => const Color(0xFF6C4CF1),
    IncidentStatus.resolved => const Color(0xFF27AE60),
    IncidentStatus.rejected => const Color(0xFFEB5757),
  };

  IconData get icon => switch (this) {
    IncidentStatus.submitted => Icons.outbox_rounded,
    IncidentStatus.underReview => Icons.manage_search_rounded,
    IncidentStatus.inProgress => Icons.build_circle_outlined,
    IncidentStatus.resolved => Icons.check_circle_rounded,
    IncidentStatus.rejected => Icons.cancel_outlined,
  };
}

extension IncidentPriorityStyle on IncidentPriority {
  Color get color => switch (this) {
    IncidentPriority.low => const Color(0xFF27AE60),
    IncidentPriority.medium => const Color(0xFFE8A317),
    IncidentPriority.high => const Color(0xFFEB5757),
  };
}

/// Small rounded label tinted with [color]; readable in light and dark mode.
class TintedBadge extends StatelessWidget {
  const TintedBadge({
    required this.label,
    required this.color,
    this.icon,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;

  /// Shifts the brand colour's lightness so text keeps >= 4.5:1 contrast on
  /// the tinted background in both themes.
  static Color readableOn(Color color, Brightness brightness) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(brightness == Brightness.light ? 0.27 : 0.75)
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = readableOn(color, Theme.of(context).brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final IncidentStatus status;

  @override
  Widget build(BuildContext context) =>
      TintedBadge(label: status.label, color: status.color);
}

class CategoryIcon extends StatelessWidget {
  const CategoryIcon(this.category, {this.size = 48, super.key});

  final IncidentCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(
        category.icon,
        color: scheme.onPrimaryContainer,
        size: size * 0.5,
        semanticLabel: category.label,
      ),
    );
  }
}
