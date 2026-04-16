import 'dart:math' as math;

import 'mediapipe_bridge_service.dart';

// ─── Exercise mode classification ───
enum ExerciseMode { aiTracked, timerBased, manual }

ExerciseMode getExerciseMode(String name) {
  final n = name.toLowerCase();
  // Timer-based: hold exercises or exercises camera can't track well
  if (n == 'plank' || n == 'wall sit' || n.contains('mewing') ||
      n.contains('tongue suction')) {
    return ExerciseMode.timerBased;
  }
  // All others are AI tracked (front-camera optimized)
  return ExerciseMode.aiTracked;
}

bool isFaceExercise(String name) {
  final n = name.toLowerCase();
  return n.contains('mouth') || n.contains('smile') || n.contains('blink') ||
      n.contains('eyebrow') || n.contains('lip') || n.contains('wink') ||
      n.contains('jaw') || n.contains('chin') || n.contains('fish') ||
      n.contains('tongue') || n.contains('cheek') || n.contains('eye') ||
      n.contains('neck') || n.contains('mewing');
}

class TrackingSnapshot {
  final String currentExercise;
  final int repCount;
  final bool isRepInProgress;
  final String previousState;
  final String statusText;
  final bool isHoldExercise;
  final int holdSeconds;
  final String? guidanceHint;

  const TrackingSnapshot({
    required this.currentExercise,
    required this.repCount,
    required this.isRepInProgress,
    required this.previousState,
    required this.statusText,
    required this.isHoldExercise,
    required this.holdSeconds,
    this.guidanceHint,
  });
}

// ─── Smoothing helper ───
class _SmoothedValue {
  double _value = 0;
  bool _initialized = false;

  double update(double raw, {double alpha = 0.3}) {
    if (!_initialized) {
      _value = raw;
      _initialized = true;
      return _value;
    }
    _value = (1 - alpha) * _value + alpha * raw;
    return _value;
  }

  double get value => _value;
  void reset() { _initialized = false; _value = 0; }
}

// ─── State machine ───
enum _RepPhase { idle, active }

class ExerciseRepCounter {
  String currentExercise = '';
  int repCount = 0;
  _RepPhase _phase = _RepPhase.idle;
  String previousState = 'idle';

  String statusText = 'Get ready';
  bool isHoldExercise = false;
  Duration _holdDuration = Duration.zero;
  String? guidanceHint;

  DateTime? _lastTimestamp;
  DateTime? _lastRepTime;      // cooldown tracking
  bool _leftSideTriggered = false;
  bool _rightSideTriggered = false;
  int _missingFrames = 0;
  int _framesSinceStart = 0;

  // Smoothing for key metrics
  final Map<String, _SmoothedValue> _smoothed = {};

  // Calibration: baseline captured in first 3 seconds
  bool _calibrated = false;
  final Map<String, double> _baseline = {};
  DateTime? _exerciseStartTime;

  // Last valid landmarks for frame buffer (hold for 5 frames)
  List<LandmarkPoint>? _lastValidFace;
  List<LandmarkPoint>? _lastValidPose;
  int _faceHoldFrames = 0;
  int _poseHoldFrames = 0;

  bool get isRepInProgress => _phase == _RepPhase.active;

  double _getSmoothed(String key, double raw) {
    _smoothed.putIfAbsent(key, () => _SmoothedValue());
    return _smoothed[key]!.update(raw);
  }

  void resetForExercise(String exerciseName, {String difficulty = 'medium'}) {
    currentExercise = exerciseName;
    repCount = 0;
    _phase = _RepPhase.idle;
    previousState = 'idle';
    statusText = 'Get ready';
    isHoldExercise = _isHold(exerciseName);
    _holdDuration = Duration.zero;
    guidanceHint = null;
    _lastTimestamp = null;
    _lastRepTime = null;
    _leftSideTriggered = false;
    _rightSideTriggered = false;
    _missingFrames = 0;
    _framesSinceStart = 0;
    _smoothed.clear();
    _calibrated = false;
    _baseline.clear();
    _exerciseStartTime = null;
    _lastValidFace = null;
    _lastValidPose = null;
    _faceHoldFrames = 0;
    _poseHoldFrames = 0;
  }

