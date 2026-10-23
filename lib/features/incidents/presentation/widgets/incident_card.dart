import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/date_format.dart';
import '../../domain/incident.dart';
import 'incident_badges.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({required this.incident, super.key});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/incident/${incident.id}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IncidentThumbnail(incident: incident),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            incident.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (incident.isPrivate)
                          Tooltip(
                            message: 'Visible only to you and staff',
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incident.location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: muted,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: muted?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(formatRelative(incident.createdAt), style: muted),
                        if (incident.upvoteCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.people_alt_outlined,
                            size: 14,
                            color: muted?.color,
                          ),
                          const SizedBox(width: 4),
                          Text('${incident.upvoteCount}', style: muted),
                        ],
                        const Spacer(),
                        StatusBadge(incident.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The report photo when there is one, otherwise its category icon.
class IncidentThumbnail extends StatelessWidget {
  const IncidentThumbnail({required this.incident, this.size = 64, super.key});

  final Incident incident;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = CategoryIcon(incident.category, size: size);
    final url = incident.photoUrl;
    if (url == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.3),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
