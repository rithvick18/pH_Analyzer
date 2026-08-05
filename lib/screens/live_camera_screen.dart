import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ph_analyzer.dart';
import '../services/strip_validator_service.dart';
import '../theme/lab_theme.dart';
import 'result_screen.dart';

Map<String, int> _readCameraImageDimensions(String imagePath) {
  final image = PHAnalyzer.loadAndNormalizeImage(imagePath);
  return {'width': image.width, 'height': image.height};
}

/// Crops [dyeRect] from the image at [imagePath] and returns JPEG bytes.
Uint8List? _cropDyeRoiBytes(Map<String, dynamic> params) {
  try {
    final String path = params['imagePath'] as String;
    final double left = (params['left'] as num).toDouble();
    final double top = (params['top'] as num).toDouble();
    final double width = (params['width'] as num).toDouble();
    final double height = (params['height'] as num).toDouble();

    final fullImage = PHAnalyzer.loadAndNormalizeImage(path);
    final int x = left.floor().clamp(0, fullImage.width - 1);
    final int y = top.floor().clamp(0, fullImage.height - 1);
    final int w = width.ceil().clamp(1, fullImage.width - x);
    final int h = height.ceil().clamp(1, fullImage.height - y);

    final crop = img.copyCrop(fullImage, x: x, y: y, width: w, height: h);
    return Uint8List.fromList(img.encodeJpg(crop, quality: 85));
  } catch (_) {
    return null;
  }
}

enum LiveSelectionMode { dye, reference }

class LiveCameraScreen extends StatefulWidget {
  const LiveCameraScreen({super.key});

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;
  String? _mockImagePath;
  String? _galleryImagePath;

  FlashMode _flashMode = FlashMode.off;
  Offset? _focusTapPosition;

  // Zoom management
  double _currentZoom = 1.5;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  double _baseZoom = 1.5;

  // Exposure management
  double _currentExposureOffset = 0.0;
  double _minExposureOffset = -2.0;
  double _maxExposureOffset = 2.0;
  double _exposureStepSize = 0.5;
  bool _showExposureSlider = false;

  bool _useReferenceImage = false; // Toggle to switch feed to assets/Reference.jpeg
  bool _enableManualReference = false;
  LiveSelectionMode _currentMode = LiveSelectionMode.dye;

  // Normalized coordinates (0..1) relative to camera preview
  Rect _dyeNormRect = const Rect.fromLTRB(0.35, 0.35, 0.65, 0.45);
  Rect _bgNormRect = const Rect.fromLTRB(0.35, 0.55, 0.65, 0.65);

  Offset? _dragStartNorm;

