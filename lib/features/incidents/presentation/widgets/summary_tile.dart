import 'package:flutter/material.dart';

class SummaryTile extends StatelessWidget {
  const SummaryTile({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$count $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              '$count',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of [SummaryTile]s with even spacing.
class SummaryRow extends StatelessWidget {
  const SummaryRow({required this.tiles, super.key});

  final List<SummaryTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}
