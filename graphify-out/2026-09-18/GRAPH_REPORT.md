# Graph Report - pH_analyzer  (2026-09-18)

## Corpus Check
- 68 files · ~46,785 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 54 file(s) not represented in the graph (top: (none) 9, .xcconfig 8, .xml 7)

## Summary
- 888 nodes · 1072 edges · 95 communities (36 shown, 55 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 24 edges (avg confidence: 0.84)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a157aa78`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- live_camera_screen.dart
- ph_analyzer package
- result_screen.dart
- roi_selector.dart
- AppDelegate
- home_screen.dart
- lab_theme.dart
- my_application.cc
- ph_analyzer.dart
- history_screen.dart
- calibration_data.dart
- prediction_record.dart
- Linux application build
- main.dart
- State
- photo_workflow_test.dart
- export_service.dart
- color_converter.dart
- measurement.dart
- history_service.dart
- wWinMain
- package:flutter/material.dart
- manifest.json
- dart:io
- Photograph of labeled colored paper strips
- dashed_circle_painter.dart
- production_regression_test.dart
- List
- Photograph of labeled colored paper strips
- ph_pipeline_test.dart
- guide_screen.dart
- Release configuration and checks
- pH_analyzer web entry
- PredictionRecord
- MainActivity.kt
- Blue Flutter launcher artwork
- Flask launcher artwork
- Blue Flutter launcher artwork
- Flask launcher artwork
- Blue Flutter launcher artwork
- Flask launcher artwork
- Blue Flutter launcher artwork
- Flask launcher artwork
- Blue Flutter launcher artwork
- Flask launcher artwork
- Raster flask logo
- Vector flask logo
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- Flask launcher artwork
- iOS app icon
- iOS app icon
- iOS app icon
- iOS app icon
- iOS app icon
- iOS app icon
- iOS app icon
- iOS app icon
- iOS app icon
- Launch screen assets
- Chemistry flask vector logo
- macOS app icon
- macOS app icon
- macOS app icon
- macOS app icon
- macOS app icon
- macOS app icon
- macOS app icon
- Web chemistry app icon
- Web chemistry app icon
- Web chemistry app icon
- Web chemistry app icon
- Web chemistry app icon
- Blank iOS launch image
- Blank iOS launch image
- Blank iOS launch image
- Rect?
- String?
- Q: Understand this app and suggest improvements for production quality
- measurement_validation.md
- check_offline_assets.py

## God Nodes (most connected - your core abstractions)
1. `ph_analyzer package` - 26 edges
2. `Win32Window` - 24 edges
3. `MessageHandler` - 12 edges
4. `FlutterWindow` - 10 edges
5. `Create` - 10 edges
6. `WndProc` - 10 edges
7. `MessageHandler` - 9 edges
8. `PredictionRecord` - 8 edges
9. `Linux application build` - 8 edges
10. `Photograph of labeled colored paper strips` - 8 edges

## Surprising Connections (you probably didn't know these)
- `Linux application build` --semantically_similar_to--> `Windows application build`  [INFERRED] [semantically similar]
  linux/CMakeLists.txt → windows/CMakeLists.txt
- `Live camera controls` --conceptually_related_to--> `camera`  [INFERRED]
  README.md → pubspec.yaml
- `Local result history` --conceptually_related_to--> `hive`  [INFERRED]
  README.md → pubspec.yaml
- `Region of interest extraction` --conceptually_related_to--> `image`  [INFERRED]
  README.md → pubspec.yaml
- `Gallery image selection` --conceptually_related_to--> `image_picker`  [INFERRED]
  README.md → pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Calibration and image color prediction flow** — readme_calibration_anchors, readme_cielab_color_conversion, readme_dye_background_color_delta, readme_natural_cubic_spline_interpolation, readme_nearest_cielab_curve_ph_prediction [EXTRACTED 1.00]

## Communities (95 total, 55 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.05
Nodes (57): PluginRegistry, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT, UINT (+49 more)

### Community 1 - "live_camera_screen.dart"
Cohesion: 0.05
Nodes (39): CameraController?, FlashMode, Future, _active, build, _camera, _capture, _capturing (+31 more)

### Community 2 - "ph_analyzer package"
Cohesion: 0.05
Nodes (49): Flutter analyzer lint configuration, assets/calibration.json, assets/logo.png, assets/logo.svg, assets/Reference.jpeg, camera, Dart SDK 3.11.4 constraint, .env bundled asset (+41 more)

### Community 3 - "result_screen.dart"
Cohesion: 0.05
Nodes (38): Animation, AnimationController, _animController, bgRect, _bgRgb, _bgThumbnail, build, _buildColorimetrySection (+30 more)

### Community 4 - "roi_selector.dart"
Cohesion: 0.04
Nodes (46): CustomPainter, _StoredROIPainter, _adjust, build, _busy, _bytes, capturedAt, createState (+38 more)

### Community 5 - "AppDelegate"
Cohesion: 0.06
Nodes (28): Any, Cocoa, file_selector_macos, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterMacOS (+20 more)

### Community 6 - "home_screen.dart"
Cohesion: 0.06
Nodes (38): guide_screen.dart, history_screen.dart, build, build, _buildBottomNavBar, _buildCameraReadyStatus, _buildDottedLineConnector, _buildHeaderBar (+30 more)

### Community 7 - "lab_theme.dart"
Cohesion: 0.07
Nodes (27): EdgeInsetsGeometry?, bgDark, blur, borderColor, borderDark, borderRadius, boxShadow, build (+19 more)

### Community 8 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 9 - "ph_analyzer.dart"
Cohesion: 0.07
Nodes (29): color_converter.dart, cubic_spline.dart, _calibration, calibrationHash, calibrationId, colorDistance, deltaLab, estimateFromRgb (+21 more)

### Community 10 - "history_screen.dart"
Cohesion: 0.09
Nodes (22): bgRect, _confirmDelete, createState, decoded, dyeRect, _getPhColor, _imgHeight, _imgWidth (+14 more)

### Community 11 - "calibration_data.dart"
Cohesion: 0.11
Nodes (17): dart:convert, anchors, bgRgb, CalibrationAnchor, CalibrationData, dyeRgb, fromJson, fromJsonString (+9 more)

### Community 12 - "prediction_record.dart"
Cohesion: 0.08
Nodes (25): DateTime?, double?, Measurement, bgHeight, bgLeft, bgTop, bgWidth, dyeHeight (+17 more)

### Community 13 - "Linux application build"
Cohesion: 0.14
Nodes (18): Application bundle installation, com.example.ph_analyzer application ID, Generated plugin build rules, GTK 3 dependency, Linux application build, Standard C++ build settings, flutter_assemble, Flutter engine library (+10 more)

### Community 14 - "main.dart"
Cohesion: 0.12
Nodes (15): build, createState, _errorMessage, initialize, _initializeApp, _initialized, initState, main (+7 more)

### Community 15 - "State"
Cohesion: 0.24
Nodes (11): AppInitializer, _AppInitializerState, HistoryScreen, _HistoryScreenState, _RecordDetailScreen, _RecordDetailScreenState, ResultScreen, _ResultScreenState (+3 more)

### Community 16 - "photo_workflow_test.dart"
Cohesion: 0.29
Nodes (6): package:flutter/services.dart, package:ph_analyzer/screens/history_screen.dart, package:ph_analyzer/screens/roi_selector.dart, package:ph_analyzer/services/history_service.dart, main, waitFor

### Community 17 - "export_service.dart"
Cohesion: 0.07
Nodes (31): dart:isolate, dart:math, dart:typed_data, image_geometry.dart, analyze, AnalyzerService, analyzeWithCalibration, createReport (+23 more)

### Community 18 - "color_converter.dart"
Cohesion: 0.14
Nodes (13): ColorConverter, _delta, _deltaCubed, deltaLab, _f, _factor, _linearize, rgbToLab (+5 more)

### Community 19 - "measurement.dart"
Cohesion: 0.08
Nodes (25): bool get, algorithm, algorithmVersion, AnalysisResult, backgroundRgb, backgroundThumbnail, calibrationHash, calibrationId (+17 more)

### Community 20 - "history_service.dart"
Cohesion: 0.07
Nodes (30): dart:async, Diagnostics, _events, _file, initialize, record, summary, _writes (+22 more)

### Community 21 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 22 - "package:flutter/material.dart"
Cohesion: 0.18
Nodes (11): PHAnalyzerApp, GuideScreen, GlassContainer, build, errorMessage, ErrorScreen, LoadingScreen, onRetry (+3 more)

### Community 23 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 24 - "dart:io"
Cohesion: 0.20
Nodes (10): dart:io, Directory, FilledButton, package:hive/hive.dart, package:ph_analyzer/models/prediction_record.dart, package:ph_analyzer/screens/home_screen.dart, package:ph_analyzer/screens/live_camera_screen.dart, main (+2 more)

### Community 25 - "Photograph of labeled colored paper strips"
Cohesion: 0.22
Nodes (9): Acetic acid strip, Dilute hydrochloric acid strip, KOH strip, Lemon strip, NH3 strip, Partially cropped HCl label, Photograph of labeled colored paper strips, Soap solution strip (+1 more)

### Community 26 - "dashed_circle_painter.dart"
Cohesion: 0.25
Nodes (7): Color, color, dashCount, gapRatio, paint, shouldRepaint, strokeWidth

### Community 27 - "production_regression_test.dart"
Cohesion: 0.11
Nodes (17): FileSystemException, int get, package:ph_analyzer/models/calibration_data.dart, package:ph_analyzer/models/measurement.dart, package:ph_analyzer/services/analyzer_isolate.dart, package:ph_analyzer/services/export_service.dart, package:ph_analyzer/services/image_geometry.dart, package:ph_analyzer/services/image_preparation.dart (+9 more)

### Community 28 - "List"
Cohesion: 0.25
Nodes (7): CubicSpline, h, interpolate, m, x, y, List

### Community 29 - "Photograph of labeled colored paper strips"
Cohesion: 0.22
Nodes (9): Acetic acid strip, Dilute hydrochloric acid strip, KOH strip, Lemon strip, NH3 strip, Partially cropped HCl label, Photograph of labeled colored paper strips, Soap solution strip (+1 more)

### Community 30 - "ph_pipeline_test.dart"
Cohesion: 0.16
Nodes (13): dart:ui, Exception, LuminanceException, MeasurementQualityException, package:flutter_test/flutter_test.dart, package:ph_analyzer/services/color_converter.dart, package:ph_analyzer/services/cubic_spline.dart, package:ph_analyzer/services/ph_analyzer.dart (+5 more)

### Community 31 - "guide_screen.dart"
Cohesion: 0.29
Nodes (6): build, _buildHeaderBanner, _buildStepCard, _buildTipRow, _buildTipsCard, live_camera_screen.dart

### Community 32 - "Release configuration and checks"
Cohesion: 0.40
Nodes (4): Android identity and signing, iOS identity, Release configuration and checks, Required verification

### Community 33 - "pH_analyzer web entry"
Cohesion: 0.40
Nodes (5): Default Flutter description, Flutter base href, Flutter web bootstrap, pH_analyzer web entry, Web app manifest

### Community 34 - "PredictionRecord"
Cohesion: 0.50
Nodes (5): HiveObject, PredictionRecord, PredictionRecordAdapter, _LegacyAdapter, TypeAdapter

### Community 92 - "Q: Understand this app and suggest improvements for production quality"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Understand this app and suggest improvements for production quality, Source Nodes

## Ambiguous Edges - Review These
- `Partially cropped HCl label` → `Photograph of labeled colored paper strips`  [AMBIGUOUS]
  assets/Reference.jpeg · relation: conceptually_related_to
- `Partially cropped HCl label` → `Photograph of labeled colored paper strips`  [AMBIGUOUS]
  Reference.jpeg · relation: conceptually_related_to

## Knowledge Gaps
- **518 isolated node(s):** `_initialized`, `_errorMessage`, `main`, `initialize`, `build` (+513 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 636 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **55 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Partially cropped HCl label` and `Photograph of labeled colored paper strips`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Partially cropped HCl label` and `Photograph of labeled colored paper strips`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `FlutterWindow` connect `Win32Window` to `AppDelegate`?**
  _High betweenness centrality (0.010) - this node is a cross-community bridge._
- **Why does `PredictionRecord` connect `PredictionRecord` to `history_screen.dart`, `prediction_record.dart`, `history_service.dart`, `dart:io`, `production_regression_test.dart`?**
  _High betweenness centrality (0.007) - this node is a cross-community bridge._
- **What connects `_initialized`, `_errorMessage`, `main` to the rest of the system?**
  _518 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05311676909569798 - nodes in this community are weakly interconnected._
- **Should `live_camera_screen.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.05128205128205128 - nodes in this community are weakly interconnected._