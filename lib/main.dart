import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'models/prediction_record.dart';
import 'screens/home_screen.dart';
import 'widgets/loading_screen.dart';
import 'services/history_service.dart';
import 'services/ph_analyzer.dart';
import 'services/diagnostics.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enhanced error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    Diagnostics.record('framework', details.exception);
  };

  // Platform-specific error handling
  PlatformDispatcher.instance.onError = (error, stack) {
    Diagnostics.record('platform', error);
    return true;
  };

  await Diagnostics.initialize();
  runApp(const AppInitializer());
}

class PHAnalyzerApp extends StatelessWidget {
  const PHAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pH Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B), // Vibrant Teal
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00897B),
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Platform-specific initialization
      debugPrint('Starting app initialization on $defaultTargetPlatform');

      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PredictionRecordAdapter());
      }
      await HistoryService.getBox();
      await PHAnalyzer().trainFromAssets();
      try {
        await HistoryService.cleanupOrphans();
        final tempDir = await getTemporaryDirectory();
        final analysisDir = Directory('${tempDir.path}/ph_analysis');
        if (await analysisDir.exists()) {
          await for (final entry in analysisDir.list(followLinks: false)) {
            if (entry is File &&
                DateTime.now().difference(await entry.lastModified()).inHours >=
                    24) {
              await entry.delete();
            }
          }
        }
      } on FileSystemException {
        debugPrint('Temporary file cleanup deferred.');
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      Diagnostics.record('initialization', e);

      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to open local history or calibration. Check available storage and retry. Existing history has not been cleared.';
        });
      }
    }
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _initialized = false;
      _errorMessage = null;
    });
    await _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ErrorScreen(
          errorMessage: _errorMessage!,
          onRetry: _retryInitialization,
        ),
      );
    }

    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingScreen(),
      );
    }

    return const PHAnalyzerApp();
  }
}
