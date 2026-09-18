# Graph Report - pH_analyzer  (2026-09-18)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 924 nodes · 1121 edges · 98 communities (38 shown, 56 thin omitted)
- Extraction: 98% EXTRACTED · 2% INFERRED · 0% AMBIGUOUS · INFERRED: 23 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `a157aa78`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- Win32Window
- export_service.dart
- live_camera_screen.dart
- AppDelegate
- result_screen.dart
- home_screen.dart
- Release configuration and checks
- roi_selector.dart
- history_service.dart
- history_screen.dart
- ph_analyzer.dart
- lab_theme.dart
- my_application.cc
- measurement.dart
- prediction_record.dart
- ph_analyzer package
- calibration_data.dart
- production_regression_test.dart
- Linux application build
- main.dart
- pH Analyzer
- ph_pipeline_test.dart
- color_converter.dart
- dart:io
- Measurement validation before accuracy claims
- wWinMain
- package:flutter/material.dart
- manifest.json
- Photograph of labeled colored paper strips
- Photograph of labeled colored paper strips
- dashed_circle_painter.dart
- List
- guide_screen.dart
- photo_workflow_test.dart
- Q: Understand this app and suggest improvements for production quality
- PredictionRecord
- pH_analyzer web entry
- Calibration anchors
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
- assets/Reference.jpeg
- hive
- check_offline_assets.py
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

## God Nodes (most connected - your core abstractions)
1. `ph_analyzer package` - 25 edges
2. `pH Analyzer` - 25 edges
3. `Win32Window` - 24 edges
4. `Release configuration and checks` - 20 edges
5. `Flutter checks` - 13 edges
6. `MessageHandler` - 12 edges
7. `Measurement validation before accuracy claims` - 11 edges
8. `FlutterWindow` - 10 edges
9. `Create` - 10 edges
10. `WndProc` - 10 edges

## Surprising Connections (you probably didn't know these)
- `Linux application build` --semantically_similar_to--> `Windows application build`  [INFERRED] [semantically similar]
  linux/CMakeLists.txt → windows/CMakeLists.txt
- `ph_analyzer package` --references--> `assets/calibration.json`  [EXTRACTED]
  pubspec.yaml → README.md
- `pH Analyzer` --references--> `Measurement validation before accuracy claims`  [EXTRACTED]
  README.md → docs/measurement_validation.md
- `pH Analyzer` --references--> `Release configuration and checks`  [EXTRACTED]
  README.md → docs/release.md
- `Measurement provenance` --conceptually_related_to--> `crypto`  [INFERRED]
  README.md → pubspec.yaml

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Release compilation verification** — _github_workflows_flutter_locked_dependency_resolution, _github_workflows_flutter_unsigned_ios_release_compile, _github_workflows_flutter_unsigned_android_release_compile, _github_workflows_flutter_android_apk_offline_asset_check [EXTRACTED 1.00]
- **Independent measurement validation** — docs_measurement_validation_paired_reference_measurements, docs_measurement_validation_independent_validation_split, docs_measurement_validation_measurement_acceptance_metrics, docs_measurement_validation_owner_validation_release_gate [EXTRACTED 1.00]
- **Acquisition to saved estimate** — readme_still_image_capture, readme_region_of_interest_extraction, readme_cielab_spline_matching, readme_measurement_provenance, readme_explicit_pdf_sharing [EXTRACTED 1.00]

## Communities (98 total, 56 thin omitted)

### Community 0 - "Win32Window"
Cohesion: 0.05
Nodes (57): PluginRegistry, unique_ptr, RegisterPlugins(), DartProject, HWND, LPARAM, LRESULT, UINT (+49 more)

### Community 1 - "export_service.dart"
Cohesion: 0.05
Nodes (42): dart:isolate, dart:math, dart:typed_data, dart:ui, image_geometry.dart, analyze, AnalyzerService, analyzeWithCalibration (+34 more)

### Community 2 - "live_camera_screen.dart"
Cohesion: 0.05
Nodes (46): CameraController?, FlashMode, Future, AppInitializer, _AppInitializerState, _active, build, _camera (+38 more)

### Community 3 - "AppDelegate"
Cohesion: 0.06
Nodes (28): Any, Cocoa, file_selector_macos, Flutter, FlutterAppDelegate, FlutterImplicitEngineBridge, FlutterImplicitEngineDelegate, FlutterMacOS (+20 more)

### Community 4 - "result_screen.dart"
Cohesion: 0.05
Nodes (38): Animation, AnimationController, _animController, bgRect, _bgRgb, _bgThumbnail, build, _buildColorimetrySection (+30 more)

