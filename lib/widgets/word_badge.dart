import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../domain/models/enums.dart';

class WordBadge extends StatelessWidget {
  final JlptLevel level;

  const WordBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final label = level == JlptLevel.n3 ? 'N3' : 'N2';
    final badgeColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }
}
