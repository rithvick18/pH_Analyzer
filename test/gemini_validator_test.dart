import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Rect;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:ph_analyzer/services/gemini_validator_service.dart';

void main() {
  test('accepts only a structured valid decision', () {
    String response(String status, String reason) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'text': jsonEncode({'status': status, 'reason': reason}),
              },
            ],
          },
        },
      ],
    });
    expect(
      GeminiValidatorService.parseResponse(
        response('valid', 'Pad visible'),
      ).accepted,
      isTrue,
    );
    expect(
      GeminiValidatorService.parseResponse(
        response('invalid', 'Fabric'),
      ).accepted,
      isFalse,
    );
    expect(
      GeminiValidatorService.parseResponse(
        response('uncertain', 'Blurred'),
      ).accepted,
      isFalse,
    );
    expect(
      () => GeminiValidatorService.parseResponse(response('maybe', 'Unknown')),
      throwsA(isA<PadValidationException>()),
    );
    expect(
      () => GeminiValidatorService.parseResponse('{}'),
      throwsA(isA<PadValidationException>()),
    );
  });

  test('connection check does not save a rejected key', () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'generativelanguage.googleapis.com');
      expect(request.headers['x-goog-api-key'], 'bad-key');
      return http.Response('{}', 403);
    });
    await expectLater(
      GeminiValidatorService.testKey('bad-key', client: client),
      throwsA(isA<PadValidationException>()),
    );
  });

  test(
    'sends full photo and selected crop and keeps rejection closed',
    () async {
      FlutterSecureStorage.setMockInitialValues({'gemini_api_key': 'test-key'});
      final directory = Directory.systemTemp.createTempSync('ph_gemini_');
      try {
        final image = img.Image(width: 20, height: 20);
        img.fill(image, color: img.ColorRgb8(126, 49, 44));
        final path = '${directory.path}/sample.png';
        File(path).writeAsBytesSync(img.encodePng(image));
        final client = MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final parts = ((body['contents'] as List).first['parts'] as List);
          expect(parts.length, 3);
          expect(parts[1]['inline_data']['mime_type'], 'image/jpeg');
          expect(parts[2]['inline_data']['mime_type'], 'image/jpeg');
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {
                        'text': jsonEncode({
                          'status': 'invalid',
                          'reason': 'Fabric texture',
                        }),
                      },
                    ],
                  },
                },
              ],
            }),
            200,
          );
        });
        final result = await GeminiValidatorService.validate(
          imagePath: path,
          dyeRect: const Rect.fromLTWH(2, 2, 10, 10),
          client: client,
        );
        expect(result.accepted, isFalse);
        expect(result.reason, 'Fabric texture');
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
}
