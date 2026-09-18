import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'roi_selector.dart';
import '../services/diagnostics.dart';

class LiveCameraScreen extends StatefulWidget {
  final Future<List<CameraDescription>> Function() cameraProvider;
  const LiveCameraScreen({super.key, this.cameraProvider = availableCameras});
  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _camera;
  Future<void> _operations = Future.value();
  int _generation = 0;
  bool _loading = true;
  bool _capturing = false;
  bool _selecting = false;
  bool _demo = false;
  bool _active = true;
  String? _error;
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _exposure = 0;
  double _minExposure = 0;
  double _maxExposure = 0;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  Future<void> _release() async {
    final camera = _camera;
    _camera = null;
    if (camera != null) await _disposeCamera(camera);
  }

  Future<void> _disposeCamera(CameraController camera) async {
    try {
      await camera.dispose();
    } catch (error) {
      Diagnostics.record('camera_dispose', error);
    }
  }

  Future<void> _initialize() {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    return _enqueue(() async {
      CameraController? pending;
      try {
        await _release();
        if (!mounted ||
            generation != _generation ||
            !_active ||
            _demo ||
            _selecting) {
          return;
        }
        if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) {
          throw CameraException(
            'Unsupported',
            'Live capture is supported on Android and iOS.',
          );
        }
        final cameras = await widget.cameraProvider();
        if (cameras.isEmpty) {
          throw CameraException('NoCamera', 'No camera was found.');
        }
        final description = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        pending = CameraController(
          description,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await pending.initialize();
        try {
          await pending.lockCaptureOrientation(DeviceOrientation.portraitUp);
        } on CameraException {
          /* Final regions are confirmed on the EXIF-normalized still image. */
        }
        var minZoom = 1.0;
        var maxZoom = 1.0;
        var minExposure = 0.0;
        var maxExposure = 0.0;
        try {
          final lower = await pending.getMinZoomLevel();
          final upper = await pending.getMaxZoomLevel();
          if (lower.isFinite && upper.isFinite && lower > 0 && upper >= lower) {
            minZoom = lower;
            maxZoom = upper;
          }
        } on CameraException {
          // Optional controls must not prevent still capture.
        }
        try {
          final lower = await pending.getMinExposureOffset();
          final upper = await pending.getMaxExposureOffset();
          if (lower.isFinite && upper.isFinite && upper >= lower) {
            minExposure = lower;
            maxExposure = upper;
          }
        } on CameraException {
          // Some devices do not support manual exposure.
        }
        if (!mounted ||
            generation != _generation ||
            !_active ||
            _demo ||
            _selecting) {
          await _disposeCamera(pending);
          pending = null;
          return;
        }
        _camera = pending;
        pending = null;
        setState(() {
          _loading = false;
          _minZoom = minZoom;
          _maxZoom = maxZoom;
          _zoom = minZoom;
          _minExposure = minExposure;
          _maxExposure = maxExposure;
          _exposure = 0.0.clamp(minExposure, maxExposure);
          _flash = FlashMode.off;
        });
      } on CameraException catch (e) {
        if (mounted && generation == _generation) {
          setState(() {
            _loading = false;
            _error = e.code.contains('Access')
                ? 'Camera permission is unavailable. Enable it in your device settings, then retry, or choose a gallery photo.'
                : 'Camera unavailable. Retry or choose a gallery photo. Demo mode is available separately.';
          });
        }
      } catch (_) {
        if (mounted && generation == _generation) {
          setState(() {
            _loading = false;
            _error =
                'Unable to start the camera. Retry or choose a gallery photo.';
          });
        }
      } finally {
        if (pending != null) await _disposeCamera(pending);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      if (!_demo && !_selecting && !_capturing) _initialize();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _active = false;
      _generation++;
      unawaited(_enqueue(_release));
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    unawaited(_enqueue(_release));
    super.dispose();
  }

  Future<void> _setDemo(bool value) async {
    if (_capturing) return;
    _generation++;
    setState(() {
      _demo = value;
      _error = null;
      _loading = false;
    });
    if (value) {
      await _enqueue(_release);
    } else {
      await _initialize();
    }
  }

  Future<void> _showRegions(
    String path,
    String source,
    DateTime capturedAt,
  ) async {
    if (!mounted) return;
    _selecting = true;
    _generation++;
    await _enqueue(_release);
    if (!mounted) return;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ROISelector(
            imagePath: path,
            source: source,
            capturedAt: capturedAt,
          ),
        ),
      );
    } finally {
      _selecting = false;
      if (mounted && _active && !_demo) await _initialize();
    }
  }

