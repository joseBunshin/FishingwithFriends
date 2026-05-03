import 'dart:typed_data';

import 'package:fishing_with_friends/features/storytelling/application/share_card_export.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// HEIC magic-byte sequence: 4 bytes size + 'ftyp' + 'heic'. Anything
/// after byte 12 doesn't matter — `decodeImage` rejects on the brand.
Uint8List _heicMagicBytes() {
  return Uint8List.fromList([
    0, 0, 0, 24, // size
    0x66, 0x74, 0x79, 0x70, // 'ftyp'
    0x68, 0x65, 0x69, 0x63, // 'heic'
    0, 0, 0, 0, // minor version
    0x68, 0x65, 0x69, 0x63, // compatible brand
    0x6D, 0x69, 0x66, 0x31, // 'mif1'
  ]);
}

void main() {
  late ProviderContainer container;
  late ShareCardExporter exporter;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    exporter = container.read(shareCardExporterProvider);
  });

  group('ShareCardExporter.decodeImage falsification guards', () {
    // The happy-path codec round-trip and the full ShareCard offscreen
    // capture both rely on `ui.instantiateImageCodec`, which hangs in
    // the flutter_test environment on Windows (no engine codec). Manual
    // QA on a real device covers the production codec path; the tests
    // below cover the guards that don't touch the codec — the same
    // guards that exist specifically so a future "still shipping navy"
    // report has the diagnostic data to skip straight to root cause.

    test('HEIC bytes return null and log without throwing', () async {
      final logged = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? msg, {int? wrapWidth}) {
        if (msg != null) logged.add(msg);
      };
      addTearDown(() => debugPrint = originalDebugPrint);

      final decoded = await exporter.decodeImage(_heicMagicBytes());

      expect(decoded, isNull);
      expect(
        logged.any((line) => line.contains('HEIC')),
        isTrue,
        reason: 'decodeImage must surface HEIC detection in logs so '
            'future "still navy" reports can rule it in or out.',
      );
    });

    test('empty bytes return null without throwing', () async {
      final decoded = await exporter.decodeImage(Uint8List(0));
      expect(decoded, isNull);
    });

    // Malformed-bytes test (length < 12 of garbage data) is omitted: it
    // bypasses the HEIC magic-byte gate (length < 12) and reaches
    // ui.instantiateImageCodec, which in flutter_test on Windows
    // hangs rather than erroring. The production code's try/catch
    // correctly returns null on codec failure — verified manually on
    // device by deliberately sharing a corrupt photo (returns navy
    // fallback + SnackBar instead of crashing).
  });
}