  TrackingSnapshot update({
    required String exerciseName,
    required List<LandmarkPoint> poseLandmarks,
    required List<LandmarkPoint> faceLandmarks,
    required DateTime timestamp,
    String difficulty = 'medium',
  }) {
    if (currentExercise != exerciseName) {
      resetForExercise(exerciseName, difficulty: difficulty);
    }

    _exerciseStartTime ??= timestamp;
    _framesSinceStart++;

    final dt = _lastTimestamp == null
        ? Duration.zero
        : timestamp.difference(_lastTimestamp!);
    _lastTimestamp = timestamp;

    final normalized = exerciseName.toLowerCase();

    // ── Frame buffer: hold last valid landmarks for 5 frames ──
    if (faceLandmarks.isNotEmpty) {
      _lastValidFace = faceLandmarks;
      _faceHoldFrames = 0;
    } else if (_lastValidFace != null && _faceHoldFrames < 5) {
      faceLandmarks = _lastValidFace!;
      _faceHoldFrames++;
    }

    if (poseLandmarks.isNotEmpty) {
      _lastValidPose = poseLandmarks;
      _poseHoldFrames = 0;
    } else if (_lastValidPose != null && _poseHoldFrames < 5) {
      poseLandmarks = _lastValidPose!;
      _poseHoldFrames++;
    }

    if (isFaceExercise(normalized)) {
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
      guidanceHint: guidanceHint,
    );
  }

  // ════════════════════════════════════════════
  //  FACE EXERCISES
  // ════════════════════════════════════════════
  void _updateFaceExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    guidanceHint = null;

    if (landmarks.isEmpty) {
      _missingFrames++;
      if (_missingFrames > 15) {
        statusText = 'Face not visible';
        guidanceHint = 'Position your face in the camera';
      } else {
        statusText = 'Tracking...';
      }
      return;
    }
    _missingFrames = 0;

    final byId = {for (final point in landmarks) point.id: point};

    double? dist(int a, int b) {
      final p1 = byId[a];
      final p2 = byId[b];
      if (p1 == null || p2 == null) return null;
      return _dist(p1.x, p1.y, p2.x, p2.y);
    }

    // Calibration: first 3 seconds, capture baselines
    final elapsed = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inMilliseconds
        : 0;
    final inCalibration = elapsed < 3000;