  // Pulse animation for Dye Pad ROI box
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );

    final bool isWidgetTest = WidgetsBinding
        .instance.runtimeType
        .toString()
        .contains('TestWidgetsFlutterBinding');
    if (!isWidgetTest) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 0.5;
    }

    _initCameraHardware();
  }

  @override
  void dispose() {
    _pulseController.dispose();
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

          try {
            _minZoom = await controller.getMinZoomLevel();
            _maxZoom = await controller.getMaxZoomLevel();
            _currentZoom = 1.5.clamp(_minZoom, _maxZoom);
            await controller.setZoomLevel(_currentZoom);
          } catch (_) {}

          try {
            _minExposureOffset = await controller.getMinExposureOffset();
            _maxExposureOffset = await controller.getMaxExposureOffset();
            _exposureStepSize = await controller.getExposureOffsetStepSize();
            if (_exposureStepSize <= 0) _exposureStepSize = 0.5;
            _currentExposureOffset = 0.0.clamp(_minExposureOffset, _maxExposureOffset);
            await controller.setExposureOffset(_currentExposureOffset);
          } catch (_) {}

          if (mounted) {
            setState(() {
              _cameraController = controller;
              _isCameraReady = true;
              _isInitialized = true;
            });
          }
          await _resetCameraExposure();
          await _prepareMockImage();
          return;
        }
      }
    } catch (_) {}
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

  void _onPanStartFromFocal(Offset focalPoint, Size canvasSize) {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;
    final normX = (focalPoint.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (focalPoint.dy / canvasSize.height).clamp(0.0, 1.0);
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

  void _onPanUpdateFromFocal(Offset focalPoint, Size canvasSize) {
    if (_dragStartNorm == null ||
        canvasSize.width <= 0 ||
        canvasSize.height <= 0) {
      return;
    }
    final normX = (focalPoint.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (focalPoint.dy / canvasSize.height).clamp(0.0, 1.0);
    final normPoint = Offset(normX, normY);

    setState(() {
      if (_enableManualReference && _currentMode == LiveSelectionMode.reference) {
        _bgNormRect = Rect.fromPoints(_dragStartNorm!, normPoint);
      } else {
        _dyeNormRect = Rect.fromPoints(_dragStartNorm!, normPoint);
      }
    });
  }

  void _onPanEnd() {
    setState(() {
      _dragStartNorm = null;
    });
  }

  Future<void> _setZoomLevel(double level) async {
    final targetZoom = level.clamp(_minZoom, _maxZoom);
    if ((targetZoom - _currentZoom).abs() > 0.01) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentZoom = targetZoom;
      });
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          await _cameraController!.setZoomLevel(targetZoom);
        } catch (_) {}
      }
    }
  }

  Future<void> _setExposureOffset(double offset) async {
    final targetOffset = offset.clamp(_minExposureOffset, _maxExposureOffset);
    if ((targetOffset - _currentExposureOffset).abs() > 0.01) {
      HapticFeedback.lightImpact();
      setState(() {
        _currentExposureOffset = targetOffset;
      });
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          await _cameraController!.setExposureOffset(targetOffset);
        } catch (_) {}
      }
    }
  }

  Future<void> _resetCameraExposure() async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _focusTapPosition = null;
      });
    }
  }

  Future<void> _onTapToFocus(TapUpDetails details, Size canvasSize) async {
    if (canvasSize.width <= 0 || canvasSize.height <= 0) return;

    final normX = (details.localPosition.dx / canvasSize.width).clamp(0.0, 1.0);
    final normY = (details.localPosition.dy / canvasSize.height).clamp(0.0, 1.0);
    final point = Offset(normX, normY);

    HapticFeedback.lightImpact();

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

  Future<void> _cycleFlashMode() async {
    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
      default:
        nextMode = FlashMode.off;
        break;
    }
    HapticFeedback.lightImpact();
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.setFlashMode(nextMode);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _flashMode = nextMode;
      });
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.torch:
        return Icons.flash_on;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.off:
      default:
        return Icons.flash_off;
    }
  }

  String _getFlashTooltip() {
    switch (_flashMode) {
      case FlashMode.torch:
        return 'Flash Torch';
      case FlashMode.auto:
        return 'Flash Auto';
      case FlashMode.off:
      default:
        return 'Flash Off';
    }
  }

  Color _getFlashIconColor() {
    switch (_flashMode) {
      case FlashMode.torch:
        return Colors.amber;
      case FlashMode.auto:
        return Colors.amberAccent;
      case FlashMode.off:
      default:
        return Colors.white70;
    }
  }

  Future<void> _pickGalleryImage() async {
    HapticFeedback.lightImpact();
    final picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _galleryImagePath = pickedFile.path;
      });
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_isCapturing) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _isCapturing = true;
    });

    try {
      String imagePath;

      if (_galleryImagePath != null) {
        imagePath = _galleryImagePath!;
      } else {
        final bool useLiveFeed = !_useReferenceImage &&
            _isCameraReady &&
            _cameraController != null &&
            _cameraController!.value.isInitialized;

        if (useLiveFeed) {
          try {
            try {
              await _cameraController!.setExposureMode(ExposureMode.locked);
              await _cameraController!.setFocusMode(FocusMode.locked);
            } catch (_) {}

            final XFile capturedFile = await _cameraController!.takePicture();
            imagePath = capturedFile.path;
          } finally {
            await _resetCameraExposure();
          }
        } else if (_mockImagePath != null) {
          imagePath = _mockImagePath!;
        } else {
          throw Exception('Camera feed / Reference image is not ready.');
        }
      }

      final fileHandle = File(imagePath);
      if (!await fileHandle.exists()) {
        throw Exception(
          'Captured image file does not exist at path: $imagePath',
        );
      }

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

      final bool isOnline = await StripValidatorService.hasInternetConnection();

      if (!isOnline) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No internet available — using CIELAB in manual mode',
              ),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        final Uint8List? dyeCropBytes = await compute(_cropDyeRoiBytes, {
          'imagePath': imagePath,
          'left': dyeImageRect.left,
          'top': dyeImageRect.top,
          'width': dyeImageRect.width,
          'height': dyeImageRect.height,
        });

        if (dyeCropBytes != null) {
          final String geminiApiKey = dotenv.env['GEMINI_API_KEY'] ??
              const String.fromEnvironment(
                'GEMINI_API_KEY',
                defaultValue: '',
              );

          final StripValidationResult validation =
              await StripValidatorService.validate(
            imageBytes: dyeCropBytes,
            apiKey: geminiApiKey,
          );

          if (!validation.isValid && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No test strip detected in ROI box: ${validation.reason}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFD84315),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            return;
          }
        }
      }

      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen(
              imagePath: imagePath,
              dyeRect: dyeImageRect,
              bgRect: bgImageRect,
            ),
          ),
        );
        await _resetCameraExposure();
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
        backgroundColor: LabTheme.bgDark,
        appBar: AppBar(
          backgroundColor: LabTheme.bgDark,
          title: const Text('Live Camera'),
        ),
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
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
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
        backgroundColor: LabTheme.bgDark,
        appBar: AppBar(
          backgroundColor: LabTheme.bgDark,
          title: const Text('Live Camera'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: LabTheme.cyanAccent),
              SizedBox(height: 16),
              Text(
                'Loading camera environment...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final double aspectRatio = _calculatePreviewAspectRatio();

    return Scaffold(
      backgroundColor: LabTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LabTheme.surfaceCard,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Live Camera ROI Overlay',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            key: const Key('gallery_button'),
            tooltip: 'Import from Gallery',
            icon: const Icon(Icons.photo_library, color: Colors.white),
            onPressed: _pickGalleryImage,
          ),
          IconButton(
            key: const Key('torch_toggle'),
            tooltip: _getFlashTooltip(),
            icon: Icon(
              _getFlashIcon(),
              color: _getFlashIconColor(),
            ),
            onPressed: _cycleFlashMode,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: Row(
              children: [
                Text(
                  'Ref Image',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _useReferenceImage
                        ? LabTheme.cyanAccent
                        : Colors.white54,
                  ),
                ),
                Switch(
                  key: const Key('reference_image_toggle'),
                  value: _useReferenceImage,
                  activeThumbColor: LabTheme.cyanAccent,
                  onChanged: (val) {
                    setState(() {
                      _useReferenceImage = val;
                    });
                  },
                ),
                const SizedBox(width: 2),
                Text(
                  'Manual Ref',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _enableManualReference
                        ? LabTheme.cyanAccent
                        : Colors.white54,
                  ),
                ),
                Switch(
                  key: const Key('manual_reference_toggle'),
                  value: _enableManualReference,
                  activeThumbColor: LabTheme.cyanAccent,
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
                      onDoubleTap: () {
                        HapticFeedback.lightImpact();
                        _resetCameraExposure();
                      },
                      onScaleStart: (details) {
                        if (details.pointerCount > 1) {
                          _baseZoom = _currentZoom;
                        } else {
                          _onPanStartFromFocal(details.localFocalPoint, canvasSize);
                        }
                      },
                      onScaleUpdate: (details) {
                        if (details.pointerCount > 1 || details.scale != 1.0) {
                          final targetZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
                          _setZoomLevel(targetZoom);
                        } else {
                          _onPanUpdateFromFocal(details.localFocalPoint, canvasSize);
                        }
                      },
                      onScaleEnd: (_) => _onPanEnd(),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _buildPreviewFeed(),
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: _LiveROIPainter(
                                  dyeNormRect: _dyeNormRect,
                                  bgNormRect: _enableManualReference ? _bgNormRect : null,
                                  focusTapNormPoint: _focusTapPosition,
                                  pulseValue: _pulseAnimation.value,
                                ),
                              );
                            },
                          ),
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              blur: 10,
                              borderRadius: 12,
                              color: Colors.black.withValues(alpha: 0.6),
                              borderColor: LabTheme.cyanAccent.withValues(alpha: 0.4),
                              child: Text(
                                '${_currentZoom.toStringAsFixed(1)}x',
                                style: const TextStyle(
                                  color: LabTheme.cyanAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
    if (_galleryImagePath != null) {
      return Image.file(
        File(_galleryImagePath!),
        fit: BoxFit.cover,
      );
    }

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
    if (_galleryImagePath != null) {
      return GlassContainer(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        borderRadius: 12,
        color: LabTheme.surfaceCard.withValues(alpha: 0.8),
        borderColor: LabTheme.cyanAccent.withValues(alpha: 0.4),
        child: Row(
          children: [
            const Icon(
              Icons.photo_library,
              size: 20,
              color: LabTheme.cyanAccent,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Gallery Image mode. Position ROI box over dye pad.',
                style: TextStyle(fontSize: 12, color: Colors.white),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.white70),
              tooltip: 'Return to Camera Feed',
              onPressed: () {
                setState(() {
                  _galleryImagePath = null;
                });
              },
            ),
          ],
        ),
      );
    }

    if (_enableManualReference) {
      return GlassContainer(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        borderRadius: 12,
        color: LabTheme.surfaceCard.withValues(alpha: 0.8),
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

    return GlassContainer(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      borderRadius: 12,
      color: LabTheme.surfaceCard.withValues(alpha: 0.8),
      child: Row(
        children: [
          Icon(
            _useReferenceImage ? Icons.image : Icons.camera_alt,
            size: 20,
            color: LabTheme.cyanAccent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _useReferenceImage
                  ? 'Showing reference.jpeg. Position ROI box over dye pad.'
                  : 'Point & shoot camera mode. Drag box over test strip dye pad.',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
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
          color: isSelected ? color.withValues(alpha: 0.25) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : LabTheme.borderDark,
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
                  color: isSelected ? color : Colors.white70,
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

  Widget _buildZoomPills(ThemeData theme) {
    final zoomLevels = [1.0, 1.5, 2.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: zoomLevels.map((zoom) {
        final isSelected = (_currentZoom - zoom).abs() < 0.15;
        final label = '${zoom == zoom.roundToDouble() ? zoom.toInt() : zoom}x';
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: LabTheme.cyanAccent.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => _setZoomLevel(zoom),
              selectedColor: LabTheme.cyanAccent,
              backgroundColor: LabTheme.surfaceElevated.withValues(alpha: 0.8),
              side: BorderSide(
                color: isSelected
                    ? LabTheme.cyanAccent
                    : LabTheme.borderDark,
                width: isSelected ? 1.5 : 1.0,
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? LabTheme.bgDark : Colors.white70,
              ),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExposureControls(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showExposureSlider = !_showExposureSlider;
                });
              },
              icon: Icon(
                Icons.exposure,
                size: 18,
                color: _currentExposureOffset != 0.0
                    ? LabTheme.cyanAccent
                    : Colors.white70,
              ),
              label: Text(
                'EV: ${_currentExposureOffset >= 0 ? '+' : ''}${_currentExposureOffset.toStringAsFixed(1)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _currentExposureOffset != 0.0
                      ? LabTheme.cyanAccent
                      : Colors.white70,
                ),
              ),
            ),
          ],
        ),
        if (_showExposureSlider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                const Icon(Icons.exposure_neg_1, size: 16, color: Colors.white70),
                Expanded(
                  child: Slider(
                    value: _currentExposureOffset.clamp(
                      _minExposureOffset,
                      _maxExposureOffset,
                    ),
                    min: _minExposureOffset,
                    max: _maxExposureOffset,
                    divisions: (_maxExposureOffset - _minExposureOffset) > 0
                        ? ((_maxExposureOffset - _minExposureOffset) /
                                (_exposureStepSize > 0 ? _exposureStepSize : 0.5))
                            .round()
                        : 8,
                    activeColor: LabTheme.cyanAccent,
                    inactiveColor: LabTheme.borderDark,
                    onChanged: (val) => _setExposureOffset(val),
                  ),
                ),
                const Icon(Icons.exposure_plus_1, size: 16, color: Colors.white70),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildControls(ThemeData theme) {
    return SafeArea(
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        padding: const EdgeInsets.all(16.0),
        borderRadius: 24,
        blur: 16,
        color: LabTheme.surfaceCard.withValues(alpha: 0.85),
        borderColor: LabTheme.cyanAccent.withValues(alpha: 0.3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildZoomPills(theme),
            const SizedBox(height: 4),
            _buildExposureControls(theme),
            const SizedBox(height: 12),
            _buildTactileShutter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTactileShutter(ThemeData theme) {
    return GestureDetector(
      onTap: _isCapturing ? null : _captureAndAnalyze,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: _isCapturing
                ? [LabTheme.surfaceElevated, LabTheme.surfaceCard]
                : [
                    LabTheme.cyanAccent,
                    LabTheme.tealAccent,
                  ],
          ),
          boxShadow: [
            BoxShadow(
              color: LabTheme.cyanAccent.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isCapturing
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: LabTheme.cyanAccent,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Capturing & Analyzing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.camera_rounded,
                      color: LabTheme.bgDark,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Capture & Analyze pH',
                      style: TextStyle(
                        color: LabTheme.bgDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
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
  final double pulseValue;

  _LiveROIPainter({
    required this.dyeNormRect,
    this.bgNormRect,
    this.focusTapNormPoint,
    this.pulseValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final dyeRect = Rect.fromLTRB(
      dyeNormRect.left * size.width,
      dyeNormRect.top * size.height,
      dyeNormRect.right * size.width,
      dyeNormRect.bottom * size.height,
    );

    // Animated pulse aura around Dye Pad ROI box
    final double pulseInflation = 3.0 + pulseValue * 6.0;
    final auraRect = dyeRect.inflate(pulseInflation);
    final auraRRect = RRect.fromRectAndRadius(auraRect, const Radius.circular(8));
    final auraPaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: (1.0 - pulseValue) * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(auraRRect, auraPaint);

    // Paint Dye Pad (Red Accent Border)
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

    // Paint Tap-to-Focus indicator
    if (focusTapNormPoint != null) {
      final tapX = focusTapNormPoint!.dx * size.width;
      final tapY = focusTapNormPoint!.dy * size.height;
      final focusBorder = Paint()
        ..color = LabTheme.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final focusCenter = Paint()
        ..color = LabTheme.cyanAccent
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
        oldDelegate.focusTapNormPoint != focusTapNormPoint ||
        oldDelegate.pulseValue != pulseValue;
  }
}
