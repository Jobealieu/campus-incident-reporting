import 'package:flutter/material.dart';

/// A filled button that swaps its label for a spinner while [isLoading].
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: content,
    );
  }
}
