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

  final File file;

  @override
  Widget build(BuildContext context) {
    if (file.path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(
        file,
        key: const Key('debug_file_svg_preview'),
        fit: BoxFit.contain,
        placeholderBuilder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return MultiAssetPlayer(file.path);
  }
}
