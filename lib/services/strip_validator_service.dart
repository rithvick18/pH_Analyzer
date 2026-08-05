import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Result returned by [StripValidatorService.validate].
class StripValidationResult {
  /// Whether a valid pH test strip / dye pad was detected in the image.
  final bool isValid;

  /// A brief human-readable explanation from the model.
  final String reason;

  const StripValidationResult({required this.isValid, required this.reason});
}

/// Sends a cropped ROI image to Gemini 1.5 Flash and asks whether the frame
/// contains a valid colorimetric pH test strip or dye pad.
///
/// Fail-open design: any network error, missing API key, or malformed JSON
/// response causes the service to return [StripValidationResult.isValid] == true
/// so the normal CIELAB pipeline can still run (graceful degradation).
class StripValidatorService {
  /// System instruction sent to the model alongside the image.
  static const String _systemInstruction =
      'Analyze this image. Is there a valid colorimetric pH test strip or dye '
      'pad visible? Reply ONLY in valid JSON format: '
      '{"isValid": true/false, "reason": "brief explanation"}';

  /// The Gemini model identifier to use for vision inference.
  static const String _modelId = 'gemini-1.5-flash';

  /// Validates [imageBytes] (JPEG / PNG bytes of the dye-pad ROI crop) against
  /// the Gemini vision API.
  ///
  /// [apiKey] – your Google AI Studio API key. If empty or null, the service
  /// skips the network call and returns a valid result so the CIELAB pipeline
  /// continues uninterrupted.
  ///
  /// Never throws; all exceptions are caught and resolved to isValid == true.
  static Future<StripValidationResult> validate({
    required Uint8List imageBytes,
    required String? apiKey,
    String mimeType = 'image/jpeg',
  }) async {
    // Guard: skip validation when API key is absent to avoid hard failures.
    if (apiKey == null || apiKey.trim().isEmpty) {
      return const StripValidationResult(
        isValid: true,
        reason: 'API key not configured – validation skipped, proceeding.',
      );
    }

    try {
      final model = GenerativeModel(
        model: _modelId,
        apiKey: apiKey.trim(),
        systemInstruction: Content.system(_systemInstruction),
        // Low temperature for deterministic, structured JSON output.
        generationConfig: GenerationConfig(
          temperature: 0.0,
          maxOutputTokens: 150,
        ),
      );

      final prompt = [
        Content.multi([
          DataPart(mimeType, imageBytes),
          TextPart('Does this image contain a pH test strip or dye pad?'),
        ]),
      ];

      final response = await model.generateContent(prompt);
      final String rawText = response.text ?? '';

      return _parseResponse(rawText);
    } catch (e) {
      // Any network, quota, or unexpected error → fail-open.
      return StripValidationResult(
        isValid: true,
        reason:
            'Validation unavailable ($e) – proceeding with CIELAB analysis.',
      );
    }
  }

  /// Parses the JSON string returned by Gemini into a [StripValidationResult].
  ///
  /// Handles model responses wrapped in markdown code fences.
  /// Defaults to isValid == true on any parse failure (fail-open).
  static StripValidationResult _parseResponse(String rawText) {
    try {
      // Strip markdown code fences the model occasionally wraps around JSON.
      String cleaned = rawText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll('```', '')
            .trim();
      }

      // Locate the JSON object boundaries.
      final int start = cleaned.indexOf('{');
      final int end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) {
        return const StripValidationResult(
          isValid: true,
          reason: 'Could not locate JSON in model response – proceeding.',
        );
      }

      final String jsonStr = cleaned.substring(start, end + 1);
      final dynamic decoded = jsonDecode(jsonStr);

      if (decoded is! Map) {
        return const StripValidationResult(
          isValid: true,
          reason: 'Unexpected JSON structure – proceeding.',
        );
      }

      final Map<String, dynamic> result = Map<String, dynamic>.from(decoded);

      final dynamic isValidRaw = result['isValid'];
      final dynamic reasonRaw = result['reason'];

      final bool isValid = isValidRaw is bool
          ? isValidRaw
          : (isValidRaw?.toString().toLowerCase() == 'true');

      final String reason = reasonRaw is String
          ? reasonRaw
          : (reasonRaw?.toString() ?? 'No reason provided.');

      return StripValidationResult(isValid: isValid, reason: reason);
    } catch (_) {
      return const StripValidationResult(
        isValid: true,
        reason: 'JSON parse error – proceeding with CIELAB analysis.',
      );
    }
  }
}
