import 'package:flutter/material.dart';

extension SnackBarX on BuildContext {
  void showSnack(String message, {bool isError = false}) {
    final scheme = Theme.of(this).colorScheme;
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? scheme.error : null,
        ),
      );
  }

  Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
  }) async {
    final scheme = Theme.of(this).colorScheme;
    final result = await showDialog<bool>(
      context: this,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: isDestructive
                ? TextButton.styleFrom(foregroundColor: scheme.error)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
