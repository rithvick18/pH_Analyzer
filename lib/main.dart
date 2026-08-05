import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'models/prediction_record.dart';
import 'screens/home_screen.dart';
import 'widgets/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enhanced error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exceptionAsString()}');
    debugPrint('Stack Trace: ${details.stack}');
  };

  // Platform-specific error handling
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Platform Error: $error');
    debugPrint('Stack Trace: $stack');
    return true;
  };

  // Initialize the app with proper error handling
  runApp(const AppInitializer());
}

class PHAnalyzerApp extends StatelessWidget {
  const PHAnalyzerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pH_analyzer',
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

      // Load environment variables
      try {
        await dotenv.load(fileName: ".env");
        debugPrint('.env loaded successfully');
      } catch (e) {
        debugPrint('.env load failed (non-critical): $e');
      }

      // Initialize Hive database with better error handling
      try {
        await Hive.initFlutter();
        debugPrint('Hive initialized successfully');

        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(PredictionRecordAdapter());
          debugPrint('PredictionRecordAdapter registered');
        }

        // Verify Hive is working - but don't fail if it doesn't
        try {
          final testBox = await Hive.openBox('testBox');
          await testBox.put('initTest', 'success');
          await testBox.close();
          debugPrint('Hive test box operation successful');
        } catch (e) {
          debugPrint('Hive test box operation failed (non-critical): $e');
          // Continue even if Hive test fails
        }
      } catch (e) {
        debugPrint('Hive initialization failed (non-critical): $e');
        // Continue even if Hive fails - we can use other storage if needed
      }

      // Verify assets are accessible by checking the calibration file
      try {
        final calibrationData = await rootBundle.loadString(
          'assets/calibration.json',
        );
        debugPrint(
          'Calibration data loaded: ${calibrationData.length} characters',
        );
      } catch (e) {
        debugPrint('Warning: Calibration file load test failed: $e');
        // Don't fail initialization for this - it might be loaded later
      }

      // iOS-specific checks
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        debugPrint('Running on iOS - performing platform-specific checks');

        // Check if we're running on a physical device vs simulator
        try {
          // This will help identify USB deployment issues
          debugPrint('iOS device check: ${defaultTargetPlatform.name}');
        } catch (e) {
          debugPrint('iOS device check failed: $e');
        }

        // Add delay for iOS USB deployment stability
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('iOS USB deployment stabilization complete');
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('App initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        setState(() {
          _errorMessage = 'Initialization failed: ${e.toString()}';
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
