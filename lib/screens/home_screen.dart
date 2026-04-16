import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../widgets/progress_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/calendar_view.dart';
import 'workout_screen.dart';

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

                    // Leaderboard
                    _buildLeaderboard(),
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

  Widget _buildLeaderboard() {
    // Mock leaderboard data
    final leaderboard = [
      {'rank': 1, 'name': 'Alex R.', 'days': 28, 'streak': 28, 'avatar': '🏆'},
      {'rank': 2, 'name': 'Priya K.', 'days': 25, 'streak': 22, 'avatar': '🥈'},
      {'rank': 3, 'name': 'Marcus D.', 'days': 24, 'streak': 20, 'avatar': '🥉'},
      {'rank': 4, 'name': 'Sofia L.', 'days': 21, 'streak': 18, 'avatar': '💪'},
      {'rank': 5, 'name': 'You', 'days': _dataService.completedDays.length, 'streak': _dataService.currentStreak, 'avatar': '⭐'},
      {'rank': 6, 'name': 'James T.', 'days': 15, 'streak': 10, 'avatar': '🔥'},
      {'rank': 7, 'name': 'Aisha M.', 'days': 12, 'streak': 8, 'avatar': '✨'},
      {'rank': 8, 'name': 'Liam W.', 'days': 10, 'streak': 6, 'avatar': '💫'},
    ];

    // Sort by days completed
    leaderboard.sort((a, b) => (b['days'] as int).compareTo(a['days'] as int));
    // Re-assign ranks after sort
    for (int i = 0; i < leaderboard.length; i++) {
      leaderboard[i]['rank'] = i + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.leaderboard_rounded, color: AppColors.secondary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Leaderboard',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: context.appCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider),
          ),
          child: Column(
            children: [
              // Top 3 podium
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.secondary.withAlpha(15),
                      Colors.transparent,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _podiumItem(leaderboard[1], 60, AppColors.textSecondary),
                    _podiumItem(leaderboard[0], 80, AppColors.secondary),
                    _podiumItem(leaderboard[2], 50, AppColors.warning),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Rest of leaderboard
              ...leaderboard.skip(3).map((entry) => _leaderboardRow(entry)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _podiumItem(Map<String, dynamic> entry, double height, Color color) {
    final isYou = entry['name'] == 'You';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry['avatar'] as String,
          style: const TextStyle(fontSize: 28),
        ),
        const SizedBox(height: 6),
        Text(
          entry['name'] as String,
          style: TextStyle(
            color: isYou ? AppColors.secondary : context.appTextPrimary,
            fontSize: 13,
            fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withAlpha(60), color.withAlpha(25)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '#${entry['rank']}',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '${entry['days']}d',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _leaderboardRow(Map<String, dynamic> entry) {
    final isYou = entry['name'] == 'You';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isYou ? AppColors.secondary.withAlpha(10) : null,
        border: Border(
          bottom: BorderSide(color: context.appDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#${entry['rank']}',
              style: TextStyle(
                color: context.appTextHint,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            entry['avatar'] as String,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['name'] as String,
                  style: TextStyle(
                    color: isYou ? AppColors.secondary : context.appTextPrimary,
                    fontSize: 14,
                    fontWeight: isYou ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                Text(
                  '🔥 ${entry['streak']} streak',
                  style: TextStyle(
                    color: context.appTextHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isYou
                  ? AppColors.secondary.withAlpha(25)
                  : context.appSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${entry['days']} days',
              style: TextStyle(
                color: isYou ? AppColors.secondary : context.appTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
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
