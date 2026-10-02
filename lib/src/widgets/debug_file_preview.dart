import 'dart:io';
import 'dart:typed_data';

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
      return _SvgFilePreview(file: file);
    }

    return MultiAssetPlayer(sourceFor(file));
  }
}

class _SvgFilePreview extends StatefulWidget {
  const _SvgFilePreview({required this.file});

  final File file;

  @override
  State<_SvgFilePreview> createState() => _SvgFilePreviewState();
}

class _SvgFilePreviewState extends State<_SvgFilePreview> {
  late Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  void didUpdateWidget(_SvgFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _bytes = widget.file.readAsBytes();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load SVG preview'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SvgPicture.memory(
          snapshot.data!,
          key: const Key('debug_file_svg_preview'),
          fit: BoxFit.contain,
          placeholderBuilder: (context) =>
              const Center(child: CircularProgressIndicator()),
        );
      },
    );
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
