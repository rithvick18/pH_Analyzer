import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Exception thrown when the Gemini API returns a rate limit (HTTP 429) error.
///
/// The caller should stop the scan and ask the user to retry later.
class RateLimitException implements Exception {
  final String message;
  const RateLimitException(this.message);

  @override
  String toString() => 'RateLimitException: $message';
}

/// Result returned by [StripValidatorService.validate].
class StripValidationResult {
  /// Whether a valid pH test strip / dye pad was detected in the image.
  final bool isValid;

  /// False when connection failures prevented AI validation.
  final bool wasValidated;

  /// A brief human-readable explanation from the model.
  final String reason;

  const StripValidationResult({
    required this.isValid,
    required this.reason,
    this.wasValidated = true,
  });
}

/// Sends a cropped ROI image to Gemini 3.5 Flash Lite and asks whether the frame
/// contains a valid colorimetric pH test strip or dye pad.
///
/// Every capture attempts the API directly; unrelated connectivity probes must
/// never prevent validation. Only transport failures permit local-only analysis.
class StripValidatorService {
  /// System instruction sent to the model alongside the image.
  ///
  /// Acts as an expert laboratory colorimetry inspector: it defines acceptance
  /// criteria, rejection cases, and enforces a strict JSON-only response schema.
  static const String _systemInstruction =
      'You are an expert laboratory vision model specializing in chemical colorimetry. '
      'Your task is to analyze close-up crop images from a smartphone camera and '
      'determine if the image contains a valid colorimetric pH test strip, indicator '
      'paper, or synthetic dye pad. '
      'Evaluation Criteria: '
      'Mark isValid true ONLY if you see an indicator dye pad, test strip matrix, or '
      'colorimetric paper designed for optical fluid/pH testing. '
      'Mark isValid false if the image shows plain paper without a dye pad, human '
      'skin/fingers, household objects, extreme glare, or solid background texture. '
      'Keep reason under 15 words, explaining clearly why the frame was accepted or rejected. '
      'Respond ONLY with a valid JSON object: {"isValid": true/false, "reason": "brief explanation"}. '
      'Do not include markdown, code fences, or any text outside the JSON object.';

  /// The Gemini model identifier to use for vision inference.
  static const String _modelId = 'gemini-3.5-flash-lite';

  /// Validates [imageBytes] (JPEG / PNG bytes of the dye-pad ROI crop) against
  /// the Gemini vision API.
  ///
  /// Missing credentials, API errors, and malformed responses stop analysis.
  /// Transport failures are retried once before allowing local CIELAB analysis.
  /// [request] substitutes the API request for deterministic tests.
  static Future<StripValidationResult> validate({
    required Uint8List imageBytes,
    required String? apiKey,
    String mimeType = 'image/jpeg',
    Future<String> Function()? request,
  }) async {
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('AI validation requires a configured GEMINI_API_KEY.');
    }

    try {
      final model = GenerativeModel(
        model: _modelId,
        apiKey: apiKey.trim(),
        systemInstruction: Content.system(_systemInstruction),
        // Low temperature + native JSON MIME type for deterministic,
        // structured output without markdown wrapping.
        generationConfig: GenerationConfig(
          temperature: 0.0,
          maxOutputTokens: 150,
          responseMimeType: 'application/json',
        ),
      );

      final prompt = [
        Content.multi([
          DataPart(mimeType, imageBytes),
          TextPart('Does this image contain a pH test strip or dye pad?'),
        ]),
      ];

      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final rawText =
              await (request != null
                      ? request()
                      : model
                            .generateContent(prompt)
                            .then((response) => response.text ?? ''))
                  .timeout(const Duration(seconds: 20));
          return _parseResponse(rawText);
        } on SocketException {
          if (attempt == 0) continue;
        } on TimeoutException {
          if (attempt == 0) continue;
        }
      }
      return const StripValidationResult(
        isValid: true,
        wasValidated: false,
        reason:
            'AI connection unavailable after retry — using local CIELAB analysis.',
      );
    } catch (e) {
      if (_isRateLimitError(e)) {
        throw const RateLimitException(
          'AI rate limit reached. Please retry later.',
        );
      }
      rethrow;
    }
  }

  /// Returns true if [error] indicates a Gemini API rate limit (HTTP 429).
  ///
  /// The `google_generative_ai` package surfaces rate limits as
  /// [ServerException] with messages containing "429" or
  /// "RESOURCE_EXHAUSTED".
  static bool _isRateLimitError(Object error) {
    if (error is ServerException) {
      final msg = error.message.toUpperCase();
      return msg.contains('429') ||
          msg.contains('RESOURCE_EXHAUSTED') ||
          msg.contains('RATE_LIMIT') ||
          msg.contains('QUOTA');
    }
    // Also check the generic message string for safety.
    final errorStr = error.toString().toUpperCase();
    return errorStr.contains('429') ||
        errorStr.contains('RESOURCE_EXHAUSTED') ||
        errorStr.contains('RATE_LIMIT');
  }

  /// Parses the JSON string returned by Gemini into a [StripValidationResult].
  ///
  /// Handles model responses wrapped in markdown code fences.
  /// Rejects malformed responses instead of treating them as AI approval.
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
        throw const FormatException('AI validation returned no JSON object.');
      }

      final String jsonStr = cleaned.substring(start, end + 1);
      final dynamic decoded = jsonDecode(jsonStr);

      if (decoded is! Map) {
        throw const FormatException(
          'AI validation returned an invalid object.',
        );
      }

      final Map<String, dynamic> result = Map<String, dynamic>.from(decoded);

      final dynamic isValidRaw = result['isValid'];
      final dynamic reasonRaw = result['reason'];

      if (isValidRaw is! bool) {
        throw const FormatException('AI validation omitted a boolean isValid.');
      }
      final bool isValid = isValidRaw;

      final String reason = reasonRaw is String
          ? reasonRaw
          : (reasonRaw?.toString() ?? 'No reason provided.');

      return StripValidationResult(isValid: isValid, reason: reason);
    } catch (_) {
      throw const FormatException(
        'AI validation response could not be read. Please retry.',
      );
    }
  }
}
