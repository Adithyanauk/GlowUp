import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class VoiceCoachService {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  String _lastSpoken = '';
  DateTime? _lastSpokenTime;

  // Singleton pattern for easy global access if needed, or pass around
  static final VoiceCoachService _instance = VoiceCoachService._internal();

  factory VoiceCoachService() {
    return _instance;
  }

  VoiceCoachService._internal() {
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Some implementations provide a wait option so 'speak' awaits completion
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

  Future<void> speakInstruction(String text) async {
    // High priority: interrupt and dictate
    await _flutterTts.stop();
    _lastSpoken = text;
    _lastSpokenTime = DateTime.now();
    await _flutterTts.speak(text);
  }

  Future<void> giveFeedback(String text, {Duration cooldown = const Duration(seconds: 3)}) async {
    // Prevent overlapping and repetitive spam
    if (_isSpeaking) return;

    final now = DateTime.now();
    if (_lastSpoken == text && _lastSpokenTime != null) {
      if (now.difference(_lastSpokenTime!) < cooldown) {
        return; // debounce identical messages
      }
    }

    _lastSpoken = text;
    _lastSpokenTime = now;
    await _flutterTts.speak(text);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
