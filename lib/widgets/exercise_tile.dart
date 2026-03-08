import 'package:flutter/material.dart';
import '../config/theme.dart';

class ExerciseTile extends StatelessWidget {
  final String name;
  final String category;
  final int duration;
  final int reps;
  final String difficulty;
  final VoidCallback? onTap;

  const ExerciseTile({
    super.key,
    required this.name,
    required this.category,
    required this.duration,
    required this.reps,
    required this.difficulty,
    this.onTap,
  });

  Color get _difficultyColor {
    switch (difficulty) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      case 'hard':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  IconData get _categoryIcon {
    return category == 'face'
        ? Icons.face_retouching_natural_rounded
        : Icons.fitness_center_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appDivider),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (category == 'face'
                        ? AppColors.secondary
                        : AppColors.primary)
                    .withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _categoryIcon,
                color: category == 'face'
                    ? AppColors.secondary
                    : AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 14, color: context.appTextHint),
                      const SizedBox(width: 4),
                      Text(
                        '${duration}s',
                        style: TextStyle(
                          color: context.appTextSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (reps > 1) ...[
                        Icon(Icons.repeat_rounded,
                            size: 14, color: context.appTextHint),
                        const SizedBox(width: 4),
                        Text(
                          '$reps reps',
                          style: TextStyle(
                            color: context.appTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _difficultyColor.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                difficulty.toUpperCase(),
                style: TextStyle(
                  color: _difficultyColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
