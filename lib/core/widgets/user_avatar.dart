import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.name, this.radius = 22, super.key});

  final String name;
  final double radius;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        _initials,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }
}