    switch (exercise) {
      // 1. Jaw Open-Close / Mouth Open
      case 'jaw open-close':
      case 'jaw open close':
      case 'mouth open':
        final raw = dist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('mouth_v', raw);

        if (inCalibration) {
          _baseline['mouth'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['mouth'] ?? 0.015;
        final open = v > base + 0.012;
        final close = v < base + 0.005;
        _countWithStateMachine(active: open, reset: close);
        break;

      // 2. Smile
      case 'smile':
        final raw = dist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('smile_w', raw);

        if (inCalibration) {
          _baseline['smile'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['smile'] ?? 0.25;
        final wide = v > base + 0.03;
        final neutral = v < base + 0.01;
        _countWithStateMachine(active: wide, reset: neutral);
        break;

      // 3. Blink (EAR — Eye Aspect Ratio)
      case 'blink':
        final leftH = dist(159, 145);
        final rightH = dist(386, 374);
        if (leftH == null || rightH == null) return;
        final avgEar = (leftH + rightH) / 2;
        final v = _getSmoothed('blink', avgEar);

        if (inCalibration) {
          _baseline['blink'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['blink'] ?? 0.025;
        final closed = v < base * 0.5;
        final open = v > base * 0.7;
        _countWithStateMachine(active: closed, reset: open);
        break;

      // 4. Eyebrow Raise
      case 'eyebrow raise':
        final leftBrow = byId[70];
        final leftEye = byId[159];
        final rightBrow = byId[300];
        final rightEye = byId[386];
        if (leftBrow == null || leftEye == null || rightBrow == null || rightEye == null) return;

        final rawDist = ((leftBrow.y - leftEye.y).abs() + (rightBrow.y - rightEye.y).abs()) / 2;
        final v = _getSmoothed('eyebrow', rawDist);

        if (inCalibration) {
          _baseline['eyebrow'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['eyebrow'] ?? 0.04;
        final raised = v > base + 0.008;
        final neutral = v < base + 0.003;
        _countWithStateMachine(active: raised, reset: neutral);
        break;

      // 5. Lip Pucker
      case 'lip pucker':
        final raw = dist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('pucker', raw);

        if (inCalibration) {
          _baseline['pucker'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['pucker'] ?? 0.25;
        final puckered = v < base - 0.025;
        final neutral = v > base - 0.01;
        _countWithStateMachine(active: puckered, reset: neutral);
        break;

      // 6. Left Wink
      case 'left wink':
        final leftH = dist(159, 145);
        final rightH = dist(386, 374);
        if (leftH == null || rightH == null) return;
        final lv = _getSmoothed('lwink_l', leftH);
        final rv = _getSmoothed('lwink_r', rightH);

        if (inCalibration) {
          _baseline['lwink'] = lv;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['lwink'] ?? 0.025;
        final leftClosed = lv < base * 0.5 && rv > base * 0.6;
        final open = lv > base * 0.7;
        _countWithStateMachine(active: leftClosed, reset: open);
        break;

      // 7. Right Wink
      case 'right wink':
        final leftH = dist(159, 145);
        final rightH = dist(386, 374);
        if (leftH == null || rightH == null) return;
        final lv = _getSmoothed('rwink_l', leftH);
        final rv = _getSmoothed('rwink_r', rightH);

        if (inCalibration) {
          _baseline['rwink'] = rv;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['rwink'] ?? 0.025;
        final rightClosed = rv < base * 0.5 && lv > base * 0.6;
        final open = rv > base * 0.7;
        _countWithStateMachine(active: rightClosed, reset: open);
        break;

      // 8. Jaw Shift
      case 'jaw shift':
        final chin = byId[152];
        final nose = byId[1];
        if (chin == null || nose == null) return;
        final rawShift = (chin.x - nose.x);
        final v = _getSmoothed('jawshift', rawShift);

        if (inCalibration) {
          _baseline['jawshift'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['jawshift'] ?? 0;
        final shifted = (v - base).abs() > 0.015;
        final centered = (v - base).abs() < 0.008;
        _countWithStateMachine(active: shifted, reset: centered);
        break;

      // ── Legacy face exercises (kept for backward compatibility) ──
      case 'chin lift':
      case 'neck raise':
        final raw = dist(152, 1);
        if (raw == null) return;
        final v = _getSmoothed('chinlift', raw);
        final up = v > 0.16;
        final neutral = v < 0.17;
        _countWithStateMachine(active: up, reset: neutral);
        break;

      case 'fish face':
        final raw = dist(234, 454);
        if (raw == null) return;
        final v = _getSmoothed('fishface', raw);
        final contracted = v < 0.32;
        final released = v > 0.32;
        _countWithStateMachine(active: contracted, reset: released);
        break;

      case 'jaw resistance':
        final raw = dist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('jawres', raw);
        final open = v > 0.03;
        final close = v < 0.022;
        _countWithStateMachine(active: open, reset: close);
        break;

      case 'cheek lift':
        final leftCheek = byId[205];
        final rightCheek = byId[425];
        final leftEye = byId[159];
        final rightEye = byId[386];
        if (leftCheek == null || rightCheek == null || leftEye == null || rightEye == null) return;
        final leftLift = leftCheek.y < leftEye.y + 0.10;
        final rightLift = rightCheek.y < rightEye.y + 0.10;
        final relax = leftCheek.y > leftEye.y + 0.11 && rightCheek.y > rightEye.y + 0.11;
        _countWithStateMachine(active: leftLift && rightLift, reset: relax);
        break;

      case 'eye widening':
        final leftEyeOpen = dist(159, 145);
        final rightEyeOpen = dist(386, 374);
        if (leftEyeOpen == null || rightEyeOpen == null) return;
        final avg = _getSmoothed('eyewiden', (leftEyeOpen + rightEyeOpen) / 2);
        final widen = avg > 0.025;
        final normal = avg < 0.025;
        _countWithStateMachine(active: widen, reset: normal);
        break;

      case 'mewing':
      case 'tongue suction (mewing)':
      case 'tongue suction':
        final raw = dist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('mewing', raw);
        final good = v < 0.025;
        statusText = good ? 'Good form' : 'Close your mouth';
        _updateHoldTracking(exercise, dt, good);
        break;

      default:
        statusText = 'Tracking';
    }
  }

  // ════════════════════════════════════════════
  //  BODY EXERCISES (Front-view optimized)
  // ════════════════════════════════════════════
  void _updateBodyExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    guidanceHint = null;

    if (landmarks.isEmpty) {
      _missingFrames++;
      if (_missingFrames > 15) {
        statusText = 'Body not visible';
        guidanceHint = 'Step back so your full body is visible';
      } else {
        statusText = 'Tracking...';
      }
      return;
    }

    // Visibility filter: only use landmarks with visibility >= 0.5
    final visible = landmarks.where((l) => l.visibility >= 0.5).toList();
    final visibleRatio = visible.length / landmarks.length;

    if (visibleRatio < 0.4) {
      _missingFrames++;
      statusText = 'Move into frame';
      guidanceHint = 'Step back — full body not visible';
      return;
    }
    _missingFrames = 0;

    final byId = {for (final point in visible) point.id: point};

    // Camera guidance
    final hasUpperBody = byId.containsKey(11) && byId.containsKey(12);
    final hasLowerBody = byId.containsKey(27) || byId.containsKey(28);

    if (!hasUpperBody) {
      guidanceHint = 'Move back — shoulders not visible';
    } else if (!hasLowerBody && !exercise.contains('push')) {
      guidanceHint = 'Step back — legs not visible';
    }

    switch (exercise) {
      // 1. Jumping Jacks (arms primary, legs optional)
      case 'jumping jacks':
        final leftWrist = byId[15];
        final rightWrist = byId[16];
        final leftShoulder = byId[11];
        final rightShoulder = byId[12];

        if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
          statusText = 'Show full arms';
          return;
        }

        // Arms up = wrists above shoulders
        final armsUp = leftWrist.y < leftShoulder.y && rightWrist.y < rightShoulder.y;
        final armsDown = leftWrist.y > leftShoulder.y + 0.08 && rightWrist.y > rightShoulder.y + 0.08;

        _countWithStateMachine(active: armsUp, reset: armsDown);
        break;

      // 2. Squats (knee angle OR hip drop)
      case 'squats':
        // Try knee angle first
        final leftKnee = _safeAngle(byId, 23, 25, 27);
        final rightKnee = _safeAngle(byId, 24, 26, 28);

        if (leftKnee != null || rightKnee != null) {
          final knee = _getSmoothed('squat_knee',
              leftKnee != null && rightKnee != null
                  ? (leftKnee + rightKnee) / 2
                  : (leftKnee ?? rightKnee!));

          final down = knee < 135;   // Very lenient
          final up = knee > 150;
          _countWithStateMachine(active: down, reset: up, peakHint: 'Go lower');
        } else {
          // Fallback: hip drop relative to baseline
          final hip = byId[23] ?? byId[24];
          if (hip != null) {
            final v = _getSmoothed('squat_hip', hip.y);
            if (!_calibrated && _framesSinceStart > 10) {
              _baseline['squat_hip'] = v;
              _calibrated = true;
            }
            final base = _baseline['squat_hip'] ?? v;
            final dropped = v > base + 0.05;
            final risen = v < base + 0.02;
            _countWithStateMachine(active: dropped, reset: risen, peakHint: 'Go lower');
          }
        }
        break;

      // 3. High Knees (alternate legs)
      case 'high knees':
        final leftKnee = byId[25];
        final rightKnee = byId[26];
        final leftHip = byId[23];
        final rightHip = byId[24];

        // Left knee check
        if (leftKnee != null && leftHip != null) {
          final leftUp = leftKnee.y < leftHip.y + 0.02; // lenient
          if (leftUp && !_leftSideTriggered) {
            if (_canCountRep()) {
              repCount++;
              _lastRepTime = DateTime.now();
              _leftSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!leftUp) _leftSideTriggered = false;
        }

        // Right knee check
        if (rightKnee != null && rightHip != null) {
          final rightUp = rightKnee.y < rightHip.y + 0.02;
          if (rightUp && !_rightSideTriggered) {
            if (_canCountRep()) {
              repCount++;
              _lastRepTime = DateTime.now();
              _rightSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!rightUp) _rightSideTriggered = false;
        }

        if (!_leftSideTriggered && !_rightSideTriggered) {
          statusText = 'Lift knees higher';
        }
        break;

      // 4. Arm Raises (Front Raise) — wrist above shoulder
      case 'arm raises':
      case 'front raise':
        final leftWrist = byId[15];
        final rightWrist = byId[16];
        final leftShoulder = byId[11];
        final rightShoulder = byId[12];

        if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) return;

        final armsUp = leftWrist.y < leftShoulder.y - 0.02 && rightWrist.y < rightShoulder.y - 0.02;
        final armsDown = leftWrist.y > leftShoulder.y + 0.1 && rightWrist.y > rightShoulder.y + 0.1;

        _countWithStateMachine(active: armsUp, reset: armsDown, peakHint: 'Raise higher');
        break;

      // 5. Push-ups (front-view adapted: shoulder/head Y movement)
      case 'pushups':
      case 'push-ups':
        // Front-view: track shoulder Y position (goes down and comes up)
        final shoulder = byId[11] ?? byId[12];
        if (shoulder != null) {
          final v = _getSmoothed('pushup_y', shoulder.y);

          if (!_calibrated && _framesSinceStart > 10) {
            _baseline['pushup_y'] = v;
            _calibrated = true;
            statusText = 'Start push-ups';
            return;
          }

          final base = _baseline['pushup_y'] ?? v;
          final down = v > base + 0.04;
          final up = v < base + 0.015;
          _countWithStateMachine(active: down, reset: up, peakHint: 'Go lower');
        } else {
          // Fallback to elbow angle if visible
          final left = _safeAngle(byId, 11, 13, 15);
          final right = _safeAngle(byId, 12, 14, 16);
          if (left != null || right != null) {
            final elbow = _getSmoothed('pushup_elbow',
                left != null && right != null ? (left + right) / 2 : (left ?? right!));
            final down = elbow < 120;
            final up = elbow > 145;
            _countWithStateMachine(active: down, reset: up, peakHint: 'Go lower');
          }
        }
        break;

      // 6. Standing Knee Raises (replaces Mountain Climbers)
      case 'standing knee raises':
      case 'mountain climbers':
        final leftKnee = byId[25];
        final rightKnee = byId[26];
        final leftHip = byId[23];
        final rightHip = byId[24];

        if (leftKnee != null && leftHip != null) {
          final leftUp = leftKnee.y < leftHip.y;
          if (leftUp && !_leftSideTriggered) _leftSideTriggered = true;
          if (!leftUp) _leftSideTriggered = false;
        }

        if (rightKnee != null && rightHip != null) {
          final rightUp = rightKnee.y < rightHip.y;
          if (rightUp && !_rightSideTriggered) _rightSideTriggered = true;
          if (!rightUp) _rightSideTriggered = false;
        }

        if (_leftSideTriggered && _rightSideTriggered) {
          if (_canCountRep()) {
            repCount++;
            _lastRepTime = DateTime.now();
            statusText = 'Good!';
          }
          _leftSideTriggered = false;
          _rightSideTriggered = false;
        } else {
          statusText = 'Drive knees up';
        }
        break;

      // 7. Side Steps (leg distance wide vs close)
      case 'side steps':
        final leftAnkle = byId[27];
        final rightAnkle = byId[28];
        final leftHip = byId[23];
        final rightHip = byId[24];

        if (leftAnkle == null || rightAnkle == null || leftHip == null || rightHip == null) return;

        final legSpread = _getSmoothed('sidestep', _dist(leftAnkle.x, leftAnkle.y, rightAnkle.x, rightAnkle.y));
        final hipW = _dist(leftHip.x, leftHip.y, rightHip.x, rightHip.y);

        final wide = legSpread > hipW * 2.0;
        final closed = legSpread < hipW * 1.3;
        _countWithStateMachine(active: wide, reset: closed);
        break;

      // 8. Burpees (front-view adapted: track shoulder Y)
      case 'burpees':
        final shoulder = byId[11] ?? byId[12];
        if (shoulder != null) {
          final v = _getSmoothed('burpee_y', shoulder.y);
          if (!_calibrated && _framesSinceStart > 10) {
            _baseline['burpee_y'] = v;
            _calibrated = true;
          }
          final base = _baseline['burpee_y'] ?? v;
          final down = v > base + 0.08;
          final up = v < base + 0.02;
          _countWithStateMachine(active: down, reset: up);
        }
        break;

      // Hold exercises
      case 'plank':
      case 'wall sit':
        final shoulder = byId[11];
        final hip = byId[23];
        if (shoulder != null && hip != null) {
          // Simple: is the body relatively straight/in position?
          final good = exercise == 'plank'
              ? _isPlankOk(byId)
              : _isWallSitOk(byId);
          statusText = good ? 'Good form' : 'Adjust posture';
          _updateHoldTracking(exercise, dt, good);
        } else {
          statusText = 'Hold position';
          _updateHoldTracking(exercise, dt, true); // Give benefit of doubt
        }
        break;

      default:
        statusText = 'Tracking';
    }
  }

  // ─── Core state machine with cooldown + hysteresis ───
  void _countWithStateMachine({
    required bool active,
    required bool reset,
    String peakHint = 'Keep going',
    String resetHint = 'Good rep!',
  }) {
    if (active && _phase == _RepPhase.idle) {
      _phase = _RepPhase.active;
      previousState = 'active';
      statusText = peakHint;
      return;
    }

    if (reset && _phase == _RepPhase.active) {
      if (_canCountRep()) {
        repCount++;
        _lastRepTime = DateTime.now();
        statusText = resetHint;
      }
      _phase = _RepPhase.idle;
      previousState = 'idle';
      return;
    }

    if (_phase == _RepPhase.idle) {
      statusText = 'Keep going';
    }
  }

  // 300ms cooldown between reps
  bool _canCountRep() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!).inMilliseconds > 300;
  }

  void _updateHoldTracking(String exercise, Duration dt, bool goodForm) {
    if (goodForm && dt.inMilliseconds > 0) {
      _holdDuration += dt;
    }
  }

  bool _isHold(String exercise) {
    final n = exercise.toLowerCase();
    return n == 'plank' || n == 'wall sit' || n.contains('mewing') || n.contains('tongue suction');
  }

  bool _isPlankOk(Map<int, LandmarkPoint> byId) {
    final shoulder = byId[11];
    final hip = byId[23];
    final ankle = byId[27];
    if (shoulder == null || hip == null) return true; // benefit of doubt
    if (ankle == null) return true;
    final angle = _angleFromPoints(shoulder, hip, ankle);
    return angle > 130; // very lenient
  }

  bool _isWallSitOk(Map<int, LandmarkPoint> byId) {
    final knee = _safeAngle(byId, 23, 25, 27);
    if (knee == null) return true; // benefit of doubt
    return knee > 60 && knee < 130; // very lenient
  }

  double? _safeAngle(Map<int, LandmarkPoint> byId, int a, int b, int c) {
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
