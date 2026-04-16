import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../models/exercise.dart';
import '../services/data_service.dart';
import '../services/exercise_rep_counter.dart';
import '../widgets/exercise_camera_tracker.dart';
import '../services/voice_coach_service.dart';
import 'workout_complete_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final int day;

  const WorkoutScreen({super.key, required this.day});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final VoiceCoachService _voiceCoach = VoiceCoachService();
  late List<Exercise> _exercises;
  late int _restBetween;
  int _currentIndex = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  Timer? _tickTimer;
  bool _isResting = false;
  bool _isPaused = false;
  bool _isStarted = false;
  bool _isExerciseTransitioning = false;

  int _repCount = 0;

  // Timer for timer-based exercises
  int _exerciseTimerSeconds = 0;
  Timer? _exerciseTimer;

  // Tip timer
  Timer? _tipTimer;

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _voiceCoach.resetSession();
    _exercises = _dataService.getExercisesForDayWithReps(widget.day);
    final plan = _dataService.getDayPlan(widget.day);
    _restBetween = plan?.restBetween ?? 15;

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // exercises loaded
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickTimer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _pulseController.dispose();
    _voiceCoach.stop();
    super.dispose();
  }

  ExerciseMode _getMode(Exercise ex) =>
      getExerciseMode(ex.name);

  bool _isFace(Exercise ex) => isFaceExercise(ex.name);

  void _startWorkout() {
    setState(() {
      _isStarted = true;
      _isResting = false;
      _isPaused = false;
    });
    _startExercise(_exercises[_currentIndex], isFirst: true);
  }

  void _startExercise(Exercise exercise, {bool isFirst = false}) {
    _repCount = 0;
    _exerciseTimerSeconds = 0;

    final mode = _getMode(exercise);

    // Start exercise timer for timer-based exercises
    if (mode == ExerciseMode.timerBased) {
      _exerciseTimerSeconds = exercise.duration;
      _startExerciseCountdown(exercise);
    }

    // Start periodic tip timer
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isPaused && !_isResting) {
        _voiceCoach.giveRandomTip();
      }
    });

    // TTS announcement
    _voiceCoach.announceExerciseStart(
      exerciseName: exercise.name,
      voiceInstruction: exercise.voiceInstruction,
      isFace: _isFace(exercise),
      isTimerBased: mode == ExerciseMode.timerBased,
      targetReps: exercise.reps,
      targetDuration: exercise.duration,
      isFirstExercise: isFirst,
    );

    setState(() {});
  }

  void _startExerciseCountdown(Exercise exercise) {
    _exerciseTimer?.cancel();
    _exerciseTimerSeconds = exercise.duration;

    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_exerciseTimerSeconds > 0) {
          _exerciseTimerSeconds--;
          // Tick sound
          SystemSound.play(SystemSoundType.click);
          // TTS countdown
          _voiceCoach.announceTimerCountdown(_exerciseTimerSeconds);
        } else {
          timer.cancel();
          _onExerciseComplete();
        }
      });
    });
  }

  void _startRestTimer() {
    _timer?.cancel();
    _timeRemaining = _restBetween;

    _voiceCoach.announceRest(
      _restBetween,
      _currentIndex < _exercises.length ? _exercises[_currentIndex].name : 'finish',
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
            // Tick sound during rest
            if (_timeRemaining <= 3 && _timeRemaining > 0) {
              SystemSound.play(SystemSoundType.click);
            }
          } else {
            timer.cancel();
            _isResting = false;
            _isPaused = false;
            _startExercise(_exercises[_currentIndex]);
          }
        });
      }
    });
  }

  void _onExerciseComplete() {
    if (_isExerciseTransitioning) return;
    _isExerciseTransitioning = true;
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();

    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isResting = true;
        _isPaused = false;
      });
      _startRestTimer();
    } else {
      _completeWorkout();
    }
    _isExerciseTransitioning = false;
  }

  void _nextExercise() {
    _timer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isResting = false;
        _isPaused = false;
      });
      _startExercise(_exercises[_currentIndex]);
    } else {
      _completeWorkout();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _onTrackingSnapshot(TrackingSnapshot snapshot, Exercise exercise) {
    if (!mounted || _isResting) return;

    final mode = _getMode(exercise);
    if (mode == ExerciseMode.timerBased) {
      // Timer-based exercises are controlled by the countdown timer
      return;
    }

    final repIncreased = snapshot.repCount > _repCount;

    setState(() {
      _repCount = snapshot.repCount;
    });

    if (repIncreased) {
      // Tick sound on rep
      SystemSound.play(SystemSoundType.click);
      _voiceCoach.announceRep(snapshot.repCount, exercise.reps);
    }

    // Check completion
    final targetReached = snapshot.isHoldExercise
        ? snapshot.holdSeconds >= exercise.duration
        : snapshot.repCount >= exercise.reps;

    if (targetReached) {
      _onExerciseComplete();
    }
  }

  void _completeWorkout() async {
    _timer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _voiceCoach.announceComplete();
    await _dataService.completeDay(widget.day);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutCompleteScreen(day: widget.day),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No exercises found for this day.')),
      );
    }

    final exercise = _exercises[_currentIndex];
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text('Day ${widget.day}'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _showExitDialog(),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${_exercises.length}',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: !_isStarted
          ? _buildStartView(exercise)
          : _isResting
          ? _buildRestView()
          : _buildExerciseView(exercise),
    );
  }

  // ═══════════════════════════════════════════
  //  START VIEW
  // ═══════════════════════════════════════════
  Widget _buildStartView(Exercise exercise) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            // Animated play button
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: _startWorkout,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.secondary, AppColors.secondaryDark],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withAlpha(60),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: 56,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Day ${widget.day} Workout',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_exercises.length} exercises',
              style: TextStyle(color: context.appTextSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            // Exercise list
            Expanded(
              child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final ex = _exercises[index];
                  final mode = _getMode(ex);
                  final isF = _isFace(ex);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.appCardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appDivider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isF
                                ? AppColors.secondary.withAlpha(25)
                                : AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Icon(
                              isF ? Icons.face_rounded : Icons.fitness_center_rounded,
                              size: 18,
                              color: isF ? AppColors.secondary : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.name,
                                style: TextStyle(
                                  color: context.appTextPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mode == ExerciseMode.timerBased
                                    ? '${ex.duration}s hold'
                                    : '${ex.reps} reps',
                                style: TextStyle(
                                  color: context.appTextHint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Mode badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: mode == ExerciseMode.aiTracked
                                ? AppColors.secondary.withAlpha(20)
                                : AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            mode == ExerciseMode.aiTracked ? 'AI' : 'Timer',
                            style: TextStyle(
                              color: mode == ExerciseMode.aiTracked
                                  ? AppColors.secondary
                                  : AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Workout',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  EXERCISE VIEW
  // ═══════════════════════════════════════════
  Widget _buildExerciseView(Exercise exercise) {
    final mode = _getMode(exercise);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Progress bar
                _buildProgressBar(),
                const SizedBox(height: 16),
                // Exercise info header
                _buildExerciseHeader(exercise, mode),
                const SizedBox(height: 16),

                // Camera tracker
                ExerciseCameraTracker(
                  exercise: exercise,
                  isPaused: _isPaused,
                  onSnapshot: (snapshot) =>
                      _onTrackingSnapshot(snapshot, exercise),
                ),
                const SizedBox(height: 20),

                // Stats display
                _buildStatsCard(exercise, mode),
                const SizedBox(height: 20),

                // Controls
                _buildControls(mode),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: (_currentIndex + 1) / _exercises.length,
        minHeight: 6,
        backgroundColor: context.appSurface,
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
      ),
    );
  }

  Widget _buildExerciseHeader(Exercise exercise, ExerciseMode mode) {
    return Row(
      children: [
        // Category badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isFace(exercise)
                ? AppColors.secondary.withAlpha(20)
                : AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFace(exercise)
                    ? Icons.face_rounded
                    : Icons.fitness_center_rounded,
                size: 14,
                color: _isFace(exercise)
                    ? AppColors.secondary
                    : AppColors.primary,
              ),
              const SizedBox(width: 6),
              Text(
                _isFace(exercise) ? 'Face' : 'Body',
                style: TextStyle(
                  color: _isFace(exercise)
                      ? AppColors.secondary
                      : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Mode badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: mode == ExerciseMode.aiTracked
                ? Colors.cyanAccent.withAlpha(20)
                : AppColors.warning.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            mode == ExerciseMode.aiTracked ? '🤖 AI Tracked' : '⏱️ Timer',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: mode == ExerciseMode.aiTracked
                  ? Colors.cyanAccent
                  : AppColors.warning,
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildStatsCard(Exercise exercise, ExerciseMode mode) {
    final isTimer = mode == ExerciseMode.timerBased;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        children: [
          // Main stat
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isTimer) ...[
                // Timer countdown
                Text(
                  '$_exerciseTimerSeconds',
                  style: TextStyle(
                    color: _exerciseTimerSeconds <= 5
                        ? AppColors.primary
                        : AppColors.secondary,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    's',
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                // Rep count
                Text(
                  '$_repCount',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    ' / ${exercise.reps}',
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Target info
          Text(
            isTimer
                ? '${exercise.name} • Hold ${exercise.duration}s'
                : '${exercise.name} • ${exercise.reps} reps',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar for current exercise
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isTimer
                  ? (exercise.duration > 0
                      ? 1 - (_exerciseTimerSeconds / exercise.duration)
                      : 0)
                  : (exercise.reps > 0
                      ? _repCount / exercise.reps
                      : 0),
              minHeight: 6,
              backgroundColor: context.appSurface,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  REST VIEW
  // ═══════════════════════════════════════════
  Widget _buildRestView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pause_circle_filled_rounded,
                color: AppColors.secondary,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Rest',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Next: ${_exercises[_currentIndex].name}',
              style: TextStyle(color: context.appTextSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            Text(
              '$_timeRemaining',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 72,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'seconds',
              style: TextStyle(color: context.appTextHint, fontSize: 16),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: () {
                _timer?.cancel();
                setState(() {
                  _isResting = false;
                  _isPaused = false;
                });
                _startExercise(_exercises[_currentIndex]);
              },
              icon: Icon(Icons.skip_next_rounded, color: AppColors.secondary),
              label: Text(
                'Skip Rest',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  CONTROLS
  // ═══════════════════════════════════════════
  Widget _buildControls(ExerciseMode mode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Voice button
        _controlButton(
          Icons.volume_up_rounded,
          'Voice',
          AppColors.secondary,
          () {
            final ex = _exercises[_currentIndex];
            _voiceCoach.speakInstruction(ex.voiceInstruction);
          },
        ),
        // Pause/Resume
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withAlpha(50),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.black,
              size: 36,
            ),
          ),
        ),
        // Next/Done button
        _controlButton(
          Icons.skip_next_rounded,
          'Next',
          AppColors.secondary,
          _nextExercise,
        ),
      ],
    );
  }

  Widget _controlButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quit Workout?',
          style: TextStyle(color: context.appTextPrimary),
        ),
        content: Text(
          'Your progress for this workout will be lost.',
          style: TextStyle(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
          TextButton(
            onPressed: () {
              _voiceCoach.stop();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Quit',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
