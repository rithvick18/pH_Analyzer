import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/analyzer_isolate.dart';
import '../services/color_converter.dart';
import '../services/export_service.dart';
import '../services/history_service.dart';
import '../services/ph_analyzer.dart';
import '../theme/lab_theme.dart';
import '../models/measurement.dart';
import '../services/diagnostics.dart';

class ResultScreen extends StatefulWidget {
  final String imagePath;
  final Rect dyeRect;
  final Rect? bgRect;
  final String source;
  final DateTime? capturedAt;

  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.dyeRect,
    this.bgRect,
    this.source = 'gallery',
    this.capturedAt,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;
  double? _predictedPh;
  Measurement? _measurement;
  bool _isSharing = false;
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
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
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
      final result = await AnalyzerService.analyze(
        imagePath: widget.imagePath,
        dyeRect: widget.dyeRect,
        bgRect: widget.bgRect,
        source: widget.source,
        capturedAt: widget.capturedAt,
      );
      if (!mounted) return;
      setState(() {
        _measurement = result.measurement;
        _predictedPh = result.measurement.ph;
        _dyeThumbnail = result.dyeThumbnail;
        _bgThumbnail = result.backgroundThumbnail;
        _dyeRgb = result.measurement.dyeRgb;
        _bgRgb = result.measurement.backgroundRgb;
        _isLoading = false;
      });
      if (MediaQuery.disableAnimationsOf(context)) {
        _animController.value = 1;
      } else {
        _animController.forward();
      }
    } catch (e) {
      Diagnostics.record('measurement', e);
      if (mounted) {
        setState(() {
          _errorMessage =
              e is MeasurementQualityException || e is LuminanceException
              ? e.toString()
              : 'Analysis could not be completed. Check the photo and selected regions, then retry.';
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
        measurement: _measurement,
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
      Diagnostics.record('measurement', e);
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Unable to save. Check available storage and retry; this result has not been saved.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    if (_predictedPh == null || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await ExportService.sharePhReport(
        imagePath: widget.imagePath,
        dyeRect: widget.dyeRect,
        bgRect: widget.bgRect,
        measurement: _measurement,
        measuredAt: _measurement?.measuredAt,
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
        phValue: _predictedPh!,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
    } catch (e) {
      Diagnostics.record('measurement', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Unable to share the report. Check available storage and try again.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _getPhCategory(double ph) => LabTheme.getPhCategory(ph);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: LabTheme.bgDark,
        appBar: AppBar(
          backgroundColor: LabTheme.surfaceCard,
          title: const Text(
            'Estimating pH on this device…',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: LabTheme.cyanAccent),
              SizedBox(height: 20),
              Text(
                'Analyzing the selected regions…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'This photo stays on your device.',
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
          title: const Text(
            'Analysis Error',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
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
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _measurement!.statusLabel,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _measurement!.validationReason,
                          style: const TextStyle(color: Colors.black87),
                        ),
                        for (final warning in _measurement!.warnings)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              warning,
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                      ],
                    ),
                  ),
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
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText:
                          'Add note (e.g. soil sample #3, well water tap)',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      filled: true,
                      fillColor: LabTheme.surfaceCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: LabTheme.borderDark,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: LabTheme.borderDark,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: LabTheme.cyanAccent,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.note_add_outlined,
                        color: LabTheme.cyanAccent,
                      ),
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
                          onPressed: _predictedPh == null || _isSharing
                              ? null
                              : _shareReport,
                          icon: const Icon(
                            Icons.share,
                            color: LabTheme.cyanAccent,
                          ),
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
                    ph.toStringAsFixed(1),
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
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '7.0 (Neutral)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              Text(
                '14.0 (Alkaline)',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
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
                    child: Icon(
                      Icons.image_not_supported,
                      color: Colors.white38,
                    ),
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
    final labBg = _bgRgb != null
        ? ColorConverter.rgbToLab(_bgRgb!)
        : [96.0, -0.5, 2.0];
    final deltaLab = ColorConverter.deltaLab(
      _dyeRgb!,
      _bgRgb ?? [245, 245, 240],
    );

    final String metricsSummary =
        '''
Dye RGB: (${_dyeRgb![0]}, ${_dyeRgb![1]}, ${_dyeRgb![2]})
Dye Lab: L*=${labDye[0].toStringAsFixed(1)}, a*=${labDye[1].toStringAsFixed(1)}, b*=${labDye[2].toStringAsFixed(1)}
Ref RGB: (${_bgRgb?[0] ?? 245}, ${_bgRgb?[1] ?? 245}, ${_bgRgb?[2] ?? 240})
Ref Lab: L*=${labBg[0].toStringAsFixed(1)}, a*=${labBg[1].toStringAsFixed(1)}, b*=${labBg[2].toStringAsFixed(1)}
Delta Lab: ΔL*=${deltaLab[0].toStringAsFixed(1)}, Δa*=${deltaLab[1].toStringAsFixed(1)}, Δb*=${deltaLab[2].toStringAsFixed(1)}
'''
            .trim();

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
              icon: const Icon(
                Icons.copy_rounded,
                color: LabTheme.cyanAccent,
                size: 20,
              ),
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
                Color.fromRGBO(
                  _bgRgb?[0] ?? 245,
                  _bgRgb?[1] ?? 245,
                  _bgRgb?[2] ?? 240,
                  1.0,
                ),
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
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: indicatorColor,
            fontSize: 12,
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
              'Color differences (ΔL*, Δa*, Δb*) against reference white were mapped using natural cubic spline over the bundled calibration anchors to estimate pH. Strip identity and accuracy are not independently validated.',
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