  Future<void> _pickGallery() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file != null) {
        await _showRegions(file.path, 'gallery', DateTime.now());
      }
    } catch (_) {
      _message(
        'Could not open the photo library. Check photo access and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
        if (_active && !_demo && _camera == null) await _initialize();
      }
    }
  }

  Future<void> _capture() async {
    if (_capturing ||
        (!_demo &&
            (_camera == null || !_camera!.value.isInitialized || !_active))) {
      return;
    }
    setState(() => _capturing = true);
    String? ownedPath;
    try {
      final capturedAt = DateTime.now();
      if (_demo) {
        final data = await rootBundle.load('assets/Reference.jpeg');
        final dir = await getTemporaryDirectory();
        final file = File(
          '${dir.path}/ph_demo_${capturedAt.microsecondsSinceEpoch}.jpeg',
        );
        await file.writeAsBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        ownedPath = file.path;
        await _showRegions(ownedPath, 'demo', capturedAt);
      } else {
        final camera = _camera!;
        final photo = await camera.takePicture();
        ownedPath = photo.path;
        await _showRegions(ownedPath, 'camera', capturedAt);
      }
    } catch (_) {
      _message(
        'Capture failed. Retake the photo or choose one from your gallery.',
      );
    } finally {
      if (ownedPath != null) {
        try {
          await File(ownedPath).delete();
        } on FileSystemException {
          /* OS temp cleanup remains available. */
        }
      }
      if (mounted) {
        setState(() => _capturing = false);
        if (_active && !_demo && _camera == null) await _initialize();
      }
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _setZoom(double value) async {
    final camera = _camera;
    if (camera == null || _capturing) return;
    try {
      await camera.setZoomLevel(value);
      if (mounted && identical(camera, _camera)) setState(() => _zoom = value);
    } on CameraException {
      _message('This camera could not change zoom.');
    }
  }

  Future<void> _setExposure(double value) async {
    final camera = _camera;
    if (camera == null || _capturing) return;
    try {
      await camera.setExposureOffset(value);
      if (mounted && identical(camera, _camera)) {
        setState(() => _exposure = value);
      }
    } on CameraException {
      _message('This camera could not change exposure.');
    }
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null || _capturing) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await camera.setFlashMode(next);
      if (mounted && identical(camera, _camera)) setState(() => _flash = next);
    } on CameraException {
      _message('Torch is not available on this camera.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = camera != null && camera.value.isInitialized && _active;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture strip'),
        actions: [
          IconButton(
            key: const Key('gallery_button'),
            tooltip: 'Choose gallery photo',
            onPressed: _capturing ? null : _pickGallery,
            icon: const Icon(Icons.photo_library),
          ),
          IconButton(
            key: const Key('torch_toggle'),
            tooltip: _flash == FlashMode.off
                ? 'Turn torch on'
                : 'Turn torch off',
            onPressed: ready && !_capturing && !_demo ? _toggleFlash : null,
            icon: Icon(
              _flash == FlashMode.off ? Icons.flash_off : Icons.flash_on,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              key: const Key('reference_image_toggle'),
              title: const Text('Demo image'),
              subtitle: const Text(
                'Demo results are labeled and are not sample measurements.',
              ),
              value: _demo,
              onChanged: _capturing ? null : _setDemo,
            ),
            Expanded(
              child: Center(
                child: _demo
                    ? Image.asset(
                        'assets/Reference.jpeg',
                        fit: BoxFit.contain,
                        semanticLabel: 'Bundled demo photograph',
                      )
                    : _loading
                    ? const CircularProgressIndicator()
                    : !ready
                    ? SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_off, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _error ??
                                    'Camera is paused. Return to the app or retry.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _capturing ? null : _initialize,
                                child: const Text('Retry camera'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: 1 / camera.value.aspectRatio,
                        child: LayoutBuilder(
                          builder: (context, constraints) => GestureDetector(
                            onTapUp: (details) async {
                              if (_capturing) return;
                              final point = Offset(
                                (details.localPosition.dx /
                                        constraints.maxWidth)
                                    .clamp(0, 1),
                                (details.localPosition.dy /
                                        constraints.maxHeight)
                                    .clamp(0, 1),
                              );
                              try {
                                await camera.setFocusPoint(point);
                                await camera.setExposurePoint(point);
                              } on CameraException {
                                _message(
                                  'Tap-to-focus is unavailable on this camera.',
                                );
                              }
                            },
                            child: CameraPreview(camera),
                          ),
                        ),
                      ),
              ),
            ),
            if (ready && !_demo) ...[
              if (_maxZoom > _minZoom)
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Text('${_zoom.toStringAsFixed(1)}x'),
                    Expanded(
                      child: Slider(
                        label: 'Zoom ${_zoom.toStringAsFixed(1)} times',
                        value: _zoom,
                        min: _minZoom,
                        max: _maxZoom,
                        onChanged: _capturing ? null : _setZoom,
                      ),
                    ),
                  ],
                ),
              if (_maxExposure > _minExposure)
                Row(
                  children: [
                    const SizedBox(width: 16),
                    const Icon(Icons.exposure),
                    Expanded(
                      child: Slider(
                        label: 'Exposure ${_exposure.toStringAsFixed(1)}',
                        value: _exposure,
                        min: _minExposure,
                        max: _maxExposure,
                        onChanged: _capturing ? null : _setExposure,
                      ),
                    ),
                  ],
                ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Keep the strip and reference paper in even light. After capture, confirm the exact regions on the photo.',
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('capture_button'),
                  onPressed: !_capturing && (_demo || ready) ? _capture : null,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(
                    _capturing
                        ? 'Preparing photo…'
                        : _demo
                        ? 'Use labeled demo'
                        : 'Capture and select regions',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
