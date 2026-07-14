import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../services/ph_analyzer.dart';
import 'roi_selector.dart' show SelectionMode;
import 'result_screen.dart';

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  SelectionMode _currentMode = SelectionMode.dye;

  // Normalized coordinates (0..1) relative to camera preview
  Rect _dyeNormRect = const Rect.fromLTRB(0.35, 0.35, 0.65, 0.45);
  Rect _bgNormRect = const Rect.fromLTRB(0.30, 0.55, 0.70, 0.70);

  Offset? _dragStartNorm;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'No available camera found on this device.';
          });
        }
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
      if (_currentMode == SelectionMode.dye) {
        _dyeNormRect = Rect.fromPoints(normPoint, normPoint);
      } else {
        _bgNormRect = Rect.fromPoints(normPoint, normPoint);
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
      if (_currentMode == SelectionMode.dye) {
        _dyeNormRect = Rect.fromPoints(_dragStartNorm!, normPoint);
      } else {
        _bgNormRect = Rect.fromPoints(_dragStartNorm!, normPoint);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      _dragStartNorm = null;
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        _isCapturing)
      return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final XFile file = await _controller!.takePicture();
      final String path = file.path;

      // Check if file exists and is accessible
      final fileHandle = File(path);
      if (!await fileHandle.exists()) {
        throw Exception('Captured image file does not exist at path: $path');
      }

      // Load image dimensions directly without using isolate for now
      // (We'll handle the heavy processing in ResultScreen)
      final image = PHAnalyzer.loadAndNormalizeImage(path);
      final double imgW = image.width.toDouble();
      final double imgH = image.height.toDouble();

      final Rect dyeImageRect = Rect.fromLTRB(
        (_dyeNormRect.left * imgW).clamp(0.0, imgW),
        (_dyeNormRect.top * imgH).clamp(0.0, imgH),
        (_dyeNormRect.right * imgW).clamp(0.0, imgW),
        (_dyeNormRect.bottom * imgH).clamp(0.0, imgH),
      );

      final Rect bgImageRect = Rect.fromLTRB(
        (_bgNormRect.left * imgW).clamp(0.0, imgW),
        (_bgNormRect.top * imgH).clamp(0.0, imgH),
        (_bgNormRect.right * imgW).clamp(0.0, imgW),
        (_bgNormRect.bottom * imgH).clamp(0.0, imgH),
      );

      if (dyeImageRect.width < 2 ||
          dyeImageRect.height < 2 ||
          bgImageRect.width < 2 ||
          bgImageRect.height < 2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Selected ROI boxes are too small. Please draw larger boxes.',
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
              imagePath: path,
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

    if (!_isCameraInitialized || _controller == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live Camera')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Starting high-resolution camera...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Camera ROI Overlay'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHelpBanner(theme),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0 / _controller!.value.aspectRatio,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final Size canvasSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    return GestureDetector(
                      onPanStart: (details) => _onPanStart(details, canvasSize),
                      onPanUpdate: (details) =>
                          _onPanUpdate(details, canvasSize),
                      onPanEnd: _onPanEnd,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CameraPreview(_controller!),
                          CustomPaint(
                            painter: _LiveROIPainter(
                              dyeNormRect: _dyeNormRect,
                              bgNormRect: _bgNormRect,
                              activeMode: _currentMode,
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

  Widget _buildHelpBanner(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Row(
        children: [
          Icon(Icons.touch_app, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Drag directly over camera feed to adjust ROI. Tap Switch ROI to toggle Red / Blue boxes.',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentMode = _currentMode == SelectionMode.dye
                            ? SelectionMode.reference
                            : SelectionMode.dye;
                      });
                    },
                    icon: Icon(
                      Icons.swap_horiz,
                      color: _currentMode == SelectionMode.dye
                          ? Colors.white
                          : Colors.white,
                    ),
                    label: Text(
                      _currentMode == SelectionMode.dye
                          ? 'Switch ROI: Active [Red Dye Pad]'
                          : 'Switch ROI: Active [Blue Reference]',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: _currentMode == SelectionMode.dye
                          ? Colors.redAccent
                          : Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
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
          ],
        ),
      ),
    );
  }
}

class _LiveROIPainter extends CustomPainter {
  final Rect dyeNormRect;
  final Rect bgNormRect;
  final SelectionMode activeMode;

  _LiveROIPainter({
    required this.dyeNormRect,
    required this.bgNormRect,
    required this.activeMode,
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

    final bgRect = Rect.fromLTRB(
      bgNormRect.left * size.width,
      bgNormRect.top * size.height,
      bgNormRect.right * size.width,
      bgNormRect.bottom * size.height,
    );

    // Paint Dye Pad (Red)
    final redBorder = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = activeMode == SelectionMode.dye ? 3.5 : 2.0;
    final redFill = Paint()
      ..color = Colors.redAccent.withValues(
        alpha: activeMode == SelectionMode.dye ? 0.3 : 0.15,
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(dyeRect, redFill);
    canvas.drawRect(dyeRect, redBorder);
    _drawBadge(canvas, 'Dye Pad (Red)', dyeRect.topLeft, Colors.redAccent);

    // Paint Reference Paper (Blue)
    final blueBorder = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = activeMode == SelectionMode.reference ? 3.5 : 2.0;
    final blueFill = Paint()
      ..color = Colors.blueAccent.withValues(
        alpha: activeMode == SelectionMode.reference ? 0.3 : 0.15,
      )
      ..style = PaintingStyle.fill;

    canvas.drawRect(bgRect, blueFill);
    canvas.drawRect(bgRect, blueBorder);
    _drawBadge(canvas, 'Reference (Blue)', bgRect.topLeft, Colors.blueAccent);
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
        oldDelegate.activeMode != activeMode;
  }
}
