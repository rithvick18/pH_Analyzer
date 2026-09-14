import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ph_analyzer/services/strip_validator_service.dart';

void main() {
  Future<StripValidationResult> validate(Future<String> Function() request) =>
      StripValidatorService.validate(
        imageBytes: Uint8List.fromList([1]),
        apiKey: 'test-key',
        request: request,
      );

  test('online captures use AI acceptance and rejection', () async {
    for (final accepted in [true, false]) {
      final result = await validate(
        () async => '{"isValid": $accepted, "reason": "Checked image"}',
      );
      expect(result.isValid, accepted);
      expect(result.wasValidated, isTrue);
    }
  });

  test('transient connection failure retries AI validation', () async {
    var calls = 0;
    final result = await validate(() async {
      if (++calls == 1) throw const SocketException('Temporary DNS failure');
      return '{"isValid": true, "reason": "Dye pad"}';
    });
    expect(calls, 2);
    expect(result.wasValidated, isTrue);
  });

  test(
    'persistent transport failures allow explicitly unvalidated output',
    () async {
      for (final error in [
        const SocketException('Offline'),
        TimeoutException('Slow'),
      ]) {
        var calls = 0;
        final result = await validate(() async {
          calls++;
          throw error;
        });
        expect(calls, 2);
        expect(result.wasValidated, isFalse);
      }
      final recovered = await validate(() async => '{"isValid":true}');
      expect(recovered.wasValidated, isTrue);
    },
  );

  test(
    'API errors and malformed responses cannot silently approve a scan',
    () async {
      await expectLater(
        validate(() async => throw Exception('403 Forbidden')),
        throwsException,
      );
      await expectLater(
        validate(() async => throw Exception('429 RESOURCE_EXHAUSTED')),
        throwsA(isA<RateLimitException>()),
      );
      for (final response in ['', 'invalid', '{}', '{"isValid":"true"}']) {
        await expectLater(
          validate(() async => response),
          throwsFormatException,
        );
      }
    },
  );

  test('missing API key prevents unvalidated online output', () async {
    await expectLater(
      StripValidatorService.validate(imageBytes: Uint8List(0), apiKey: ''),
      throwsStateError,
    );
  });
}
