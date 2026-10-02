import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:multi_asset_player/multi_asset_player.dart';

/// Displays a file using the multi-asset player, with native SVG rendering.
///
/// SVG files are handled explicitly so users see the rendered vector rather
/// than its XML source.
class DebugFilePreview extends StatelessWidget {
  const DebugFilePreview({required this.file, super.key});

  /// Returns enough vertical space for the player used by [file].
  ///
  /// Audio controls in [MultiAssetPlayer] need more room than the default
  /// image and document previews.
  static double heightFor(File file, {required double fallback}) {
    return _isAudio(file.path) ? 360 : fallback;
  }

  /// Returns the source expected by [MultiAssetPlayer] for [file].
  ///
  /// Audio backends require a URI with a scheme. Other preview types continue
  /// to receive a filesystem path, which preserves their existing behavior.
  static String sourceFor(File file) {
    return _isAudio(file.path) ? file.uri.toString() : file.path;
  }

  final File file;

  @override
  Widget build(BuildContext context) {
    if (file.path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        file,
        key: const Key('debug_file_svg_preview'),
        fit: BoxFit.contain,
        placeholderBuilder: (context) =>
            const Center(child: CircularProgressIndicator()),
      );
    }

    return MultiAssetPlayer(sourceFor(file));
  }
}

bool _isAudio(String path) {
  final normalizedPath = path.toLowerCase();
  return _audioExtensions.any(normalizedPath.endsWith);
}

const _audioExtensions = <String>{
  '.aac',
  '.flac',
  '.m4a',
  '.mp3',
  '.ogg',
  '.opus',
  '.wav',
};
