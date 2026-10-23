import 'package:intl/intl.dart';

/// "just now", "5 min ago", "3 hours ago", "2 days ago", then a calendar date.
String formatRelative(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) {
    return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
  return DateFormat.yMMMd().format(time);
}

/// "Oct 15, 2026 at 10:24 AM"
String formatTimestamp(DateTime time) =>
    '${DateFormat.yMMMd().format(time)} at ${DateFormat.jm().format(time)}';
