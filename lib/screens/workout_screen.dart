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

class _WorkoutScreenState extends State<WorkoutScreen> {
  final DataService _dataService = DataService();
  final VoiceCoachService _voiceCoach = VoiceCoachService();
  late List<Exercise> _exercises;
  late int _restBetween;
  int _currentIndex = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  bool _isResting = false;
  bool _isPaused = false;
  bool _isStarted = false;
  bool _isExerciseTransitioning = false;

  String _currentExercise = '';
  int _repCount = 0;
  bool _isRepInProgress = false;
  String _previousState = 'idle';
  int _holdSeconds = 0;
  String _formStatus = 'Adjust posture';

  @override
  void initState() {
    super.initState();
    _exercises = _dataService.getExercisesForDayWithReps(widget.day);
    final plan = _dataService.getDayPlan(widget.day);
    _restBetween = plan?.restBetween ?? 15;
    if (_exercises.isNotEmpty) {
      _prepareExerciseState(_exercises.first);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voiceCoach.stop();
    super.dispose();
  }

  void _startWorkout() {
    setState(() {
      _isStarted = true;
      _isResting = false;
      _isPaused = false;
      _prepareExerciseState(_exercises[_currentIndex]);
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
          } else {
            _timer?.cancel();
            if (_isResting) {
              _isResting = false;
              _isPaused = false;
              _prepareExerciseState(_exercises[_currentIndex]);
            } else {
              _onExerciseComplete();
            }
          }
        });
      }
    });
  }

  void _onExerciseComplete() {
    if (_isExerciseTransitioning) return;
    _isExerciseTransitioning = true;
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isResting = true;
        _isPaused = false;
        _timeRemaining = _restBetween;
      });
      _startTimer();
    } else {
      _completeWorkout();
    }
    _isExerciseTransitioning = false;
  }

  void _nextExercise() {
    _timer?.cancel();
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isResting = false;
        _isPaused = false;
        _prepareExerciseState(_exercises[_currentIndex]);
      });
    } else {
      _completeWorkout();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _prepareExerciseState(Exercise exercise) {
    _currentExercise = exercise.name;
    _repCount = 0;
    _isRepInProgress = false;
    _previousState = 'idle';
    _holdSeconds = 0;
    _formStatus = 'Adjust posture';
    
    // Announce the new exercise and its voice instructions
    _voiceCoach.speakInstruction("${exercise.name}. ${exercise.voiceInstruction}");
  }

  void _onTrackingSnapshot(TrackingSnapshot snapshot, Exercise exercise) {
    if (!mounted || _isResting) return;

    final repIncreased = snapshot.repCount > _repCount;

    setState(() {
      _currentExercise = snapshot.currentExercise;
      _repCount = snapshot.repCount;
      _isRepInProgress = snapshot.isRepInProgress;
      _previousState = snapshot.previousState;
      _holdSeconds = snapshot.holdSeconds;
      
      if (repIncreased) {
        SystemSound.play(SystemSoundType.click);
        _voiceCoach.speakInstruction(snapshot.repCount.toString());
      } else if (_formStatus != snapshot.statusText && snapshot.statusText != 'Tracking' && snapshot.statusText != 'Adjust posture' && snapshot.statusText != 'Good rep') {
        _voiceCoach.giveFeedback(snapshot.statusText);
      }
      
      _formStatus = snapshot.statusText;
    });

    final isMewing = snapshot.currentExercise.toLowerCase().contains('mewing');
    
    final targetReached = snapshot.isHoldExercise
        ? snapshot.holdSeconds >= (isMewing ? 60 : exercise.duration)
        : snapshot.repCount >= exercise.reps;

    if (targetReached) {
      _onExerciseComplete();
    }
  }

  void _completeWorkout() async {
    _timer?.cancel();
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
              child: Text(
                '${_currentIndex + 1} / ${_exercises.length}',
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
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

  Widget _buildStartView(Exercise exercise) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withAlpha(180)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 56,
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
              '${_exercises.length} exercises • ~18 min',
              style: TextStyle(color: context.appTextSecondary, fontSize: 15),
            ),
            const SizedBox(height: 24),
            // Exercise list preview
            Expanded(
              child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final ex = _exercises[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: context.appCardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: ex.category == 'face'
                                ? AppColors.secondary.withAlpha(30)
                                : AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: ex.category == 'face'
                                    ? AppColors.secondary
                                    : AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ex.name,
                            style: TextStyle(
                              color: context.appTextPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '${ex.duration}s',
                          style: TextStyle(
                            color: context.appTextHint,
                            fontSize: 13,
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
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Start Workout',
                  style: TextStyle(
                    color: Colors.white,
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

  Widget _buildExerciseView(Exercise exercise) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Exercise progress
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _exercises.length,
                    minHeight: 4,
                    backgroundColor: context.appSurface,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.secondary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Exercise category label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: exercise.category == 'face'
                        ? AppColors.secondary.withAlpha(30)
                        : AppColors.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        exercise.category == 'face'
                            ? Icons.face_retouching_natural_rounded
                            : Icons.fitness_center_rounded,
                        size: 16,
                        color: exercise.category == 'face'
                            ? AppColors.secondary
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        exercise.category == 'face'
                            ? 'Face Exercise'
                            : 'Body Exercise',
                        style: TextStyle(
                          color: exercise.category == 'face'
                              ? AppColors.secondary
                              : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Exercise name
                Text(
                  exercise.name,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exercise.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Live camera-based tracking (replaces placeholder)
                ExerciseCameraTracker(
                  exercise: exercise,
                  isPaused: _isPaused,
                  onSnapshot: (snapshot) =>
                      _onTrackingSnapshot(snapshot, exercise),
                ),
                const SizedBox(height: 24),

                _buildRepStatus(exercise),
                const SizedBox(height: 20),

                // Controls
                _buildControls(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRepStatus(Exercise exercise) {
    final isHold =
        exercise.name.toLowerCase() == 'plank' ||
        exercise.name.toLowerCase() == 'wall sit' ||
        exercise.name.toLowerCase().contains('mewing');
        
    final isMewing = exercise.name.toLowerCase().contains('mewing');

    final mainValue = isHold ? '$_holdSeconds s' : '$_repCount';
    final targetText = isHold
        ? 'Target: ${isMewing ? 60 : exercise.duration}s'
        : 'Target: ${exercise.reps} reps';

    return Column(
      children: [
        Text(
          mainValue,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 42,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          targetText,
          style: TextStyle(
            color: context.appTextSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _formStatus,
          style: TextStyle(
            color: _formStatus == 'Good form'
                ? AppColors.success
                : AppColors.warning,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isRepInProgress
              ? 'Phase: $_previousState'
              : 'Tracking: $_currentExercise',
          style: TextStyle(
            color: context.appTextHint,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRestView() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pause_circle_filled_rounded,
                color: AppColors.secondary,
                size: 64,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
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
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 72,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'seconds',
              style: TextStyle(color: AppColors.textHint, fontSize: 16),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: _nextExercise,
              icon: const Icon(Icons.skip_next_rounded),
              label: const Text('Skip Rest'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
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

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Voice instruction button
        _controlButton(
          Icons.volume_up_rounded,
          'Voice',
          AppColors.secondary,
          () {
            final ex = _exercises[_currentIndex];
            _voiceCoach.speakInstruction(ex.voiceInstruction);
          },
        ),
        // Pause/Resume button
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(60),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        // Next button
        _controlButton(
          Icons.skip_next_rounded,
          'Next',
          AppColors.primary,
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
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(50)),
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
            child: const Text(
              'Continue',
              style: TextStyle(color: AppColors.secondary),
            ),
          ),
          TextButton(
            onPressed: () {
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
