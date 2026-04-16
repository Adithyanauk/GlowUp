import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class VoiceCoachService {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  String _lastSpoken = '';
  DateTime? _lastSpokenTime;
  DateTime? _lastTipTime;
  bool _hasGivenSetupHint = false;
  int _tipIndex = 0;

  static final VoiceCoachService _instance = VoiceCoachService._internal();

  factory VoiceCoachService() {
    return _instance;
  }

  VoiceCoachService._internal() {
    _initTts();
  }

  static const List<String> _motivationTips = [
    'Remember to breathe',
    'Keep your core tight',
    'Stay focused',
    'You are doing great',
    'Keep the rhythm',
    'Nice and steady',
    'Control the movement',
    'Almost there, push through',
    'Great energy!',
    'Stay strong',
  ];

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05);

    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });
    
    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  bool get isSpeaking => _isSpeaking;

  /// High-priority: stops current speech and speaks immediately
  Future<void> speakInstruction(String text) async {
    await _flutterTts.stop();
    _lastSpoken = text;
    _lastSpokenTime = DateTime.now();
    await _flutterTts.speak(text);
  }

  /// Announce exercise start — AI tutor style
  Future<void> announceExerciseStart({
    required String exerciseName,
    required String voiceInstruction,
    required bool isFace,
    required bool isTimerBased,
    required int targetReps,
    required int targetDuration,
    required bool isFirstExercise,
  }) async {
    final parts = <String>[];

    // Setup hint on first exercise
    if (isFirstExercise && !_hasGivenSetupHint) {
      _hasGivenSetupHint = true;
      parts.add("Let's begin. Place your phone on a stable surface in a well lit area.");
    }

    parts.add(exerciseName);

    // Body exercise: distance guidance
    if (!isFace) {
      parts.add('Stand about 2 meters from the camera so your full body is visible.');
    }

    // Brief instruction
    parts.add(voiceInstruction);

    // Target info
    if (isTimerBased) {
      parts.add('Hold for $targetDuration seconds.');
    } else {
      parts.add('Do $targetReps reps.');
    }

    await speakInstruction(parts.join('. '));
  }

  /// Speak rep count — just the number, with milestone encouragement
  Future<void> announceRep(int count, int target) async {
    if (_isSpeaking) return;

    String text = '$count';

    // Milestone encouragement
    if (count == target) {
      text = '$count. Done! Great job!';
    } else if (count % 5 == 0 && count > 0) {
      if (count >= target ~/ 2 && count < target) {
        text = '$count. Past halfway, keep it up!';
      } else if (count < target ~/ 2) {
        text = '$count. Great pace!';
      }
    }

    _lastSpoken = text;
    _lastSpokenTime = DateTime.now();
    await _flutterTts.speak(text);
  }

  /// Timer countdown at key intervals
  Future<void> announceTimerCountdown(int secondsRemaining) async {
    if (_isSpeaking) return;

    if (secondsRemaining == 30) {
      await _flutterTts.speak('30 seconds left');
    } else if (secondsRemaining == 10) {
      await _flutterTts.speak('10 seconds');
    } else if (secondsRemaining <= 5 && secondsRemaining > 0) {
      await _flutterTts.speak('$secondsRemaining');
    } else if (secondsRemaining == 0) {
      await _flutterTts.speak('Done!');
    }
  }

  /// Give a random motivational tip (max once per 15s)
  Future<void> giveRandomTip() async {
    if (_isSpeaking) return;

    final now = DateTime.now();
    if (_lastTipTime != null && now.difference(_lastTipTime!).inSeconds < 15) {
      return;
    }

    _lastTipTime = now;
    final tip = _motivationTips[_tipIndex % _motivationTips.length];
    _tipIndex++;
    await _flutterTts.speak(tip);
  }

  /// Low-priority feedback with cooldown
  Future<void> giveFeedback(String text, {Duration cooldown = const Duration(seconds: 4)}) async {
    if (_isSpeaking) return;

    final now = DateTime.now();
    if (_lastSpoken == text && _lastSpokenTime != null) {
      if (now.difference(_lastSpokenTime!) < cooldown) {
        return;
      }
    }

    _lastSpoken = text;
    _lastSpokenTime = now;
    await _flutterTts.speak(text);
  }

  /// Announce rest period
  Future<void> announceRest(int seconds, String nextExerciseName) async {
    await speakInstruction('Rest. $seconds seconds. Next exercise: $nextExerciseName.');
  }

  /// Announce workout complete
  Future<void> announceComplete() async {
    await speakInstruction('Workout complete! Great job today. You are getting stronger every day.');
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  void resetSession() {
    _hasGivenSetupHint = false;
    _tipIndex = 0;
    _lastTipTime = null;
  }
}
