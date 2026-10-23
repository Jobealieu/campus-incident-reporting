import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/incident_providers.dart';
import '../../domain/incident.dart';

/// Shows an incident photo from Firebase Storage (download URL) or from
/// Firestore (raw bytes), with [fallback] while missing or on error.
class IncidentPhotoImage extends ConsumerWidget {
  const IncidentPhotoImage({
    required this.incident,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    super.key,
  });

  final Incident incident;
  final Widget fallback;
  final BoxFit fit;
  final int? cacheWidth;

  static const _loading = Center(child: CircularProgressIndicator());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = incident.photoUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: fit,
        cacheWidth: cacheWidth,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _loading,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    final path = incident.photoPath;
    if (path == null) return fallback;
    return ref
        .watch(incidentPhotoBytesProvider(path))
        .when(
          data: (bytes) => bytes == null
              ? fallback
              : Image.memory(
                  bytes,
                  fit: fit,
                  cacheWidth: cacheWidth,
                  gaplessPlayback: true,
                ),
          loading: () => _loading,
          error: (_, _) => fallback,
        );
  }
}