### Community 5 - "home_screen.dart"
Cohesion: 0.06
Nodes (38): guide_screen.dart, history_screen.dart, build, build, _buildBottomNavBar, _buildCameraReadyStatus, _buildDottedLineConnector, _buildHeaderBar (+30 more)

### Community 6 - "Release configuration and checks"
Cohesion: 0.07
Nodes (32): Android APK offline asset check, Cancel superseded runs, Dart formatting check, Flutter checks, Flutter static analysis, Flutter tests with coverage, Locked dependency resolution, Offline release input check (+24 more)

### Community 7 - "roi_selector.dart"
Cohesion: 0.06
Nodes (32): _adjust, build, _busy, _bytes, capturedAt, createState, dispose, _dye (+24 more)

### Community 8 - "history_service.dart"
Cohesion: 0.07
Nodes (30): dart:async, Diagnostics, _events, _file, initialize, record, summary, _writes (+22 more)

### Community 9 - "history_screen.dart"
Cohesion: 0.07
Nodes (30): CustomPainter, bgRect, _confirmDelete, createState, decoded, dyeRect, _getPhColor, HistoryScreen (+22 more)

### Community 10 - "ph_analyzer.dart"
Cohesion: 0.07
Nodes (29): color_converter.dart, cubic_spline.dart, _calibration, calibrationHash, calibrationId, colorDistance, deltaLab, estimateFromRgb (+21 more)

### Community 11 - "lab_theme.dart"
Cohesion: 0.07
Nodes (27): EdgeInsetsGeometry?, bgDark, blur, borderColor, borderDark, borderRadius, boxShadow, build (+19 more)

### Community 12 - "my_application.cc"
Cohesion: 0.09
Nodes (22): FlPluginRegistry, FlView, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins() (+14 more)

### Community 13 - "measurement.dart"
Cohesion: 0.08
Nodes (25): bool get, algorithm, algorithmVersion, AnalysisResult, backgroundRgb, backgroundThumbnail, calibrationHash, calibrationId (+17 more)

### Community 14 - "prediction_record.dart"
Cohesion: 0.08
Nodes (25): DateTime?, double?, Measurement, bgHeight, bgLeft, bgTop, bgWidth, dyeHeight (+17 more)

### Community 15 - "ph_analyzer package"
Cohesion: 0.09
Nodes (23): Flutter analyzer lint configuration, assets/logo.png, assets/logo.svg, camera, cupertino_icons, Dart SDK 3.11.4 constraint, Flutter, flutter_colorpicker (+15 more)

### Community 16 - "calibration_data.dart"
Cohesion: 0.11
Nodes (17): dart:convert, anchors, bgRgb, CalibrationAnchor, CalibrationData, dyeRgb, fromJson, fromJsonString (+9 more)

### Community 17 - "production_regression_test.dart"
Cohesion: 0.11
Nodes (17): FileSystemException, int get, package:ph_analyzer/models/calibration_data.dart, package:ph_analyzer/models/measurement.dart, package:ph_analyzer/services/analyzer_isolate.dart, package:ph_analyzer/services/export_service.dart, package:ph_analyzer/services/image_geometry.dart, package:ph_analyzer/services/image_preparation.dart (+9 more)

### Community 18 - "Linux application build"
Cohesion: 0.14
Nodes (18): Application bundle installation, com.example.ph_analyzer application ID, Generated plugin build rules, GTK 3 dependency, Linux application build, Standard C++ build settings, flutter_assemble, Flutter engine library (+10 more)

### Community 19 - "main.dart"
Cohesion: 0.12
Nodes (15): build, createState, _errorMessage, initialize, _initializeApp, _initialized, initState, main (+7 more)

### Community 20 - "pH Analyzer"
Cohesion: 0.15
Nodes (16): crypto, Android and iOS release targets, Bounded image inputs, Calibration hash preservation, Experimental pH estimates, Explicit PDF sharing, Measurement provenance, Offline edge computing (+8 more)

### Community 21 - "ph_pipeline_test.dart"
Cohesion: 0.18
Nodes (12): Exception, LuminanceException, MeasurementQualityException, package:flutter_test/flutter_test.dart, package:ph_analyzer/services/color_converter.dart, package:ph_analyzer/services/cubic_spline.dart, package:ph_analyzer/services/ph_analyzer.dart, package:ph_analyzer/services/robust_extractor.dart (+4 more)

### Community 22 - "color_converter.dart"
Cohesion: 0.14
Nodes (13): ColorConverter, _delta, _deltaCubed, deltaLab, _f, _factor, _linearize, rgbToLab (+5 more)

