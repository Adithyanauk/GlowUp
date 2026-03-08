class DayPlan {
  final int day;
  final String phase; // 'light', 'medium', 'advanced'
  final List<String> faceExerciseIds;
  final List<String> bodyExerciseIds;
  final int restBetween; // seconds

  DayPlan({
    required this.day,
    required this.phase,
    required this.faceExerciseIds,
    required this.bodyExerciseIds,
    required this.restBetween,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) {
    return DayPlan(
      day: json['day'] as int,
      phase: json['phase'] as String,
      faceExerciseIds: List<String>.from(json['face']),
      bodyExerciseIds: List<String>.from(json['body']),
      restBetween: json['restBetween'] as int,
    );
  }

  String get phaseLabel {
    switch (phase) {
      case 'light':
        return 'Light Routine';
      case 'medium':
        return 'Medium Routine';
      case 'advanced':
        return 'Advanced Routine';
      default:
        return phase;
    }
  }

  int get totalExercises => faceExerciseIds.length + bodyExerciseIds.length;
}
