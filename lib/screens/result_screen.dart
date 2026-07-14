import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../services/analyzer_isolate.dart';
import '../services/export_service.dart';
import '../services/history_service.dart';
import '../services/ph_analyzer.dart';
import '../services/robust_extractor.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final Rect dyeRect;
  final Rect bgRect;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.dyeRect,
    required this.bgRect,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
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

  @override
  void initState() {
    super.initState();
    _runAnalysis();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _runAnalysis() async {
    try {
      // Convert Rect objects to serializable maps for isolate communication
      final dyeRectMap = {
        'left': widget.dyeRect.left,
        'top': widget.dyeRect.top,
        'width': widget.dyeRect.width,
        'height': widget.dyeRect.height,
      };
      final bgRectMap = {
        'left': widget.bgRect.left,
        'top': widget.bgRect.top,
        'width': widget.bgRect.width,
        'height': widget.bgRect.height,
      };

      // Create Rect objects from maps for the analyzer service
      final dyeRectForAnalyzer = Rect.fromLTWH(
        dyeRectMap['left'] as double,
        dyeRectMap['top'] as double,
        dyeRectMap['width'] as double,
        dyeRectMap['height'] as double,
      );

      final bgRectForAnalyzer = Rect.fromLTWH(
        bgRectMap['left'] as double,
        bgRectMap['top'] as double,
        bgRectMap['width'] as double,
        bgRectMap['height'] as double,
      );

      final phFuture = AnalyzerService.predictFromPath(
        widget.imagePath,
        dyeRectForAnalyzer,
        bgRectForAnalyzer,
      );

      final path = widget.imagePath;

      final thumbnailFuture = Isolate.run(() {
        final image = PHAnalyzer.loadAndNormalizeImage(path);

        // Reconstruct Rect objects from the maps
        final dyeR = Rect.fromLTWH(
          dyeRectMap['left'] as double,
          dyeRectMap['top'] as double,
          dyeRectMap['width'] as double,
          dyeRectMap['height'] as double,
        );

        final bgR = Rect.fromLTWH(
          bgRectMap['left'] as double,
          bgRectMap['top'] as double,
          bgRectMap['width'] as double,
          bgRectMap['height'] as double,
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

        final dyePatch = img.copyCrop(
          image,
          x: dyeLeft,
          y: dyeTop,
          width: dyeW,
          height: dyeH,
        );
        final bgPatch = img.copyCrop(
          image,
          x: bgLeft,
          y: bgTop,
          width: bgW,
          height: bgH,
        );

        final dyeRgb = RobustColorExtractor.extract(dyePatch);
        final bgRgb = RobustColorExtractor.extract(bgPatch);

        return {
          'dyeThumb': img.encodeJpg(dyePatch, quality: 90),
          'bgThumb': img.encodeJpg(bgPatch, quality: 90),
          'dyeRgb': dyeRgb,
          'bgRgb': bgRgb,
        };
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
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getPhColor(double ph) {
    if (ph < 3.0) return const Color(0xFFE53935); // Red
    if (ph < 5.0) return const Color(0xFFFB8C00); // Orange
    if (ph < 6.5) return const Color(0xFFFDD835); // Yellow
    if (ph <= 7.5) return const Color(0xFF43A047); // Green (Neutral)
    if (ph < 10.0) return const Color(0xFF1E88E5); // Blue
    if (ph < 12.0) return const Color(0xFF3949AB); // Indigo
    return const Color(0xFF8E24AA); // Purple
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
        appBar: AppBar(title: const Text('Analyzing pH...')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Running local Edge-Computing analysis...',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Extracting robust RGBs & evaluating natural cubic spline',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
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

    final double ph = _predictedPh ?? 7.0;
    final Color phColor = _getPhColor(ph);
    final String category = _getPhCategory(ph);

    return Scaffold(
      appBar: AppBar(title: const Text('Analysis Results'), centerTitle: true),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [theme.colorScheme.surface, phColor.withValues(alpha: 0.1)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMainResultCard(theme, ph, phColor, category),
                const SizedBox(height: 24),
                Text(
                  'Extracted ROIs & Robust RGB Verification',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
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
                        title: 'Reference Paper',
                        thumbnail: _bgThumbnail,
                        rgb: _bgRgb,
                        borderColor: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildExplanationCard(theme),
                const SizedBox(height: 28),
                Text(
                  'Record & Export Analysis',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Add note (e.g. soil sample #3, well water tap)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    prefixIcon: const Icon(Icons.note_add_outlined),
                  ),
                ),
                const SizedBox(height: 16),
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
                              ? Colors.green
                              : theme.colorScheme.primaryContainer,
                          foregroundColor: _isSaved
                              ? Colors.white
                              : theme.colorScheme.onPrimaryContainer,
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
                        icon: const Icon(Icons.share),
                        label: const Text(
                          'Share Report',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                            color: theme.colorScheme.primary,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Analyze Another Image'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
        ),
      ),
    );
  }

  Widget _buildMainResultCard(
    ThemeData theme,
    double ph,
    Color phColor,
    String category,
  ) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: phColor.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: phColor.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: phColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              category.toUpperCase(),
              style: TextStyle(
                color: phColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Predicted pH',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ph.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w900,
              color: phColor,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (ph / 14.0).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(phColor),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '0.0 (Acid)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                '7.0 (Neutral)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              Text(
                '14.0 (Base)',
                style: TextStyle(fontSize: 11, color: Colors.grey),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 70,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            clipBehavior: Clip.antiAlias,
            child: thumbnail != null
                ? Image.memory(thumbnail, fit: BoxFit.cover)
                : const Center(child: Icon(Icons.image_not_supported)),
          ),
          const SizedBox(height: 10),
          if (rgb != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(rgb[0], rgb[1], rgb[2], 1.0),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey, width: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'RGB(${rgb[0]}, ${rgb[1]}, ${rgb[2]})',
                  style: const TextStyle(
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

  Widget _buildExplanationCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Color differences (ΔL*, Δa*, Δb*) against reference white were mapped using natural cubic spline over 8 anchor points to compute exact pH.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