### Community 23 - "dart:io"
Cohesion: 0.20
Nodes (10): dart:io, Directory, FilledButton, package:hive/hive.dart, package:ph_analyzer/models/prediction_record.dart, package:ph_analyzer/screens/home_screen.dart, package:ph_analyzer/screens/live_camera_screen.dart, main (+2 more)

### Community 24 - "Measurement validation before accuracy claims"
Cohesion: 0.20
Nodes (11): Empirical uncertainty calibration, Holdout threshold evaluation, Independent validation split, Intended operating envelope, Measurement acceptance metrics, Measurement validation before accuracy claims, Negative and adverse captures, Owner validation release gate (+3 more)

### Community 25 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 26 - "package:flutter/material.dart"
Cohesion: 0.18
Nodes (11): PHAnalyzerApp, GuideScreen, GlassContainer, build, errorMessage, ErrorScreen, LoadingScreen, onRetry (+3 more)

### Community 27 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 28 - "Photograph of labeled colored paper strips"
Cohesion: 0.22
Nodes (9): Acetic acid strip, Dilute hydrochloric acid strip, KOH strip, Lemon strip, NH3 strip, Partially cropped HCl label, Photograph of labeled colored paper strips, Soap solution strip (+1 more)

### Community 29 - "Photograph of labeled colored paper strips"
Cohesion: 0.22
Nodes (9): Acetic acid strip, Dilute hydrochloric acid strip, KOH strip, Lemon strip, NH3 strip, Partially cropped HCl label, Photograph of labeled colored paper strips, Soap solution strip (+1 more)

### Community 30 - "dashed_circle_painter.dart"
Cohesion: 0.25
Nodes (7): Color, color, dashCount, gapRatio, paint, shouldRepaint, strokeWidth

### Community 31 - "List"
Cohesion: 0.25
Nodes (7): CubicSpline, h, interpolate, m, x, y, List

### Community 32 - "guide_screen.dart"
Cohesion: 0.29
Nodes (6): build, _buildHeaderBanner, _buildStepCard, _buildTipRow, _buildTipsCard, live_camera_screen.dart

### Community 33 - "photo_workflow_test.dart"
Cohesion: 0.29
Nodes (6): package:flutter/services.dart, package:ph_analyzer/screens/history_screen.dart, package:ph_analyzer/screens/roi_selector.dart, package:ph_analyzer/services/history_service.dart, main, waitFor

### Community 34 - "Q: Understand this app and suggest improvements for production quality"
Cohesion: 0.40
Nodes (4): Answer, Outcome, Q: Understand this app and suggest improvements for production quality, Source Nodes

### Community 35 - "PredictionRecord"
Cohesion: 0.50
Nodes (5): HiveObject, PredictionRecord, PredictionRecordAdapter, _LegacyAdapter, TypeAdapter

### Community 36 - "pH_analyzer web entry"
Cohesion: 0.40
Nodes (5): Default Flutter description, Flutter base href, Flutter web bootstrap, pH_analyzer web entry, Web app manifest

### Community 37 - "Calibration anchors"
Cohesion: 0.50
Nodes (4): assets/calibration.json, Calibration anchors, Calibration schema 1, Numerical pH resolution

## Ambiguous Edges - Review These
- `Partially cropped HCl label` → `Photograph of labeled colored paper strips`  [AMBIGUOUS]
  assets/Reference.jpeg · relation: conceptually_related_to
- `Partially cropped HCl label` → `Photograph of labeled colored paper strips`  [AMBIGUOUS]
  Reference.jpeg · relation: conceptually_related_to

## Knowledge Gaps
- **520 isolated node(s):** `flutter_controller_`, `project_`, `x`, `y`, `height` (+515 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 657 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **56 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **What is the exact relationship between `Partially cropped HCl label` and `Photograph of labeled colored paper strips`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **What is the exact relationship between `Partially cropped HCl label` and `Photograph of labeled colored paper strips`?**
  _Edge tagged AMBIGUOUS (relation: conceptually_related_to) - confidence is low._
- **Why does `FlutterWindow` connect `Win32Window` to `AppDelegate`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **Why does `PredictionRecord` connect `PredictionRecord` to `history_service.dart`, `history_screen.dart`, `prediction_record.dart`, `production_regression_test.dart`, `dart:io`?**
  _High betweenness centrality (0.006) - this node is a cross-community bridge._
- **What connects `flutter_controller_`, `project_`, `x` to the rest of the system?**
  _520 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Win32Window` be split into smaller, more focused modules?**
  _Cohesion score 0.05311676909569798 - nodes in this community are weakly interconnected._
- **Should `export_service.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.054078014184397165 - nodes in this community are weakly interconnected._