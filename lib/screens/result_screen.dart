import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../services/analyzer_isolate.dart';
import '../services/color_converter.dart';
import '../services/export_service.dart';
import '../services/history_service.dart';
import '../services/ph_analyzer.dart';
import '../services/robust_extractor.dart';
import '../theme/lab_theme.dart';

Map<String, dynamic> _generateThumbnailsIsolate(Map<String, dynamic> params) {
  final path = params['path'] as String;
  final dyeRectMap = params['dyeRectMap'] as Map<String, dynamic>;
  final bgRectMap = params['bgRectMap'] as Map<String, dynamic>?;

  final image = PHAnalyzer.loadAndNormalizeImage(path);

  final dyeR = Rect.fromLTWH(
    dyeRectMap['left'] as double,
    dyeRectMap['top'] as double,
    dyeRectMap['width'] as double,
    dyeRectMap['height'] as double,
  );

  final int dyeLeft = dyeR.left.floor().clamp(0, image.width - 1);
  final int dyeTop = dyeR.top.floor().clamp(0, image.height - 1);
  final int dyeW = (dyeR.right.ceil() - dyeLeft).clamp(
    1,
    image.width - dyeLeft,
  );
  final int dyeH = (dyeR.bottom.ceil() - dyeTop).clamp(
    1,
    image.height - dyeTop,
  );

  final dyePatch = img.copyCrop(
    image,
    x: dyeLeft,
    y: dyeTop,
    width: dyeW,
    height: dyeH,
  );
  final dyeRgb = RobustColorExtractor.extract(dyePatch);

  img.Image bgPatch;
  List<int> bgRgb;

  if (bgRectMap != null) {
    final bgR = Rect.fromLTWH(
      bgRectMap['left'] as double,
      bgRectMap['top'] as double,
      bgRectMap['width'] as double,
      bgRectMap['height'] as double,
    );
    final int bgLeft = bgR.left.floor().clamp(0, image.width - 1);
    final int bgTop = bgR.top.floor().clamp(0, image.height - 1);
    final int bgW = (bgR.right.ceil() - bgLeft).clamp(
      1,
      image.width - bgLeft,
    );
    final int bgH = (bgR.bottom.ceil() - bgTop).clamp(
      1,
      image.height - bgTop,
    );
    bgPatch = img.copyCrop(
      image,
      x: bgLeft,
      y: bgTop,
      width: bgW,
      height: bgH,
    );
    bgRgb = RobustColorExtractor.extract(bgPatch);
  } else {
    bgRgb = const [245, 245, 240];
    bgPatch = img.Image(width: 70, height: 70);
    img.fill(bgPatch, color: img.ColorRgb8(245, 245, 240));
  }

  return {
    'dyeThumb': img.encodeJpg(dyePatch, quality: 90),
    'bgThumb': img.encodeJpg(bgPatch, quality: 90),
    'dyeRgb': dyeRgb,
    'bgRgb': bgRgb,
  };
}

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final Rect dyeRect;
  final Rect? bgRect;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.dyeRect,
    this.bgRect,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  double? _predictedPh;
  Uint8List? _dyeThumbnail;
  Uint8List? _bgThumbnail;
  List<int>? _dyeRgb;
  List<int>? _bgRgb;

  final TextEditingController _noteController = TextEditingController();
  bool _isSaved = false;
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _runAnalysis();
  }

  @override
  void dispose() {
    _animController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    try {
      final dyeRectMap = {
        'left': widget.dyeRect.left,
        'top': widget.dyeRect.top,
        'width': widget.dyeRect.width,
        'height': widget.dyeRect.height,
      };
      final Map<String, dynamic>? bgRectMap = widget.bgRect != null
          ? {
              'left': widget.bgRect!.left,
              'top': widget.bgRect!.top,
              'width': widget.bgRect!.width,
              'height': widget.bgRect!.height,
            }
          : null;

      final dyeRectForAnalyzer = Rect.fromLTWH(
        dyeRectMap['left'] as double,
        dyeRectMap['top'] as double,
        dyeRectMap['width'] as double,
        dyeRectMap['height'] as double,
      );

      final Rect? bgRectForAnalyzer = widget.bgRect != null
          ? Rect.fromLTWH(
              bgRectMap!['left'] as double,
              bgRectMap['top'] as double,
              bgRectMap['width'] as double,
              bgRectMap['height'] as double,
            )
          : null;

      final phFuture = AnalyzerService.predictFromPath(
        widget.imagePath,
        dyeRectForAnalyzer,
        bgRectForAnalyzer,
      );

      final path = widget.imagePath;

      final thumbnailFuture = compute(_generateThumbnailsIsolate, {
        'path': path,
        'dyeRectMap': dyeRectMap,
        'bgRectMap': bgRectMap,
      });

      final results = await Future.wait([phFuture, thumbnailFuture]);
      final double ph = results[0] as double;
      final Map<String, dynamic> thumbData = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _predictedPh = ph;
          _dyeThumbnail = thumbData['dyeThumb'] as Uint8List;
          _bgThumbnail = thumbData['bgThumb'] as Uint8List;
          _dyeRgb = thumbData['dyeRgb'] as List<int>;
          _bgRgb = thumbData['bgRgb'] as List<int>;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Analysis failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToHistory() async {
    if (_predictedPh == null || _isSaved || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      await HistoryService.savePrediction(
        phValue: _predictedPh!,
        tempImagePath: widget.imagePath,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        dyeRect: widget.dyeRect,
        bgRect: widget.bgRect,
      );
      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved to local analysis history!'),
            backgroundColor: LabTheme.phNeutralGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    if (_predictedPh == null) return;
    try {
      await ExportService.sharePhReport(
        imagePath: widget.imagePath,
        dyeRect: widget.dyeRect,
        bgRect: widget.bgRect,
        phValue: _predictedPh!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing report: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _getPhCategory(double ph) {
    if (ph < 3.0) return 'Strongly Acidic';
    if (ph < 6.5) return 'Acidic';
    if (ph <= 7.5) return 'Neutral';
    if (ph < 11.5) return 'Basic / Alkaline';
    return 'Strongly Basic';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: LabTheme.bgDark,
        appBar: AppBar(
          backgroundColor: LabTheme.surfaceCard,
          title: const Text('Analyzing pH...', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: LabTheme.cyanAccent),
              SizedBox(height: 20),
              Text(
                'Running local Edge-Computing analysis...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Extracting robust RGBs & evaluating natural cubic spline',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: LabTheme.bgDark,
        appBar: AppBar(
          backgroundColor: LabTheme.surfaceCard,
          title: const Text('Analysis Error', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
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

    final double ph = _predictedPh ?? 7.0;
    final Color phColor = LabTheme.getPhColor(ph);
    final String category = _getPhCategory(ph);

    return Scaffold(
      backgroundColor: LabTheme.bgDark,
      appBar: AppBar(
        backgroundColor: LabTheme.surfaceCard,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Analysis Results',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroPhGauge(ph, phColor, category),
                  const SizedBox(height: 24),
                  const Text(
                    'Extracted ROIs & Spectral Samplers',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPatchCard(
                          theme,
                          title: 'Dye Pad Sample',
                          thumbnail: _dyeThumbnail,
                          rgb: _dyeRgb,
                          borderColor: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildPatchCard(
                          theme,
                          title: widget.bgRect != null
                              ? 'Reference Paper'
                              : 'Reference White',
                          thumbnail: _bgThumbnail,
                          rgb: _bgRgb,
                          borderColor: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildColorimetrySection(theme),
                  const SizedBox(height: 24),
                  _buildExplanationCard(theme),
                  const SizedBox(height: 28),
                  const Text(
                    'Record & Export Analysis',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Add note (e.g. soil sample #3, well water tap)',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      filled: true,
                      fillColor: LabTheme.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: LabTheme.borderDark),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: LabTheme.borderDark),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: LabTheme.cyanAccent),
                      ),
                      prefixIcon: const Icon(Icons.note_add_outlined, color: LabTheme.cyanAccent),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed:
                              (_isSaved || _isSaving || _predictedPh == null)
                              ? null
                              : _saveToHistory,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isSaved
                                      ? Icons.check_circle
                                      : Icons.bookmark_add,
                                ),
                          label: Text(
                            _isSaved ? 'Saved to History' : 'Save to History',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _isSaved
                                ? LabTheme.phNeutralGreen
                                : LabTheme.cyanAccent,
                            foregroundColor: _isSaved
                                ? Colors.white
                                : LabTheme.bgDark,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _predictedPh == null ? null : _shareReport,
                          icon: const Icon(Icons.share, color: LabTheme.cyanAccent),
                          label: const Text(
                            'Share Report',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: LabTheme.cyanAccent,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: LabTheme.cyanAccent,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Analyze Another Image'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: LabTheme.surfaceElevated,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: LabTheme.borderDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroPhGauge(double ph, Color phColor, String category) {
    return GlassContainer(
      padding: const EdgeInsets.all(28),
      borderRadius: 28,
      blur: 16,
      color: LabTheme.surfaceCard.withValues(alpha: 0.8),
      borderColor: phColor.withValues(alpha: 0.5),
      boxShadow: [
        BoxShadow(
          color: phColor.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            decoration: BoxDecoration(
              color: phColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: phColor.withValues(alpha: 0.6)),
            ),
            child: Text(
              category.toUpperCase(),
              style: TextStyle(
                color: phColor,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      phColor.withValues(alpha: 0.3),
                      phColor.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: (ph / 14.0).clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: LabTheme.borderDark.withValues(alpha: 0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(phColor),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'pH',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withValues(alpha: 0.6),
                      letterSpacing: 1.1,
                    ),
                  ),
                  Text(
                    ph.toStringAsFixed(2),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: phColor,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0.0 (Acidic)',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
              ),
              Text(
                '7.0 (Neutral)',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
              ),
              Text(
                '14.0 (Alkaline)',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPatchCard(
    ThemeData theme, {
    required String title,
    required Uint8List? thumbnail,
    required List<int>? rgb,
    required Color borderColor,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 20,
      color: LabTheme.surfaceCard.withValues(alpha: 0.8),
      borderColor: borderColor.withValues(alpha: 0.5),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: LabTheme.borderDark),
            ),
            clipBehavior: Clip.antiAlias,
            child: thumbnail != null
                ? Image.memory(thumbnail, fit: BoxFit.cover)
                : const Center(
                    child: Icon(Icons.image_not_supported, color: Colors.white38),
                  ),
          ),
          const SizedBox(height: 10),
          if (rgb != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white54, width: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'RGB(${rgb[0]}, ${rgb[1]}, ${rgb[2]})',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildColorimetrySection(ThemeData theme) {
    if (_dyeRgb == null) return const SizedBox.shrink();

    final labDye = ColorConverter.rgbToLab(_dyeRgb!);
    final labBg = _bgRgb != null ? ColorConverter.rgbToLab(_bgRgb!) : [96.0, -0.5, 2.0];
    final deltaLab = ColorConverter.deltaLab(_dyeRgb!, _bgRgb ?? [245, 245, 240]);

    final String metricsSummary = '''
Dye RGB: (${_dyeRgb![0]}, ${_dyeRgb![1]}, ${_dyeRgb![2]})
Dye Lab: L*=${labDye[0].toStringAsFixed(1)}, a*=${labDye[1].toStringAsFixed(1)}, b*=${labDye[2].toStringAsFixed(1)}
Ref RGB: (${_bgRgb?[0] ?? 245}, ${_bgRgb?[1] ?? 245}, ${_bgRgb?[2] ?? 240})
Ref Lab: L*=${labBg[0].toStringAsFixed(1)}, a*=${labBg[1].toStringAsFixed(1)}, b*=${labBg[2].toStringAsFixed(1)}
Delta Lab: ΔL*=${deltaLab[0].toStringAsFixed(1)}, Δa*=${deltaLab[1].toStringAsFixed(1)}, Δb*=${deltaLab[2].toStringAsFixed(1)}
'''.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Colorimetry & CIELAB Metrics',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, color: LabTheme.cyanAccent, size: 20),
              tooltip: 'Copy Metrics to Clipboard',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: metricsSummary));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Colorimetry metrics copied to clipboard!'),
                    backgroundColor: LabTheme.cyanAccent,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          color: LabTheme.surfaceCard.withValues(alpha: 0.8),
          borderColor: LabTheme.borderDark,
          child: Column(
            children: [
              _buildMetricRow(
                'Dye Pad RGB',
                '(${_dyeRgb![0]}, ${_dyeRgb![1]}, ${_dyeRgb![2]})',
                Color.fromRGBO(_dyeRgb![0], _dyeRgb![1], _dyeRgb![2], 1.0),
              ),
              const Divider(color: LabTheme.borderDark, height: 20),
              _buildMetricRow(
                'Dye Pad CIELAB',
                'L*: ${labDye[0].toStringAsFixed(1)}  a*: ${labDye[1].toStringAsFixed(1)}  b*: ${labDye[2].toStringAsFixed(1)}',
                LabTheme.cyanAccent,
              ),
              const Divider(color: LabTheme.borderDark, height: 20),
              _buildMetricRow(
                'Ref Paper RGB',
                '(${_bgRgb?[0] ?? 245}, ${_bgRgb?[1] ?? 245}, ${_bgRgb?[2] ?? 240})',
                Color.fromRGBO(_bgRgb?[0] ?? 245, _bgRgb?[1] ?? 245, _bgRgb?[2] ?? 240, 1.0),
              ),
              const Divider(color: LabTheme.borderDark, height: 20),
              _buildMetricRow(
                'Delta CIELAB (Δ)',
                'ΔL*: ${deltaLab[0].toStringAsFixed(1)}  Δa*: ${deltaLab[1].toStringAsFixed(1)}  Δb*: ${deltaLab[2].toStringAsFixed(1)}',
                LabTheme.tealAccent,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String value, Color indicatorColor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildExplanationCard(ThemeData theme) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      color: LabTheme.surfaceCard.withValues(alpha: 0.6),
      borderColor: LabTheme.borderDark,
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: LabTheme.cyanAccent),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Color differences (ΔL*, Δa*, Δb*) against reference white were mapped using natural cubic spline over 8 anchor points to compute exact pH.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
