import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exercise.dart';
import '../models/day_plan.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  List<Exercise> _faceExercises = [];
  List<Exercise> _bodyExercises = [];
  List<DayPlan> _dailyPlan = [];
  SharedPreferences? _prefs;

  List<Exercise> get faceExercises => _faceExercises;
  List<Exercise> get bodyExercises => _bodyExercises;
  List<DayPlan> get dailyPlan => _dailyPlan;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    final String jsonString =
        await rootBundle.loadString('assets/data/exercise_plan.json');
    final Map<String, dynamic> data = json.decode(jsonString);

    _faceExercises = (data['face_exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList();

    _bodyExercises = (data['body_exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList();

    _dailyPlan = (data['daily_plan'] as List)
        .map((e) => DayPlan.fromJson(e))
        .toList();
  }

  Exercise? getExerciseById(String id) {
    final allExercises = [..._faceExercises, ..._bodyExercises];
    try {
      return allExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  DayPlan? getDayPlan(int day) {
    try {
      return _dailyPlan.firstWhere((d) => d.day == day);
    } catch (_) {
      return null;
    }
  }

  List<Exercise> getExercisesForDay(int day) {
    final plan = getDayPlan(day);
    if (plan == null) return [];

    final exercises = <Exercise>[];
    for (final id in plan.faceExerciseIds) {
      final ex = getExerciseById(id);
      if (ex != null) exercises.add(ex);
    }
    for (final id in plan.bodyExerciseIds) {
      final ex = getExerciseById(id);
      if (ex != null) exercises.add(ex);
    }
    return exercises;
  }

  // --- Persistence ---

  bool get hasCompletedOnboarding =>
      _prefs?.getBool('onboarding_complete') ?? false;

  Future<void> setOnboardingComplete() async {
    await _prefs?.setBool('onboarding_complete', true);
  }

  int get currentDay => _prefs?.getInt('current_day') ?? 1;

  Future<void> setCurrentDay(int day) async {
    await _prefs?.setInt('current_day', day);
  }

  Set<int> get completedDays {
    final list = _prefs?.getStringList('completed_days') ?? [];
    return list.map((e) => int.parse(e)).toSet();
  }

  Future<void> completeDay(int day) async {
    final completed = completedDays;
    completed.add(day);
    await _prefs?.setStringList(
        'completed_days', completed.map((e) => e.toString()).toList());
    // advance to next day
    if (day < 30) {
      await setCurrentDay(day + 1);
    }
    await _updateStreak(day);
  }

  int get currentStreak => _prefs?.getInt('current_streak') ?? 0;
  int get bestStreak => _prefs?.getInt('best_streak') ?? 0;

  Future<void> _updateStreak(int completedDay) async {
    final completed = completedDays;
    int streak = 0;
    for (int d = completedDay; d >= 1; d--) {
      if (completed.contains(d)) {
        streak++;
      } else {
        break;
      }
    }
    await _prefs?.setInt('current_streak', streak);
    if (streak > bestStreak) {
      await _prefs?.setInt('best_streak', streak);
    }
  }

  double get progressPercent => completedDays.length / 30.0;

  // --- Fitness Level ---

  String get fitnessLevel => _prefs?.getString('fitness_level') ?? 'beginner';

  Future<void> setFitnessLevel(String level) async {
    await _prefs?.setString('fitness_level', level);
  }

  bool get hasCompletedPersonalization =>
      _prefs?.getBool('personalization_complete') ?? false;

  Future<void> setPersonalizationComplete() async {
    await _prefs?.setBool('personalization_complete', true);
  }

  // --- Auth state ---

  bool get hasSkippedAuth => _prefs?.getBool('auth_skipped') ?? false;

  Future<void> setAuthSkipped() async {
    await _prefs?.setBool('auth_skipped', true);
  }

  bool get hasCompletedAuth => _prefs?.getBool('auth_complete') ?? false;

  Future<void> setAuthComplete() async {
    await _prefs?.setBool('auth_complete', true);
  }

  Future<void> clearAuthState() async {
    await _prefs?.remove('auth_skipped');
    await _prefs?.remove('auth_complete');
  }

  int get baseReps {
    switch (fitnessLevel) {
      case 'beginner':
        return 10;
      case 'medium':
        return 15;
      case 'advanced':
        return 20;
      default:
        return 10;
    }
  }

  List<Exercise> getExercisesForDayWithReps(int day) {
    final exercises = getExercisesForDay(day);
    final reps = baseReps;
    return exercises.map((ex) => Exercise(
      id: ex.id,
      name: ex.name,
      description: ex.description,
      duration: ex.duration,
      reps: reps,
      image: ex.image,
      category: ex.category,
      difficulty: ex.difficulty,
      voiceInstruction: ex.voiceInstruction,
    )).toList();
  }

  Future<void> clearAllData() async {
    await _prefs?.clear();
  }
}
