import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../services/ph_analyzer.dart';
import 'result_screen.dart';

Future<Map<String, dynamic>> _loadAndNormalizeIsolate(
  Map<String, String> params,
) async {
  final path = params['path']!;
  final tempDirPath = params['tempDirPath']!;
  final image = PHAnalyzer.loadAndNormalizeImage(path);
  final normalizedFile = File(
    '$tempDirPath/normalized_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  final jpgBytes = img.encodeJpg(image, quality: 95);
  await normalizedFile.writeAsBytes(jpgBytes);
  return {
    'bytes': jpgBytes,
    'width': image.width,
    'height': image.height,
    'path': normalizedFile.path,
  };
}

enum SelectionMode { dye, reference }

class ROISelector extends StatefulWidget {
  final String imagePath;

  const ROISelector({super.key, required this.imagePath});

  @override
  State<ROISelector> createState() => _ROISelectorState();
}

class _ROISelectorState extends State<ROISelector> {
  final GlobalKey _canvasKey = GlobalKey();
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _imageBytes;
  int _imgWidth = 0;
  int _imgHeight = 0;
  String _normalizedPath = '';

  SelectionMode _currentMode = SelectionMode.dye;

  Offset? _dyeStart;
  Offset? _dyeEnd;
  Offset? _bgStart;
  Offset? _bgEnd;

  Size _lastCanvasSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadAndNormalize();
  }

  Future<void> _loadAndNormalize() async {
    try {
      final path = widget.imagePath;
      final tempDir = await getTemporaryDirectory();
      final result = await compute(_loadAndNormalizeIsolate, {
        'path': path,
        'tempDirPath': tempDir.path,
      });

      if (mounted) {
        setState(() {
          _imageBytes = result['bytes'] as Uint8List;
          _imgWidth = result['width'] as int;
          _imgHeight = result['height'] as int;
          _normalizedPath = result['path'] as String;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load image: $e';
          _isLoading = false;
        });
      }
    }
  }

  Rect? _getRect(Offset? start, Offset? end) {
    if (start == null || end == null) return null;
    return Rect.fromPoints(start, end);
  }

  _ImageTransform _computeTransform(Size canvasSize) {
    final double imgW = _imgWidth.toDouble();
    final double imgH = _imgHeight.toDouble();
    if (imgW <= 0 || imgH <= 0 || canvasSize.width <= 0 || canvasSize.height <= 0) {
      return _ImageTransform(
        scale: 1,
        offsetX: 0,
        offsetY: 0,
        displayedWidth: canvasSize.width,
        displayedHeight: canvasSize.height,
      );
    }

    final double scaleX = canvasSize.width / imgW;
    final double scaleY = canvasSize.height / imgH;
    final double scale = math.min(scaleX, scaleY);

    final double displayedWidth = imgW * scale;
    final double displayedHeight = imgH * scale;
    final double offsetX = (canvasSize.width - displayedWidth) / 2.0;
    final double offsetY = (canvasSize.height - displayedHeight) / 2.0;

    return _ImageTransform(
      scale: scale,
      offsetX: offsetX,
      offsetY: offsetY,
      displayedWidth: displayedWidth,
      displayedHeight: displayedHeight,
    );
  }

  Rect _screenToImageCoords(Rect screenRect, _ImageTransform transform) {
    final double imgW = _imgWidth.toDouble();
    final double imgH = _imgHeight.toDouble();

    final double left = ((screenRect.left - transform.offsetX) / transform.scale)
        .clamp(0.0, imgW);
    final double top = ((screenRect.top - transform.offsetY) / transform.scale)
        .clamp(0.0, imgH);
    final double right = ((screenRect.right - transform.offsetX) / transform.scale)
        .clamp(0.0, imgW);
    final double bottom = ((screenRect.bottom - transform.offsetY) / transform.scale)
        .clamp(0.0, imgH);

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _onSubmit() {
    final dyeScreenRect = _getRect(_dyeStart, _dyeEnd);
    final bgScreenRect = _getRect(_bgStart, _bgEnd);

    if (dyeScreenRect == null || bgScreenRect == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select BOTH the Dye Pad (Red) and Reference Paper (Blue).'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Size canvasSize = _lastCanvasSize;
    if (_canvasKey.currentContext != null) {
      final box = _canvasKey.currentContext!.findRenderObject() as RenderBox?;
      if (box != null && box.size.width > 0 && box.size.height > 0) {
        canvasSize = box.size;
      }
    }

    if (canvasSize.width <= 0 || canvasSize.height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error determining image layout dimensions.')),
      );
      return;
    }

    final transform = _computeTransform(canvasSize);
    final dyeImageRect = _screenToImageCoords(dyeScreenRect, transform);
    final bgImageRect = _screenToImageCoords(bgScreenRect, transform);

    if (dyeImageRect.width < 2 ||
        dyeImageRect.height < 2 ||
        bgImageRect.width < 2 ||
        bgImageRect.height < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected regions are too small. Please draw larger boxes.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imagePath: _normalizedPath.isNotEmpty ? _normalizedPath : widget.imagePath,
          dyeRect: dyeImageRect,
          bgRect: bgImageRect,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Regions')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading & normalizing image orientation...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Select Regions')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select ROI Boxes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset selections',
            onPressed: () {
              setState(() {
                _dyeStart = null;
                _dyeEnd = null;
                _bgStart = null;
                _bgEnd = null;
                _currentMode = SelectionMode.dye;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopInstructions(theme),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final Size canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                _lastCanvasSize = canvasSize;
                final transform = _computeTransform(canvasSize);

                return GestureDetector(
                  onPanStart: (details) {
                    final pos = details.localPosition;
                    final clampedPos = Offset(
                      pos.dx.clamp(transform.offsetX, transform.offsetX + transform.displayedWidth),
                      pos.dy.clamp(transform.offsetY, transform.offsetY + transform.displayedHeight),
                    );
                    setState(() {
                      if (_currentMode == SelectionMode.dye) {
                        _dyeStart = clampedPos;
                        _dyeEnd = clampedPos;
                      } else {
                        _bgStart = clampedPos;
                        _bgEnd = clampedPos;
                      }
                    });
                  },
                  onPanUpdate: (details) {
                    final pos = details.localPosition;
                    final clampedPos = Offset(
                      pos.dx.clamp(transform.offsetX, transform.offsetX + transform.displayedWidth),
                      pos.dy.clamp(transform.offsetY, transform.offsetY + transform.displayedHeight),
                    );
                    setState(() {
                      if (_currentMode == SelectionMode.dye) {
                        _dyeEnd = clampedPos;
                      } else {
                        _bgEnd = clampedPos;
                      }
                    });
                  },
                  onPanEnd: (details) {
                    if (_currentMode == SelectionMode.dye && _bgStart == null) {
                      setState(() {
                        _currentMode = SelectionMode.reference;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dye Pad selected! Now drag around the Reference Background Paper (Blue).'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Stack(
                    key: _canvasKey,
                    fit: StackFit.expand,
                    children: [
                      if (_imageBytes != null)
                        Image.memory(
                          _imageBytes!,
                          fit: BoxFit.contain,
                        ),
                      CustomPaint(
                        painter: _ROIPainter(
                          dyeRect: _getRect(_dyeStart, _dyeEnd),
                          bgRect: _getRect(_bgStart, _bgEnd),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildTopInstructions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildModeTab(
                  label: '1. Dye Pad (Red)',
                  color: Colors.redAccent,
                  isSelected: _currentMode == SelectionMode.dye,
                  isDone: _dyeStart != null && _dyeEnd != null && _dyeStart != _dyeEnd,
                  onTap: () => setState(() => _currentMode = SelectionMode.dye),
                ),
                const SizedBox(width: 8),
                _buildModeTab(
                  label: '2. Reference (Blue)',
                  color: Colors.blueAccent,
                  isSelected: _currentMode == SelectionMode.reference,
                  isDone: _bgStart != null && _bgEnd != null && _bgStart != _bgEnd,
                  onTap: () => setState(() => _currentMode = SelectionMode.reference),
                ),
              ],
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
    required bool isDone,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.4),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? color : null,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDone) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 16, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final bool canSubmit = _dyeStart != null &&
        _dyeEnd != null &&
        _dyeStart != _dyeEnd &&
        _bgStart != null &&
        _bgEnd != null &&
        _bgStart != _bgEnd;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: canSubmit ? _onSubmit : null,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text(
            'Submit & Analyze pH',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
    );
  }
}

class _ImageTransform {
  final double scale;
  final double offsetX;
  final double offsetY;
  final double displayedWidth;
  final double displayedHeight;

  _ImageTransform({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
    required this.displayedWidth,
    required this.displayedHeight,
  });
}

class _ROIPainter extends CustomPainter {
  final Rect? dyeRect;
  final Rect? bgRect;

  _ROIPainter({this.dyeRect, this.bgRect});

  @override
  void paint(Canvas canvas, Size size) {
    if (dyeRect != null && !dyeRect!.isEmpty) {
      final paintBorder = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final paintFill = Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      canvas.drawRect(dyeRect!, paintFill);
      canvas.drawRect(dyeRect!, paintBorder);
      _drawBadge(canvas, 'Dye Pad (Red)', dyeRect!.topLeft, Colors.redAccent);
    }

    if (bgRect != null && !bgRect!.isEmpty) {
      final paintBorder = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      final paintFill = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      canvas.drawRect(bgRect!, paintFill);
      canvas.drawRect(bgRect!, paintBorder);
      _drawBadge(canvas, 'Reference (Blue)', bgRect!.topLeft, Colors.blueAccent);
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
  bool shouldRepaint(covariant _ROIPainter oldDelegate) {
    return oldDelegate.dyeRect != dyeRect || oldDelegate.bgRect != bgRect;
  }
}
