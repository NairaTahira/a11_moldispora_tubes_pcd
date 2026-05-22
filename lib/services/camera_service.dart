import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;

  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        debugPrint('❌ No cameras found');
        return;
      }
      await _initController(_cameras.first);
    } catch (e) {
      debugPrint('❌ Camera init error: $e');
    }
  }

  Future<void> _initController(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.medium, // 480p — good balance for inference speed
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
    _isInitialized = true;
  }

  Future<XFile?> captureImage() async {
    if (!_isInitialized || _controller == null) return null;
    try {
      return await _controller!.takePicture();
    } catch (e) {
      debugPrint('❌ Capture error: $e');
      return null;
    }
  }

  Future<void> startImageStream(Function(CameraImage) onImage) async {
    if (!_isInitialized || _controller == null) return;
    if (_controller!.value.isStreamingImages) return;
    await _controller!.startImageStream(onImage);
  }

  Future<void> stopImageStream() async {
    if (_controller?.value.isStreamingImages ?? false) {
      await _controller!.stopImageStream();
    }
  }

  void dispose() {
    _controller?.dispose();
    _isInitialized = false;
  }
}