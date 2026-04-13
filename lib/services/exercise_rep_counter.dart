import 'dart:math' as math;
import 'package:flutter/foundation.dart';

import 'mediapipe_bridge_service.dart';

class TrackingSnapshot {
  final String currentExercise;
  final int repCount;
  final bool isRepInProgress;
  final String previousState;
  final String statusText;
  final bool isHoldExercise;
  final int holdSeconds;

  const TrackingSnapshot({
    required this.currentExercise,
    required this.repCount,
    required this.isRepInProgress,
    required this.previousState,
    required this.statusText,
    required this.isHoldExercise,
    required this.holdSeconds,
  });
}

class ExerciseRepCounter {
  String currentExercise = '';
  String currentDifficulty = 'medium';
  int repCount = 0;
  bool isRepInProgress = false;
  String previousState = 'idle';

  String statusText = 'Adjust posture';
  bool isHoldExercise = false;
  Duration _holdDuration = Duration.zero;

  DateTime? _lastTimestamp;
  DateTime? _phaseStartedAt;
  bool _leftSideTriggered = false;
  bool _rightSideTriggered = false;
  int _missingLandmarkStreak = 0;

  void resetForExercise(String exerciseName, {String difficulty = 'medium'}) {
    currentExercise = exerciseName;
    currentDifficulty = difficulty;
    repCount = 0;
    isRepInProgress = false;
    previousState = 'idle';
    statusText = 'Tracking starting...';
    isHoldExercise = _isHold(exerciseName);
    _holdDuration = Duration.zero;
    _lastTimestamp = null;
    _phaseStartedAt = null;
    _leftSideTriggered = false;
    _rightSideTriggered = false;
    _missingLandmarkStreak = 0;
  }

  TrackingSnapshot update({
    required String exerciseName,
    required List<LandmarkPoint> poseLandmarks,
    required List<LandmarkPoint> faceLandmarks,
    required DateTime timestamp,
    String difficulty = 'medium',
  }) {
    if (currentExercise != exerciseName || currentDifficulty != difficulty) {
      resetForExercise(exerciseName, difficulty: difficulty);
    }

    final dt = _lastTimestamp == null
        ? Duration.zero
        : timestamp.difference(_lastTimestamp!);
    _lastTimestamp = timestamp;

    final normalized = exerciseName.toLowerCase();

    if (_isFaceExercise(normalized)) {
      _updateFaceExercise(normalized, faceLandmarks, dt);
    } else {
      _updateBodyExercise(normalized, poseLandmarks, dt);
    }

    return TrackingSnapshot(
      currentExercise: currentExercise,
      repCount: repCount,
      isRepInProgress: isRepInProgress,
      previousState: previousState,
      statusText: statusText,
      isHoldExercise: isHoldExercise,
      holdSeconds: _holdDuration.inSeconds,
    );
  }

  void _updateFaceExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    if (landmarks.isEmpty) {
      debugPrint("DEBUG: media pipe face detecting failed - no landmarks placed");
      _missingLandmarkStreak++;
      statusText = _missingLandmarkStreak < 15
          ? 'Tracking face...'
          : 'Camera active';
      return;
    }

    debugPrint("DEBUG: media pipe face detecting successful - landmarks placed");
    _missingLandmarkStreak = 0;

    final byId = {for (final point in landmarks) point.id: point};

    double? distance(int a, int b) {
      final p1 = byId[a];
      final p2 = byId[b];
      if (p1 == null || p2 == null) return null;
      return _dist(p1.x, p1.y, p2.x, p2.y);
    }

