import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:universal_file_previewer/universal_file_previewer.dart';

/// Displays a file using the universal previewer, with native SVG rendering.
///
/// `universal_file_previewer` categorizes SVG documents as XML text. SVG is a
/// textual format, but users generally expect to see the rendered vector, so
/// SVG files are handled explicitly before falling back to the package.
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

    return FilePreviewWidget(
      file: file,
      config: const PreviewConfig(
        showToolbar: false,
        showFileInfo: false,
        enableZoom: true,
        codeTheme: CodeTheme.dark,
      ),
    );
  }
}
