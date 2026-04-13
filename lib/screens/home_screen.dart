import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../widgets/progress_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/calendar_view.dart';
import '../widgets/exercise_tile.dart';
import 'workout_screen.dart';
import 'day_plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();

  @override
  Widget build(BuildContext context) {
    final currentDay = _dataService.currentDay;
    final completedDays = _dataService.completedDays;
    final progress = _dataService.progressPercent;
    final currentStreak = _dataService.currentStreak;
    final bestStreak = _dataService.bestStreak;
    final todayPlan = _dataService.getDayPlan(currentDay);
    final todayExercises = _dataService.getExercisesForDay(currentDay);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Layered header: AppBar + Red Card ──
              _buildLayeredHeader(context, currentDay, todayPlan),
              const SizedBox(height: 20),

              // Everything below gets horizontal padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Streak
                    StreakCard(
                      currentStreak: currentStreak,
                      bestStreak: bestStreak,
                    ),
                    const SizedBox(height: 20),

                    // Progress
                    ProgressCard(
                      progress: progress,
                      completedDays: completedDays.length,
                    ),
                    const SizedBox(height: 20),

                    // Calendar
                    CalendarView(
                      completedDays: completedDays,
                      currentDay: currentDay,
                    ),
                    const SizedBox(height: 24),

                    // Today's Exercises
                    Text(
                      "Today's Exercises",
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...todayExercises.map(
                      (ex) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ExerciseTile(
                          name: ex.name,
                          category: ex.category,
                          duration: ex.duration,
                          reps: ex.reps,
                          difficulty: ex.difficulty,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 30 Day Plan
                    _buildPlanSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the two-layer header: secondary AppBar flowing into the red card.
  Widget _buildLayeredHeader(BuildContext context, int currentDay, dayPlan) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        // ── Layer 1: Secondary background that extends behind the card ──
        Container(
          // This stretches down far enough so the rounded bottom peeks
          // below the red card, creating a "second layer" effect.
          height: topPadding + 400,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(36),
              bottomRight: Radius.circular(36),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.secondaryDark.withAlpha(40),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
        ),

        // ── Layer 2: Content on top ──
        Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Column(
            children: [
              // AppBar row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: TextStyle(
                              color: Colors.black.withAlpha(180),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'GlowUp-Challenge',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(120),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Red card — edge-to-edge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildTodayCard(context, currentDay, dayPlan),
              ),
              const SizedBox(height: 10),
              // Decorative lines below card
              Container(
                width: 50,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(180),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(120),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: 20,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(70),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayCard(BuildContext context, int currentDay, dayPlan) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFD32F2F), Color(0xFF1A1A1A)],
          stops: [0.0, 0.55, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Character image on the right ──
            Positioned(
              right: -10,
              bottom: -10,
              child: Image.asset(
                'assets/images/glowup-humans.png',
                height: 240,
                fit: BoxFit.contain,
              ),
            ),
            // ── Card content on the left ──
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phase tags
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Day $currentDay of 30',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (dayPlan != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withAlpha(50),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dayPlan.phaseLabel,
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Ready to\nGlow?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayPlan != null
                        ? '${dayPlan.totalExercises} exercises • ~18 min'
                        : 'Challenge complete!',
                    style: TextStyle(
                      color: Colors.white.withAlpha(200),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context)
                            .push(
                              MaterialPageRoute(
                                builder: (_) => WorkoutScreen(day: currentDay),
                              ),
                            )
                            .then((_) => setState(() {}));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 22),
                          SizedBox(width: 6),
                          Text(
                            "Start Workout",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '30 Day Challenge',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const DayPlanScreen()),
                );
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildPhaseCard(
          'Phase 1: Light',
          'Day 1–10',
          Icons.spa_rounded,
          AppColors.success,
        ),
        const SizedBox(height: 10),
        _buildPhaseCard(
          'Phase 2: Medium',
          'Day 11–20',
          Icons.fitness_center_rounded,
          AppColors.warning,
        ),
        const SizedBox(height: 10),
        _buildPhaseCard(
          'Phase 3: Advanced',
          'Day 21–30',
          Icons.whatshot_rounded,
          AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildPhaseCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: context.appTextHint),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning ';
    if (hour < 17) return 'Good Afternoon ';
    return 'Good Evening ';
  }
}
