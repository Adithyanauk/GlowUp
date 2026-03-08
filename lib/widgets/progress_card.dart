import 'package:flutter/material.dart';
import '../config/theme.dart';

class ProgressCard extends StatelessWidget {
  final double progress;
  final int completedDays;
  final int totalDays;

  const ProgressCard({
    super.key,
    required this.progress,
    required this.completedDays,
    this.totalDays = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Progress',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$completedDays / $totalDays days',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: context.appSurface,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${(progress * 100).toStringAsFixed(0)}% Complete',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
