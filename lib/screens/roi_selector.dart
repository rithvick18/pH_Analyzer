import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/image_geometry.dart';
import '../services/image_preparation.dart';
import '../services/calibration_profile_service.dart';
import '../services/ph_analyzer.dart';
import '../services/robust_extractor.dart';
import '../services/gemini_validator_service.dart';
import '../models/calibration_data.dart';
import '../models/calibration_profile.dart';
import 'result_screen.dart';

class ROISelector extends StatefulWidget {
  final String imagePath;
  final String source;
  final DateTime? capturedAt;
  final bool calibrationPoint;
  const ROISelector({
    super.key,
    required this.imagePath,
    this.source = 'gallery',
    this.capturedAt,
    this.calibrationPoint = false,
  });
  @override
  State<ROISelector> createState() => _ROISelectorState();
}

class _ROISelectorState extends State<ROISelector> {
  Uint8List? _bytes;
  Size _imageSize = Size.zero;
  String? _normalizedPath;
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool? _geminiEnabled;
  String? _modeError;
  bool _useReference = false;
  bool _selectReference = false;
  Rect? _dye;
  Rect? _reference;
  Offset? _start;
  List<CalibrationProfile> _profiles = [];
  String _selectedId = CalibrationProfileService.bundledId;
  String? _profileError;
  bool _profilesLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.source != 'demo') _loadValidationMode();
    if (!widget.calibrationPoint) _loadProfiles();
  }

  Future<void> _loadValidationMode() async {
    try {
      final key = await GeminiValidatorService.readKey();
      if (mounted) {
        setState(() => _geminiEnabled = key != null && key.isNotEmpty);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _modeError =
              'Cannot read validation settings. Retry after reopening this photo.',
        );
      }
    }
  }

  Future<void> _loadProfiles() async {
    try {
      final profiles = await CalibrationProfileService.getAll();
      final selected = await CalibrationProfileService.activeId();
      if (mounted) {
        setState(() {
          _profiles = profiles;
          _selectedId = selected;
          _profilesLoading = false;
          if (selected != CalibrationProfileService.bundledId &&
              !profiles.any((p) => p.id == selected)) {
            _profileError =
                'Selected calibration is missing. Choose a profile before analyzing.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _profileError = e.toString();
          _profilesLoading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final directory = await getTemporaryDirectory();
      final result = await compute(prepareImage, {
        'path': widget.imagePath,
        'tempDirPath': directory.path,
      });
      final path = result['path'] as String;
      if (!mounted) {
        await _remove(path);
        return;
      }
      setState(() {
        _normalizedPath = path;
        _bytes = result['bytes'] as Uint8List;
        _imageSize = Size(
          (result['width'] as int).toDouble(),
          (result['height'] as int).toDouble(),
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Unable to prepare this image. Choose a readable photo under 25 MB and 24 megapixels.';
        });
      }
    }
  }

  Future<void> _remove(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      /* OS temp cleanup is the fallback. */
    }
  }

  @override
  void dispose() {
    final path = _normalizedPath;
    if (path != null) unawaited(_remove(path));
    super.dispose();
  }

  Rect? get _selected => _selectReference ? _reference : _dye;
  void _setSelected(Rect rect) => setState(() {
    if (_selectReference) {
      _reference = rect;
    } else {
      _dye = rect;
    }
  });

  /// Accessible alternatives to freehand drawing, in image coordinates.
  void _adjust(double dx, double dy, double sizeFactor) {
    final r =
        _selected ??
        Rect.fromLTWH(
          _imageSize.width * .4,
          _imageSize.height * (_selectReference ? .65 : .35),
          _imageSize.width * .2,
          _imageSize.height * .1,
        );
    final width = (r.width * sizeFactor).clamp(4.0, _imageSize.width);
    final height = (r.height * sizeFactor).clamp(4.0, _imageSize.height);
    final left = (r.center.dx - width / 2 + dx * _imageSize.width).clamp(
      0.0,
      _imageSize.width - width,
    );
    final top = (r.center.dy - height / 2 + dy * _imageSize.height).clamp(
      0.0,
      _imageSize.height - height,
    );
    _setSelected(Rect.fromLTWH(left, top, width, height));
  }

  Future<void> _submit() async {
    if (_busy || _dye == null || (_useReference && _reference == null)) return;
    if (_dye!.width < 4 ||
        _dye!.height < 4 ||
        (_useReference && (_reference!.width < 4 || _reference!.height < 4))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select regions at least 4 by 4 pixels.')),
      );
      return;
    }
    if (_useReference && _dye!.overlaps(_reference!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dye and reference paper regions must not overlap.'),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    PadValidation? validation;
    var manualMode = false;
    try {
      // The bundled demo is a labeled fixture, never a sample measurement.
      if (widget.source != 'demo') {
        if (_modeError != null) throw PadValidationException(_modeError!);
        final key = await GeminiValidatorService.readKey();
        manualMode = key == null || key.isEmpty;
        if (!manualMode) {
          validation = await GeminiValidatorService.validate(
            imagePath: _normalizedPath!,
            dyeRect: _dye!,
          );
        }
      }
      if (validation != null && !validation.accepted) {
        throw PadValidationException(
          validation.status == 'invalid'
              ? 'This does not appear to be a pH dye pad. ${validation.reason}'
              : 'Dye pad could not be confirmed. Retake the photo. ${validation.reason}',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is PadValidationException
                  ? e.message
                  : 'Gemini validation failed. Check the connection and retry.',
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    if (widget.calibrationPoint) {
      try {
        final image = PHAnalyzer.loadAndNormalizeImage(_normalizedPath!);
        final dye = RobustColorExtractor.extract(
          ImageGeometry.crop(image, _dye!),
        );
        final reference = _useReference
            ? RobustColorExtractor.extract(
                ImageGeometry.crop(image, _reference!),
              )
            : const [245, 245, 240];
        if (mounted) Navigator.of(context).pop((dye, reference));
      } catch (e) {
        if (mounted) {
          setState(() => _busy = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Color extraction failed: $e')),
          );
        }
      }
      return;
    }
    if (_profileError != null || _profilesLoading) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_profileError ?? 'Calibration is still loading.'),
        ),
      );
      return;
    }
    CalibrationData? calibration;
    String calibrationName = 'Bundled experimental';
    if (_selectedId != CalibrationProfileService.bundledId) {
      final profile = _profiles.firstWhere((p) => p.id == _selectedId);
      calibration = profile.calibration;
      calibrationName = profile.name;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          imagePath: _normalizedPath!,
          dyeRect: _dye!,
          bgRect: _useReference ? _reference : null,
          source: widget.source,
          capturedAt: widget.capturedAt,
          calibration: calibration,
          calibrationName: calibrationName,
          validationReason: validation?.reason,
          manualMode: manualMode,
        ),
      ),
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Preparing photo')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photo unavailable')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.calibrationPoint
              ? 'Capture calibration color'
              : widget.source == 'demo'
              ? 'DEMO — Confirm regions'
              : 'Confirm photo regions',
        ),
        actions: [
          IconButton(
            tooltip: 'Reset selected regions',
            onPressed: () => setState(() {
              _dye = null;
              _reference = null;
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    widget.source == 'demo'
                        ? 'Select the dye pad on this demo photo. Reference paper is optional.'
                        : _modeError != null
                        ? _modeError!
                        : _geminiEnabled == null
                        ? 'Loading image validation settings…'
                        : _geminiEnabled!
                        ? 'Select the dye pad. Gemini will check this photo before local pH analysis.'
                        : 'Manual mode: select the dye pad for local color analysis. No AI check will confirm that this is a dye pad.',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Dye pad'),
                          selected: !_selectReference,
                          onSelected: (_) =>
                              setState(() => _selectReference = false),
                        ),
                      ),
                      if (_useReference)
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Reference paper'),
                            selected: _selectReference,
                            onSelected: (_) =>
                                setState(() => _selectReference = true),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: (viewport.maxHeight * .5).clamp(220.0, 600.0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxHeight <= 0 ||
                          constraints.maxWidth <= 0) {
                        return const SizedBox.shrink();
                      }
                      final geometry = ImageGeometry(
                        _imageSize,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      );
                      Offset point(Offset p) => geometry
                          .toImage(Rect.fromLTWH(p.dx, p.dy, 0, 0))
                          .topLeft;
                      return Semantics(
                        label:
                            'Photo selection canvas. Use the region adjustment buttons below as an alternative to dragging.',
                        child: GestureDetector(
                          onPanStart: (d) {
                            _start = point(d.localPosition);
                          },
                          onPanUpdate: (d) {
                            if (_start != null) {
                              _setSelected(
                                Rect.fromPoints(
                                  _start!,
                                  point(d.localPosition),
                                ),
                              );
                            }
                          },
                          onPanEnd: (_) => _start = null,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(
                                _bytes!,
                                fit: BoxFit.contain,
                                semanticLabel: 'Captured photo',
                              ),
                              CustomPaint(
                                painter: _SelectionPainter(
                                  geometry,
                                  _dye,
                                  _useReference ? _reference : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Place or reset active region at center',
                      onPressed: () {
                        setState(() {
                          if (_selectReference) {
                            _reference = null;
                          } else {
                            _dye = null;
                          }
                        });
                        _adjust(0, 0, 1);
                      },
                      icon: const Icon(Icons.center_focus_strong),
                    ),
                    IconButton(
                      tooltip: 'Move region left',
                      onPressed: () => _adjust(-.02, 0, 1),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    IconButton(
                      tooltip: 'Move region right',
                      onPressed: () => _adjust(.02, 0, 1),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                    IconButton(
                      tooltip: 'Move region up',
                      onPressed: () => _adjust(0, -.02, 1),
                      icon: const Icon(Icons.arrow_upward),
                    ),
                    IconButton(
                      tooltip: 'Move region down',
                      onPressed: () => _adjust(0, .02, 1),
                      icon: const Icon(Icons.arrow_downward),
                    ),
                    IconButton(
                      tooltip: 'Enlarge region',
                      onPressed: () => _adjust(0, 0, 1.2),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Shrink region',
                      onPressed: () => _adjust(0, 0, .8),
                      icon: const Icon(Icons.remove),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Measure reference paper'),
                  subtitle: _useReference
                      ? null
                      : const Text(
                          'A fixed reference color will be assumed. Lighting is not corrected.',
                        ),
                  value: _useReference,
                  onChanged: (v) => setState(() {
                    _useReference = v;
                    if (!v) _selectReference = false;
                  }),
                ),
                if (!widget.calibrationPoint && _profilesLoading)
                  const LinearProgressIndicator(),
                if (!widget.calibrationPoint)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (_profileError != null)
                          Text(
                            _profileError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        DropdownButtonFormField<String>(
                          key: ValueKey('analysis_calibration_$_selectedId'),
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Dye calibration for this analysis',
                          ),
                          initialValue:
                              _selectedId ==
                                      CalibrationProfileService.bundledId ||
                                  _profiles.any((p) => p.id == _selectedId)
                              ? _selectedId
                              : CalibrationProfileService.bundledId,
                          items: [
                            const DropdownMenuItem(
                              value: CalibrationProfileService.bundledId,
                              child: Text(
                                'Bundled experimental',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            ..._profiles.map(
                              (p) => DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (id) async {
                            if (id == null) return;
                            try {
                              await CalibrationProfileService.select(id);
                              if (mounted) {
                                setState(() {
                                  _selectedId = id;
                                  _profileError = null;
                                });
                              }
                            } catch (e) {
                              if (mounted) {
                                setState(() => _profileError = e.toString());
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          !_busy &&
                              (widget.source == 'demo' ||
                                  (_geminiEnabled != null &&
                                      _modeError == null)) &&
                              (widget.calibrationPoint ||
                                  (!_profilesLoading &&
                                      _profileError == null)) &&
                              _dye != null &&
                              (!_useReference || _reference != null)
                          ? _submit
                          : null,
                      icon: const Icon(Icons.analytics_outlined),
                      label: Text(
                        widget.calibrationPoint
                            ? 'Use selected colors'
                            : _geminiEnabled == false && widget.source != 'demo'
                            ? 'Analyze in manual mode'
                            : 'Analyze as an unvalidated estimate',
                      ),
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
}

class _SelectionPainter extends CustomPainter {
  final ImageGeometry geometry;
  final Rect? dye;
  final Rect? reference;
  _SelectionPainter(this.geometry, this.dye, this.reference);
  @override
  void paint(Canvas canvas, Size size) {
    for (final item in [
      (dye, Colors.redAccent),
      (reference, Colors.blueAccent),
    ]) {
      if (item.$1 == null) continue;
      final rect = geometry.toScreen(item.$1!);
      canvas.drawRect(
        rect,
        Paint()
          ..color = item.$2
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      final text = TextPainter(
        text: TextSpan(
          text: item.$1 == dye ? 'Dye' : 'Reference',
          style: TextStyle(
            color: item.$2,
            backgroundColor: Colors.black87,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, rect.topLeft);
    }
  }

  @override
  bool shouldRepaint(covariant _SelectionPainter old) =>
      old.dye != dye ||
      old.reference != reference ||
      old.geometry.viewport != geometry.viewport;
}
