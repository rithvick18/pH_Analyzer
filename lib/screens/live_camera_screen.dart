import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../services/ph_analyzer.dart';
import 'result_screen.dart';

Map<String, int> _readCameraImageDimensions(String imagePath) {
  final image = PHAnalyzer.loadAndNormalizeImage(imagePath);
  return {'width': image.width, 'height': image.height};
}

enum LiveSelectionMode { dye, reference }

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;
  String? _mockImagePath;

  bool _isTorchOn = false;
  Offset? _focusTapPosition;

  bool _useReferenceImage = false; // Toggle to switch feed to assets/Reference.jpeg
  bool _enableManualReference = false;
  LiveSelectionMode _currentMode = LiveSelectionMode.dye;

  // Normalized coordinates (0..1) relative to camera preview
  Rect _dyeNormRect = const Rect.fromLTRB(0.35, 0.35, 0.65, 0.45);
  Rect _bgNormRect = const Rect.fromLTRB(0.35, 0.55, 0.65, 0.65);

  Offset? _dragStartNorm;

  @override
  void initState() {
    super.initState();
    _initCameraHardware();
  }

  @override
  void dispose() {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        _cameraController!.setFlashMode(FlashMode.off);
      } catch (_) {}
    }
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCameraHardware() async {
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final cameras = await availableCameras();
        if (cameras.isNotEmpty) {
          final backCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => cameras.first,
          );

          final controller = CameraController(
            backCamera,
            ResolutionPreset.high,
            enableAudio: false,
          );

          await controller.initialize();

          // Set default zoom level for macro distance (~1.5x)
          try {
            final minZoom = await controller.getMinZoomLevel();
            final maxZoom = await controller.getMaxZoomLevel();
            final defaultZoom = 1.5.clamp(minZoom, maxZoom);
            await controller.setZoomLevel(defaultZoom);
          } catch (_) {
            // Zoom level setting ignored if unsupported
          }

          if (mounted) {
            setState(() {
              _cameraController = controller;
              _isCameraReady = true;
              _isInitialized = true;
            });
          }
          await _prepareMockImage();
          return;
        }
      }
    } catch (_) {
      // Fall back to mock reference camera mode when physical camera is unavailable
    }
    await _prepareMockImage();
  }

  Future<void> _prepareMockImage() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetFile = File('${tempDir.path}/mock_reference_camera.jpeg');
      final byteData = await rootBundle.load('assets/Reference.jpeg');
      await targetFile.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );
      if (mounted) {
        setState(() {
          _mockImagePath = targetFile.path;
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mockImagePath = 'assets/Reference.jpeg';
          _isInitialized = true;
        });
      }
    }
  }

  void _onPanStart(DragStartDetails details, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    final normX = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / canvasSize.height).clamp(
      0.0,
      1.0,
    );
    final normPoint = Offset(normX, normY);

    setState(() {
      _dragStartNorm = normPoint;
      if (_enableManualReference && _currentMode == LiveSelectionMode.reference) {
        _bgNormRect = Rect.fromPoints(normPoint, normPoint);
      } else {
        _dyeNormRect = Rect.fromPoints(normPoint, normPoint);
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details, Size canvasSize) {
    if (_dragStartNorm == null ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return;
    }
    final normX = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / canvasSize.height).clamp(
      0.0,
      1.0,
    );
    final normPoint = Offset(normX, normY);

    setState(() {
      if (_enableManualReference && _currentMode == LiveSelectionMode.reference) {
        _bgNormRect = Rect.fromPoints(_dragStartNorm!, normPoint);
      } else {
        _dyeNormRect = Rect.fromPoints(_dragStartNorm!, normPoint);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragStartNorm = null;
    });
  }

  Future<void> _onTapToFocus(TapUpDetails details, Size canvasSize) async {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final normX = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    final point = Offset(normX, normY);

    setState(() {
      _focusTapPosition = point;
    });

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setExposurePoint(point);
      } catch (_) {}
      try {
        await _cameraController!.setFocusPoint(point);
      } catch (_) {}
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
    }
  }

  Future<void> _toggleTorch() async {
    final newTorchState = !_isTorchOn;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setFlashMode(
          newTorchState ? FlashMode.torch : FlashMode.off,
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isTorchOn = newTorchState;
      });
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_isCapturing) {
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      String imagePath;

      final bool useLiveFeed = !_useReferenceImage &&
          _isCameraReady &&
          _cameraController != null &&
          _cameraController!.value.isInitialized;

      if (useLiveFeed) {
        // Point and shoot live camera: lock exposure and focus before capture
        try {
          await _cameraController!.setExposureMode(ExposureMode.locked);
          await _cameraController!.setFocusMode(FocusMode.locked);
        } catch (_) {
          // Ignore if locking focus/exposure is unsupported on hardware/driver
        }

        final XFile capturedFile = await _cameraController!.takePicture();
        imagePath = capturedFile.path;
      } else if (_mockImagePath != null) {
        imagePath = _mockImagePath!;
      } else {
        throw Exception('Camera feed / Reference image is not ready.');
      }

      final fileHandle = File(imagePath);
      if (!await fileHandle.exists()) {
        throw Exception(
          'Captured image file does not exist at path: $imagePath',
        );
      }

      // Get image dimensions in an isolate to avoid blocking the UI
      final imgDimensions = await compute(_readCameraImageDimensions, imagePath);

      final double imgW = (imgDimensions['width'] as int).toDouble();
      final double imgH = (imgDimensions['height'] as int).toDouble();

      final Rect dyeImageRect = Rect.fromLTRB(
        (_dyeNormRect.left * imgW).clamp(0.0, imgW),
        (_dyeNormRect.top * imgH).clamp(0.0, imgH),
        (_dyeNormRect.right * imgW).clamp(0.0, imgW),
        (_dyeNormRect.bottom * imgH).clamp(0.0, imgH),
      );

      final Rect? bgImageRect = _enableManualReference
          ? Rect.fromLTRB(
              (_bgNormRect.left * imgW).clamp(0.0, imgW),
              (_bgNormRect.top * imgH).clamp(0.0, imgH),
              (_bgNormRect.right * imgW).clamp(0.0, imgW),
              (_bgNormRect.bottom * imgH).clamp(0.0, imgH),
            )
          : null;

      if (dyeImageRect.width < 2 || dyeImageRect.height < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dye Pad ROI box is too small. Please draw a larger box.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (_enableManualReference &&
          bgImageRect != null &&
          (bgImageRect.width < 2 || bgImageRect.height < 2)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Reference Paper ROI box is too small. Please draw a larger box.',
              ),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imagePath: imagePath,
              dyeRect: dyeImageRect,
              bgRect: bgImageRect,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Camera')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.videocam_off,
                  color: Colors.redAccent,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Camera')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading camera environment...'),
            ],
          ),
        ),
      );
    }

    final double aspectRatio = _calculatePreviewAspectRatio();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Camera ROI Overlay'),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('torch_toggle'),
            tooltip: _isTorchOn ? 'Torch On' : 'Torch Off',
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: _isTorchOn ? Colors.amber : theme.colorScheme.onSurfaceVariant,
            ),
            onPressed: _toggleTorch,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Row(
              children: [
                Text(
                  'Ref Image',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _useReferenceImage
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Switch(
                  key: const Key('reference_image_toggle'),
                  value: _useReferenceImage,
                  onChanged: (val) {
                    setState(() {
                      _useReferenceImage = val;
                    });
                  },
                ),
                const SizedBox(width: 4),
                Text(
                  'Manual Ref',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _enableManualReference
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Switch(
                  key: const Key('manual_reference_toggle'),
                  value: _enableManualReference,
                  onChanged: (val) {
                    setState(() {
                      _enableManualReference = val;
                      if (!_enableManualReference) {
                        _currentMode = LiveSelectionMode.dye;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHelpBanner(theme),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final Size canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      onTapUp: (details) => _onTapToFocus(details, canvasSize),
                      onPanStart: (details) => _onPanStart(details, canvasSize),
                      onPanUpdate: (details) =>
                          _onPanUpdate(details, canvasSize),
                      onPanEnd: _onPanEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildPreviewFeed(),
                          CustomPaint(
                            painter: _LiveROIPainter(
                              dyeNormRect: _dyeNormRect,
                              bgNormRect: _enableManualReference ? _bgNormRect : null,
                              focusTapNormPoint: _focusTapPosition,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          _buildControls(theme),
        ],
      ),
    );
  }

  double _calculatePreviewAspectRatio() {
    if (!_useReferenceImage &&
        _isCameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      final double rawRatio = _cameraController!.value.aspectRatio;
      final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (isMobile) {
        return rawRatio > 1.0 ? (1.0 / rawRatio) : rawRatio;
      }
      return rawRatio;
    }
    return 1200.0 / 1600.0;
  }

  Widget _buildPreviewFeed() {
    if (!_useReferenceImage &&
        _isCameraReady &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      final camera = _cameraController!;
      final Size previewSize = camera.value.previewSize ?? const Size(1920, 1080);
      final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

      final double nativeW = isMobile ? previewSize.height : previewSize.width;
      final double nativeH = isMobile ? previewSize.width : previewSize.height;

      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: nativeW,
              height: nativeH,
              child: CameraPreview(camera),
            ),
          ),
        ),
      );
    }

    return Image.asset(
      'assets/Reference.jpeg',
      fit: BoxFit.cover,
    );
  }


  Widget _buildHelpBanner(ThemeData theme) {
    if (_enableManualReference) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        child: Row(
          children: [
            Expanded(
              child: _buildModeTab(
                label: 'Dye Pad (Red)',
                color: Colors.redAccent,
                isSelected: _currentMode == LiveSelectionMode.dye,
                onTap: () => setState(() => _currentMode = LiveSelectionMode.dye),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModeTab(
                label: 'Reference (Blue)',
                color: Colors.blueAccent,
                isSelected: _currentMode == LiveSelectionMode.reference,
                onTap: () => setState(() => _currentMode = LiveSelectionMode.reference),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(
            _useReferenceImage ? Icons.image : Icons.camera_alt,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _useReferenceImage
                  ? 'Showing reference.jpeg. Position ROI box over dye pad.'
                  : 'Point & shoot camera mode. Drag box over test strip dye pad.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String label,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : null,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _isCapturing ? null : _captureAndAnalyze,
          icon: _isCapturing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.camera),
          label: Text(
            _isCapturing
                ? 'Capturing & Analyzing...'
                : 'Capture & Analyze pH',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveROIPainter extends CustomPainter {
  final Rect dyeNormRect;
  final Rect? bgNormRect;
  final Offset? focusTapNormPoint;

  _LiveROIPainter({
    required this.dyeNormRect,
    this.bgNormRect,
    this.focusTapNormPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Convert normalized (0..1) coords to canvas size
    final dyeRect = Rect.fromLTRB(
      dyeNormRect.left * size.width,
      dyeNormRect.top * size.height,
      dyeNormRect.right * size.width,
      dyeNormRect.bottom * size.height,
    );

    // Paint Dye Pad (Red Accent Border, Transparent Interior)
    final redBorder = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    canvas.drawRect(dyeRect, redBorder);
    _drawBadge(canvas, 'Dye Pad ROI', dyeRect.topLeft, Colors.redAccent);

    // Paint Reference Paper if enabled (Blue Accent)
    if (bgNormRect != null) {
      final bgRect = Rect.fromLTRB(
        bgNormRect!.left * size.width,
        bgNormRect!.top * size.height,
        bgNormRect!.right * size.width,
        bgNormRect!.bottom * size.height,
      );

      final blueBorder = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5;
      final blueFill = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      canvas.drawRect(bgRect, blueFill);
      canvas.drawRect(bgRect, blueBorder);
      _drawBadge(canvas, 'Reference ROI', bgRect.topLeft, Colors.blueAccent);
    }

    // Paint Tap-to-Focus visual indicator if user tapped screen
    if (focusTapNormPoint != null) {
      final tapX = focusTapNormPoint!.dx * size.width;
      final tapY = focusTapNormPoint!.dy * size.height;
      final focusBorder = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final focusCenter = Paint()
        ..color = Colors.amberAccent
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(tapX, tapY), 20, focusBorder);
      canvas.drawCircle(Offset(tapX, tapY), 3, focusCenter);
    }
  }

  void _drawBadge(Canvas canvas, String text, Offset position, Color color) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeRect = Rect.fromLTWH(
      position.dx,
      position.dy - textPainter.height - 6,
      textPainter.width + 10,
      textPainter.height + 4,
    );

    final bgPaint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(badgeRect, const Radius.circular(6)),
      bgPaint,
    );
    textPainter.paint(canvas, Offset(badgeRect.left + 5, badgeRect.top + 2));
  }

  @override
  bool shouldRepaint(covariant _LiveROIPainter oldDelegate) {
    return oldDelegate.dyeNormRect != dyeNormRect ||
        oldDelegate.bgNormRect != bgNormRect ||
        oldDelegate.focusTapNormPoint != focusTapNormPoint;
  }
}
