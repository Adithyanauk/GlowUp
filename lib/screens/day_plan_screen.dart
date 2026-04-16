import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'workout_screen.dart';

class DayPlanScreen extends StatelessWidget {
  const DayPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final completedDays = dataService.completedDays;
    final currentDay = dataService.currentDay;

    return Scaffold(
      appBar: AppBar(
        title: const Text('30 Day Challenge'),
      ),
      body: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: 30,
        itemBuilder: (context, index) {
          final day = index + 1;
          final plan = dataService.getDayPlan(day);
          final isCompleted = completedDays.contains(day);
          final isCurrent = day == currentDay;
          final isLocked = day > currentDay;

          if (plan == null) return const SizedBox.shrink();

          // Phase headers
          Widget? phaseHeader;
          if (day == 1) {
            phaseHeader = _phaseHeader(
                'Phase 1: Light', 'Days 1–10', AppColors.success);
          } else if (day == 11) {
            phaseHeader = _phaseHeader(
                'Phase 2: Medium', 'Days 11–20', AppColors.warning);
          } else if (day == 21) {
            phaseHeader = _phaseHeader(
                'Phase 3: Advanced', 'Days 21–30', AppColors.primary);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (phaseHeader != null) ...[
                phaseHeader,
                const SizedBox(height: 12),
              ],
              GestureDetector(
                onTap: isLocked
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkoutScreen(day: day),
                          ),
                        );
                      },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appCardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: isCurrent
                        ? Border.all(color: AppColors.primary, width: 2)
                        : Border.all(color: context.appDivider),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.success
                              : isCurrent
                                  ? AppColors.primary
                                  : context.appSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 22)
                              : isLocked
                                  ? Icon(Icons.lock_outline_rounded,
                                      color: context.appTextHint, size: 20)
                                  : Text(
                                      '$day',
                                      style: TextStyle(
                                        color: isCurrent
                                            ? Colors.white
                                            : context.appTextSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Day $day',
                              style: TextStyle(
                                color: isLocked
                                    ? context.appTextHint
                                    : context.appTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${plan.totalExercises} exercises • ${plan.phaseLabel}',
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (isCompleted)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      // Banner ad at the very bottom of the screen
      bottomNavigationBar: const BannerAdWidget(),
    );
  }

  Widget _phaseHeader(String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Builder(
                builder: (context) => Text(
                  subtitle,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