    switch (exercise) {
      case 'chin lift':
      case 'neck raise':
        final chinNose = distance(152, 1);
        if (chinNose == null) return;
        final up = chinNose > 0.19;
        final neutral = chinNose < 0.15;
        _countUpDownCycle(up: up, backToStart: neutral);
        break;

      case 'fish face':
      case 'tongue suction':
        final cheekWidth = distance(234, 454);
        if (cheekWidth == null) return;
        final contracted = cheekWidth < 0.30;
        final released = cheekWidth > 0.34;
        _countUpDownCycle(up: contracted, backToStart: released);
        break;

      case 'jaw open-close':
        final mouthOpen = distance(13, 14);
        if (mouthOpen == null) {
            debugPrint("Jaw: Landmarks missing");
            return;
        }
        final openThreshold = 0.035;
        final closeThreshold = 0.02;
        
        debugPrint("Jaw - Dist: ${mouthOpen.toStringAsFixed(4)} | State: ${isRepInProgress ? 'active' : 'idle'} | Target Open: >$openThreshold, Target Close: <$closeThreshold");
        
        final open = mouthOpen > openThreshold;
        final close = mouthOpen < closeThreshold;
        _countUpDownCycle(up: open, backToStart: close, exerciseName: 'jaw');
        break;

      case 'jaw resistance':
        final mouthGap = distance(13, 14);
        if (mouthGap == null) return;
        final open = mouthGap > 0.04;
        final close = mouthGap < 0.024;

        if (open && !isRepInProgress) {
          isRepInProgress = true;
          previousState = 'open';
          _phaseStartedAt = DateTime.now();
          statusText = 'Controlled open';
        }

        if (close && isRepInProgress) {
          final started = _phaseStartedAt;
          final longEnough =
              started != null &&
              DateTime.now().difference(started).inMilliseconds > 1100;
          if (longEnough) {
            repCount++;
            statusText = 'Good control';
          } else {
            statusText = 'Move slower';
          }
          isRepInProgress = false;
          previousState = 'close';
        }
        break;

      case 'cheek lift':
        final leftCheek = byId[205];
        final rightCheek = byId[425];
        final leftEye = byId[159];
        final rightEye = byId[386];
        if (leftCheek == null ||
            rightCheek == null ||
            leftEye == null ||
            rightEye == null) {
          return;
        }
        final leftLift = leftCheek.y < leftEye.y + 0.09;
        final rightLift = rightCheek.y < rightEye.y + 0.09;
        final relax =
            leftCheek.y > leftEye.y + 0.11 && rightCheek.y > rightEye.y + 0.11;
        _countUpDownCycle(up: leftLift && rightLift, backToStart: relax);
        break;

      case 'eye widening':
        final leftEyeOpen = distance(159, 145);
        final rightEyeOpen = distance(386, 374);
        if (leftEyeOpen == null || rightEyeOpen == null) return;
        final avg = (leftEyeOpen + rightEyeOpen) / 2;
        final widen = avg > 0.03;
        final normal = avg < 0.022;
        _countUpDownCycle(up: widen, backToStart: normal);
        break;

      case 'mewing':
        final mouthGap = distance(13, 14);
        if (mouthGap == null) return;
        final isMouthClosed = mouthGap < 0.025;
        statusText = isMouthClosed ? 'Good form' : 'Keep mouth closed';
        break;

      default:
        statusText = 'Tracking';
    }

