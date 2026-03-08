import 'package:flutter/material.dart';
import '../config/theme.dart';

class CalendarView extends StatelessWidget {
  final Set<int> completedDays;
  final int currentDay;

  const CalendarView({
    super.key,
    required this.completedDays,
    required this.currentDay,
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
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.secondary, size: 22),
              const SizedBox(width: 8),
              Text(
                '30 Day Calendar',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 30,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isCompleted = completedDays.contains(day);
              final isCurrent = day == currentDay;
              final isFuture = day > currentDay;

              return Container(
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.secondary
                      : isCurrent
                          ? AppColors.secondary.withAlpha(40)
                          : context.appSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrent
                      ? Border.all(color: AppColors.secondary, width: 2)
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : Text(
                          '$day',
                          style: TextStyle(
                            color: isFuture
                                ? context.appTextHint
                                : context.appTextPrimary,
                            fontSize: 13,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _legend(context, AppColors.secondary, 'Completed'),
              const SizedBox(width: 16),
              _legend(context, AppColors.secondary.withAlpha(40), 'Today'),
              const SizedBox(width: 16),
              _legend(context, context.appSurface, 'Upcoming'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(BuildContext context, Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: context.appTextSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
