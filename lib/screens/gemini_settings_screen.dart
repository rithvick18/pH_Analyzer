import 'package:flutter/material.dart';
import '../services/gemini_validator_service.dart';

class GeminiSettingsScreen extends StatefulWidget {
  const GeminiSettingsScreen({super.key});
  @override
  State<GeminiSettingsScreen> createState() => _GeminiSettingsScreenState();
}

class _GeminiSettingsScreenState extends State<GeminiSettingsScreen> {
  final controller = TextEditingController();
  bool saved = false;
  bool busy = false;
  bool visible = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      if (mounted) setState(() {});
    });
    GeminiValidatorService.readKey()
        .then((key) {
          if (mounted) setState(() => saved = key != null && key.isNotEmpty);
        })
        .catchError((Object _) {
          if (mounted) setState(() => error = 'Could not read secure storage.');
        });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await GeminiValidatorService.testKey(controller.text);
      await GeminiValidatorService.saveKey(controller.text);
      controller.clear();
      if (mounted) setState(() => saved = true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> remove() async {
    await GeminiValidatorService.deleteKey();
    if (mounted) setState(() => saved = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gemini validation setup')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Enter your own Gemini API key. The key is stored in this device’s secure storage. Photos of the selected dye pad are sent to Gemini for identity checks; pH is calculated on this device.',
          ),
          const SizedBox(height: 20),
          Text(
            saved
                ? 'Gemini validation is enabled. API key saved on this device.'
                : 'Manual mode is enabled. Photos are analyzed locally without AI identity checks.',
          ),
          TextField(
            controller: controller,
            obscureText: !visible,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: saved ? 'Replace API key' : 'Gemini API key',
              suffixIcon: IconButton(
                tooltip: visible ? 'Hide key' : 'Show key',
                onPressed: () => setState(() => visible = !visible),
                icon: Icon(visible ? Icons.visibility_off : Icons.visibility),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy || controller.text.trim().isEmpty ? null : save,
            child: Text(
              busy ? 'Testing connection…' : 'Test connection and save',
            ),
          ),
          if (saved)
            TextButton(
              onPressed: busy ? null : remove,
              child: const Text('Switch to manual mode and delete key'),
            ),
          if (saved)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
        ],
      ),
    ),
  );
}
