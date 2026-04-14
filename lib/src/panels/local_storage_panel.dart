import 'package:flutter/material.dart';

/// A panel that acts as a placeholder for inspecting local storage
/// (SQLite, Hive, Isar, etc.).
///
/// Because actual storage implementation is app-specific, this panel provides
/// an injection point: pass a [customBuilder] to render your own storage
/// inspector widget inline, or leave it `null` to show the default
/// instructional text.
///
/// Example — injecting a custom SQLite browser:
/// ```dart
/// LocalStoragePanel(
///   customBuilder: (context) => MySQLiteBrowserWidget(),
/// )
/// ```
class LocalStoragePanel extends StatelessWidget {
  const LocalStoragePanel({
    this.customBuilder,
    super.key,
  });

  /// Optional builder for a custom storage inspection widget.
  ///
  /// When provided, its result is shown instead of the placeholder text.
  final WidgetBuilder? customBuilder;

  @override
  Widget build(BuildContext context) {
    if (customBuilder != null) {
      return customBuilder!(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.storage, size: 32, color: Colors.grey),
        const SizedBox(height: 8),
        const Text(
          'Local Storage Inspector',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        const Text(
          'Local storage (SQLite, Hive, Isar, …) is app-specific.\n\n'
          'Inject your own widget by passing a customBuilder to LocalStoragePanel, '
          'or to DebuggingToolsWrapper.localStorageBuilder.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Provide a customBuilder to LocalStoragePanel '
                  'to inspect your storage here.',
                ),
              ),
            );
          },
          icon: const Icon(Icons.info_outline),
          label: const Text('How to customise'),
        ),
      ],
    );
  }
}
