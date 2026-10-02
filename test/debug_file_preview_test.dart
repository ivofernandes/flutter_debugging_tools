import 'dart:io';

import 'package:flutter_debugging_tools/src/widgets/debug_file_preview.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DebugFilePreview.heightFor', () {
    test('allows enough height for MultiAssetPlayer audio controls', () {
      for (final extension in [
        'mp3',
        'm4a',
        'aac',
        'flac',
        'ogg',
        'opus',
        'wav',
      ]) {
        expect(
          DebugFilePreview.heightFor(
            File('/tmp/recording.$extension'),
            fallback: 160,
          ),
          360,
        );
      }
    });

    test('preserves the requested height for other previews', () {
      expect(
        DebugFilePreview.heightFor(File('/tmp/image.png'), fallback: 160),
        160,
      );
    });
  });

  group('DebugFilePreview.sourceFor', () {
    test('uses a file URI for audio playback', () {
      final file = File('/tmp/audio previews/recording.m4a');

      expect(
        DebugFilePreview.sourceFor(file),
        'file:///tmp/audio%20previews/recording.m4a',
      );
    });

    test('keeps filesystem paths for non-audio previews', () {
      final file = File('/tmp/image.png');

      expect(DebugFilePreview.sourceFor(file), file.path);
    });
  });
}