    _updateHoldTrackingIfNeeded(exercise, dt, statusText == 'Good form' || statusText == 'Good control');
  }

  void _updateBodyExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    if (landmarks.isEmpty) {
      debugPrint("DEBUG: media pipe body detecting failed - no landmarks placed");
      _missingLandmarkStreak++;
      statusText = _missingLandmarkStreak < 15
          ? 'Tracking body...'
          : 'Camera active';
      return;
    }

    debugPrint("DEBUG: media pipe body detecting successful - landmarks placed");
    _missingLandmarkStreak = 0;

    final byId = {for (final point in landmarks) point.id: point};

    switch (exercise) {
      case 'squats':
        final left = _angle(byId, 23, 25, 27);
        final right = _angle(byId, 24, 26, 28);
        if (left == null || right == null) {
            debugPrint("Squats: Landmarks missing");
            return;
        }
        final knee = (left + right) / 2;
        final isHard = currentDifficulty == 'hard';
        final isEasy = currentDifficulty == 'easy';
        final downThreshold = isHard ? 90 : (isEasy ? 130 : 110);
        final upThreshold = isHard ? 165 : (isEasy ? 150 : 160);
        
        debugPrint("Squats - Angle: ${knee.toStringAsFixed(1)} | State: ${isRepInProgress ? 'active(peaked)' : 'idle'} | Target Down: <$downThreshold, Target Up: >$upThreshold");
        
        final down = knee < downThreshold;
        final up = knee > upThreshold;
        _countUpDownCycle(up: down, backToStart: up, postureHint: 'Go lower', exerciseName: 'squats');
        break;

      case 'pushups':
        final left = _angle(byId, 11, 13, 15);
        final right = _angle(byId, 12, 14, 16);
        if (left == null || right == null) return;
        final elbow = (left + right) / 2;
        final isHard = currentDifficulty == 'hard';
        final isEasy = currentDifficulty == 'easy';
        final downThreshold = isHard ? 90 : (isEasy ? 120 : 100);
        final upThreshold = isHard ? 160 : (isEasy ? 140 : 150);
        final down = elbow < downThreshold;
        final up = elbow > upThreshold;
        _countUpDownCycle(up: down, backToStart: up, postureHint: 'Go lower');
        break;

      case 'jumping jacks':
        final open = _isJackOpen(byId);
        final closed = _isJackClosed(byId);
        if (open == null || closed == null) return;

        if (closed && !isRepInProgress) {
          isRepInProgress = true;
          previousState = 'closed';
          statusText = 'Start';
        } else if (open && isRepInProgress && previousState == 'closed') {
          previousState = 'open';
          statusText = 'Open';
        } else if (closed && isRepInProgress && previousState == 'open') {
          repCount++;
          isRepInProgress = false;
          previousState = 'closed';
          statusText = 'Good form';
        }
        break;

      case 'mountain climbers':
        final leftClose = _kneeToChest(byId, 25, 23) < 0.12;
        final rightClose = _kneeToChest(byId, 26, 24) < 0.12;
        if (leftClose) _leftSideTriggered = true;
        if (rightClose) _rightSideTriggered = true;

        if (_leftSideTriggered && _rightSideTriggered) {
          repCount++;
          _leftSideTriggered = false;
          _rightSideTriggered = false;
          statusText = 'Good form';
        } else {
          statusText = 'Drive knees up';
        }
        break;

      case 'high knees':
        final leftUp = _isKneeAboveHip(byId, 25, 23);
        final rightUp = _isKneeAboveHip(byId, 26, 24);

        if (leftUp && !_leftSideTriggered) {
          repCount++;
          _leftSideTriggered = true;
          statusText = 'Good form';
        }
        if (!leftUp) _leftSideTriggered = false;

        if (rightUp && !_rightSideTriggered) {
          repCount++;
          _rightSideTriggered = true;
          statusText = 'Good form';
        }
        if (!rightUp) _rightSideTriggered = false;
        break;

      case 'burpees':
        final squat = _isSquatLike(byId);
        final plank = _isPlankLineGood(byId);
        final jump = _isJumpPose(byId);

        if (squat && !isRepInProgress) {
          isRepInProgress = true;
          previousState = 'squat';
          statusText = 'Squat';
        } else if (plank && isRepInProgress && previousState == 'squat') {
          previousState = 'plank';
          statusText = 'Plank';
        } else if (jump && isRepInProgress && previousState == 'plank') {
          repCount++;
          isRepInProgress = false;
          previousState = 'jump';
          statusText = 'Good form';
        }
        break;

      case 'plank':
      case 'wall sit':
        final good = exercise == 'plank'
            ? _isPlankLineGood(byId)
            : _isWallSitGood(byId);
        _updateHoldTrackingIfNeeded(exercise, dt, good);
        statusText = good ? 'Good form' : 'Adjust posture';
        break;

      default:
        statusText = 'Tracking';
    }
  }

  void _countUpDownCycle({
    required bool up, 
    required bool backToStart,
    String peakHint = 'Hold control',
    String postureHint = 'Adjust posture',
    String exerciseName = 'exercise',
  }) {
    if (up && !isRepInProgress) {
      debugPrint("[$exerciseName] State Transition: idle -> active (Hit threshold)");
      isRepInProgress = true;
      previousState = 'peak';
      statusText = peakHint;
      return;
    }

    if (backToStart && isRepInProgress) {
      repCount++;
      debugPrint("DEBUG: reps increasing! (Total: $repCount)");
      isRepInProgress = false;
      previousState = 'start';
      statusText = 'Good rep';
      return;
    }

    if (!isRepInProgress) {
      statusText = postureHint;
    } else {
      statusText = 'Keep going';
    }
  }

  void _updateHoldTrackingIfNeeded(
    String exercise,
    Duration dt,
    bool goodForm,
  ) {
    final holdExercise = exercise == 'plank' || exercise == 'wall sit';
    if (!holdExercise) return;

    if (goodForm && dt.inMilliseconds > 0) {
      _holdDuration += dt;
    }
  }

  bool _isFaceExercise(String exercise) {
    return exercise.contains('chin') ||
        exercise.contains('fish') ||
        exercise.contains('jaw') ||
        exercise.contains('tongue') ||
        exercise.contains('cheek') ||
        exercise.contains('eye') ||
        exercise.contains('neck') ||
        exercise.contains('mewing');
  }

  bool _isHold(String exercise) {
    final normalized = exercise.toLowerCase();
    return normalized == 'plank' || normalized == 'wall sit' || normalized.contains('mewing');
  }

  bool _isKneeAboveHip(Map<int, LandmarkPoint> byId, int kneeId, int hipId) {
    final knee = byId[kneeId];
    final hip = byId[hipId];
    if (knee == null || hip == null) return false;
    return knee.y < hip.y;
  }

  double _kneeToChest(Map<int, LandmarkPoint> byId, int kneeId, int hipId) {
    final knee = byId[kneeId];
    final hip = byId[hipId];
    if (knee == null || hip == null) return 999;
    return _dist(knee.x, knee.y, hip.x, hip.y);
  }

  bool? _isJackOpen(Map<int, LandmarkPoint> byId) {
    final leftWrist = byId[15];
    final rightWrist = byId[16];
    final leftAnkle = byId[27];
    final rightAnkle = byId[28];
    final leftShoulder = byId[11];
    final rightShoulder = byId[12];
    final leftHip = byId[23];
    final rightHip = byId[24];

    if ([
      leftWrist,
      rightWrist,
      leftAnkle,
      rightAnkle,
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    ].contains(null)) {
      return null;
    }

    final handSpread = _dist(
      leftWrist!.x,
      leftWrist.y,
      rightWrist!.x,
      rightWrist.y,
    );
    final shoulderSpread = _dist(
      leftShoulder!.x,
      leftShoulder.y,
      rightShoulder!.x,
      rightShoulder.y,
    );
    final legSpread = _dist(
      leftAnkle!.x,
      leftAnkle.y,
      rightAnkle!.x,
      rightAnkle.y,
    );
    final hipSpread = _dist(leftHip!.x, leftHip.y, rightHip!.x, rightHip.y);

    return handSpread > shoulderSpread * 2.1 && legSpread > hipSpread * 1.6;
  }

  bool? _isJackClosed(Map<int, LandmarkPoint> byId) {
    final leftWrist = byId[15];
    final rightWrist = byId[16];
    final leftAnkle = byId[27];
    final rightAnkle = byId[28];
    final leftShoulder = byId[11];
    final rightShoulder = byId[12];
    final leftHip = byId[23];
    final rightHip = byId[24];

    if ([
      leftWrist,
      rightWrist,
      leftAnkle,
      rightAnkle,
      leftShoulder,
      rightShoulder,
      leftHip,
      rightHip,
    ].contains(null)) {
      return null;
    }

    final handSpread = _dist(
      leftWrist!.x,
      leftWrist.y,
      rightWrist!.x,
      rightWrist.y,
    );
    final shoulderSpread = _dist(
      leftShoulder!.x,
      leftShoulder.y,
      rightShoulder!.x,
      rightShoulder.y,
    );
    final legSpread = _dist(
      leftAnkle!.x,
      leftAnkle.y,
      rightAnkle!.x,
      rightAnkle.y,
    );
    final hipSpread = _dist(leftHip!.x, leftHip.y, rightHip!.x, rightHip.y);

    return handSpread < shoulderSpread * 1.2 && legSpread < hipSpread * 1.2;
  }

  bool _isPlankLineGood(Map<int, LandmarkPoint> byId) {
    final shoulder = byId[11];
    final hip = byId[23];
    final ankle = byId[27];
    if (shoulder == null || hip == null || ankle == null) return false;

    final shoulderHipAnkle = _angleFromPoints(shoulder, hip, ankle);
    final isHard = currentDifficulty == 'hard';
    final isEasy = currentDifficulty == 'easy';
    // Easy: 140, Medium: 155, Hard: 165
    final target = isHard ? 165 : (isEasy ? 140 : 155);
    return shoulderHipAnkle > target;
  }

  bool _isWallSitGood(Map<int, LandmarkPoint> byId) {
    final kneeAngle = _angle(byId, 23, 25, 27);
    if (kneeAngle == null) return false;
    
    final isHard = currentDifficulty == 'hard';
    final isEasy = currentDifficulty == 'easy';
    // Easy: 70-115, Medium: 80-105, Hard: 85-95
    final minA = isHard ? 85 : (isEasy ? 70 : 80);
    final maxA = isHard ? 95 : (isEasy ? 115 : 105);
    return kneeAngle > minA && kneeAngle < maxA;
  }

  bool _isSquatLike(Map<int, LandmarkPoint> byId) {
    final knee = _angle(byId, 23, 25, 27);
    return knee != null && knee < 100;
  }

  bool _isJumpPose(Map<int, LandmarkPoint> byId) {
    final leftAnkle = byId[27];
    final rightAnkle = byId[28];
    final leftHip = byId[23];
    final rightHip = byId[24];
    if (leftAnkle == null ||
        rightAnkle == null ||
        leftHip == null ||
        rightHip == null) {
      return false;
    }

    final avgAnkleY = (leftAnkle.y + rightAnkle.y) / 2;
    final avgHipY = (leftHip.y + rightHip.y) / 2;
    return avgAnkleY < avgHipY + 0.35;
  }

  double? _angle(Map<int, LandmarkPoint> byId, int a, int b, int c) {
    final p1 = byId[a];
    final p2 = byId[b];
    final p3 = byId[c];
    if (p1 == null || p2 == null || p3 == null) return null;
    return _angleFromPoints(p1, p2, p3);
  }

  double _angleFromPoints(LandmarkPoint a, LandmarkPoint b, LandmarkPoint c) {
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;

    final dot = abx * cbx + aby * cby;
    final magAb = math.sqrt(abx * abx + aby * aby);
    final magCb = math.sqrt(cbx * cbx + cby * cby);
    if (magAb == 0 || magCb == 0) return 0;

    final cosValue = (dot / (magAb * magCb)).clamp(-1.0, 1.0);
    return math.acos(cosValue) * 180 / math.pi;
  }

  double _dist(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
