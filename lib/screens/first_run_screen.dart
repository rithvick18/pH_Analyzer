import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/calibration_profile_service.dart';
import '../services/gemini_validator_service.dart';
import 'calibration_manager_screen.dart';
import 'gemini_settings_screen.dart';
import 'home_screen.dart';

class FirstRunScreen extends StatefulWidget {
  const FirstRunScreen({super.key});
  static const boxName = 'app_setup';
  static const completeKey = 'calibration_complete';

  @override
  State<FirstRunScreen> createState() => _FirstRunScreenState();
}

class _FirstRunScreenState extends State<FirstRunScreen> {
  bool checking = true;
  bool keyReady = false;
  bool manualSelected = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    refreshKey();
  }

  Future<void> refreshKey() async {
    try {
      final key = await GeminiValidatorService.readKey();
      if (mounted) {
        setState(() {
          keyReady = key != null && key.isNotEmpty;
          if (keyReady) manualSelected = false;
          checking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Could not read secure storage: $e';
          checking = false;
        });
      }
    }
  }

  Future<void> finish(String id) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await CalibrationProfileService.select(id);
      final box = Hive.isBoxOpen(FirstRunScreen.boxName)
          ? Hive.box<bool>(FirstRunScreen.boxName)
          : await Hive.openBox<bool>(FirstRunScreen.boxName);
      await box.put(FirstRunScreen.completeKey, true);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const HomeScreen(openCaptureOnStart: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not finish setup: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> createProfile() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CalibrationProfileEditor()),
    );
    if (id != null) await finish(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up pH Analyzer')),
    body: SafeArea(
      child: checking
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  keyReady || manualSelected
                      ? 'Choose a calibration'
                      : 'Choose image validation',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (!keyReady && !manualSelected) ...[
                  const Text(
                    'Gemini can check whether a photo shows a dye pad. You can also estimate pH locally in manual mode without an API key or AI image check.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GeminiSettingsScreen(),
                        ),
                      );
                      await refreshKey();
                    },
                    child: const Text('Enter Gemini API key'),
                  ),
                  OutlinedButton(
                    onPressed: () => setState(() => manualSelected = true),
                    child: const Text('Continue in manual mode'),
                  ),
                ] else ...[
                  const Text(
                    'Use the supplied eight-point calibration, or make a named calibration from known pH references. You can change profiles later.',
                  ),
                  if (manualSelected)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Manual mode: photos stay on this device for pH analysis. Dye-pad identity is not checked by AI.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => finish(CalibrationProfileService.bundledId),
                    child: const Text('Use default calibration'),
                  ),
                  OutlinedButton(
                    onPressed: busy ? null : createProfile,
                    child: const Text('Create my own calibration'),
                  ),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GeminiSettingsScreen(),
                        ),
                      );
                      await refreshKey();
                    },
                    child: Text(
                      manualSelected
                          ? 'Set up Gemini instead'
                          : 'Change Gemini key',
                    ),
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}
