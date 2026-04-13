import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/exercise.dart';
import '../services/exercise_rep_counter.dart';
import '../services/mediapipe_bridge_service.dart';

class ExerciseCameraTracker extends StatefulWidget {
  final Exercise exercise;
  final bool isPaused;
  final ValueChanged<TrackingSnapshot> onSnapshot;

  const ExerciseCameraTracker({
    super.key,
    required this.exercise,
    required this.isPaused,
    required this.onSnapshot,
  });

  @override
  State<ExerciseCameraTracker> createState() => _ExerciseCameraTrackerState();
}

class _ExerciseCameraTrackerState extends State<ExerciseCameraTracker> {
  final MediapipeBridgeService _mediapipeBridge = MediapipeBridgeService();
  final ExerciseRepCounter _repCounter = ExerciseRepCounter();

  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isCameraOff = false;
  String _cameraMessage = 'Camera unavailable';
  int _frameCount = 0;
  late TrackingSnapshot _latestSnapshot;

  @override
  void initState() {
    super.initState();
    _repCounter.resetForExercise(widget.exercise.name, difficulty: widget.exercise.difficulty.toLowerCase());
    _latestSnapshot = TrackingSnapshot(
      currentExercise: widget.exercise.name,
      repCount: 0,
      isRepInProgress: false,
      previousState: 'idle',
      statusText: 'Adjust posture',
      isHoldExercise:
          widget.exercise.name.toLowerCase() == 'plank' ||
          widget.exercise.name.toLowerCase() == 'wall sit',
      holdSeconds: 0,
    );
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant ExerciseCameraTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.name != widget.exercise.name) {
      _repCounter.resetForExercise(widget.exercise.name, difficulty: widget.exercise.difficulty.toLowerCase());
      _latestSnapshot = TrackingSnapshot(
        currentExercise: widget.exercise.name,
        repCount: 0,
        isRepInProgress: false,
        previousState: 'idle',
        statusText: 'Adjust posture',
        isHoldExercise:
            widget.exercise.name.toLowerCase() == 'plank' ||
            widget.exercise.name.toLowerCase() == 'wall sit',
        holdSeconds: 0,
      );
    }
  }

  @override
  void dispose() {
    final cameraController = _controller;
    _controller = null;
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() => _isInitializing = true);
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          front = cam;
          break;
        }
      }

      final selectedCamera = front ?? cameras.firstOrNull;
      if (selectedCamera == null) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _isCameraReady = false;
          });
        }
        return;
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await controller.startImageStream(_onFrame);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _isCameraReady = true;
      });
    } catch (error) {
      if (error is CameraException) {
        final cameraError = error;
        if (cameraError.code == 'CameraAccessDenied') {
          _cameraMessage = 'Camera permission denied';
        } else if (cameraError.code == 'CameraAccessDeniedWithoutPrompt') {
          _cameraMessage = 'Enable camera permission in settings';
        }
      }
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isCameraReady = false;
      });
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!_isCameraReady || _isCameraOff || widget.isPaused || _isProcessing) {
      return;
    }

    _frameCount += 1;
    if (_frameCount % 3 != 0) {
      return;
    }
    
    debugPrint("DEBUG: camera working");

    _isProcessing = true;
    try {
      final bytes = _joinPlanes(image.planes);
      final rotation = _controller?.description.sensorOrientation ?? 0;

      final result = await _mediapipeBridge.processFrame(
        bytes: bytes,
        width: image.width,
        height: image.height,
        rotation: rotation,
        exerciseName: widget.exercise.name,
        useFaceMesh: widget.exercise.category == 'face',
        usePose: widget.exercise.category != 'face',
      );
      
      debugPrint("DEBUG: media pipe detection complete (Face pts: ${result.faceLandmarks.length}, Body pts: ${result.poseLandmarks.length})");

      if (!mounted) return;

      final snapshot = _repCounter.update(
        exerciseName: widget.exercise.name,
        poseLandmarks: result.poseLandmarks,
        faceLandmarks: result.faceLandmarks,
        timestamp: DateTime.now(),
        difficulty: widget.exercise.difficulty.toLowerCase(),
      );

      if (mounted) {
        setState(() {
          _latestSnapshot = snapshot;
        });
      }
      widget.onSnapshot(snapshot);
    } finally {
      _isProcessing = false;
    }
  }

  Uint8List _joinPlanes(List<Plane> planes) {
    final writeBuffer = WriteBuffer();
    for (final plane in planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    return writeBuffer.done().buffer.asUint8List();
  }

  Future<void> _toggleCameraPower() async {
    final controller = _controller;
    if (controller == null) return;

    if (_isCameraOff) {
      try {
        await controller.resumePreview();
      } catch (_) {}
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(_onFrame);
      }
      if (!mounted) return;
      setState(() => _isCameraOff = false);
      return;
    }

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    try {
      await controller.pausePreview();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isCameraOff = true);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _latestSnapshot;

    return Container(
      height: 380,
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(180), width: 2.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: _isInitializing
                ? const Center(child: CircularProgressIndicator())
                : _isCameraReady && _controller != null
                ? (_isCameraOff
                      ? Center(
                          child: Text(
                            'Camera off',
                            style: TextStyle(
                              color: context.appTextSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : _buildMirroredPreview(_controller!))
                : Center(
                    child: Text(
                      _cameraMessage,
                      style: TextStyle(
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(90),
                    Colors.transparent,
                    Colors.black.withAlpha(120),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 12,
            child: Text(
              widget.exercise.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black.withAlpha(90),
              borderRadius: BorderRadius.circular(12),
              child: IconButton(
                onPressed: _toggleCameraPower,
                icon: Icon(
                  _isCameraOff
                      ? Icons.videocam_rounded
                      : Icons.videocam_off_rounded,
                  color: Colors.white,
                ),
                tooltip: _isCameraOff ? 'Camera on' : 'Camera off',
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 12,
            right: 12,
            child: Text(
              snapshot.statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMirroredPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    final width = previewSize?.height ?? 1280;
    final height = previewSize?.width ?? 720;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
