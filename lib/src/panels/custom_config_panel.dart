import 'package:flutter/material.dart';

import '../model/debug_panel_item.dart';

/// A thin helper that wraps any widget as a named [DebugPanelItem].
///
/// Use this when adding custom panels to [DebuggingToolsWrapper.extraPanels]:
///
/// ```dart
/// DebuggingToolsWrapper(
///   extraPanels: [
///     CustomConfigPanel.item(
///       title: 'My Feature Flags',
///       child: MyFeatureFlagsWidget(),
///     ),
///   ],
/// )
/// ```
class CustomConfigPanel extends StatelessWidget {
  const CustomConfigPanel({
    required this.child,
    super.key,
  });

  final Widget child;

  /// Convenience factory that creates a ready-to-use [DebugPanelItem].
  static DebugPanelItem item({
    required String title,
    required Widget child,
    bool expanded = false,
  }) {
    return DebugPanelItem(
      title,
      CustomConfigPanel(child: child),
      expanded: expanded,
    );
  }

  @override
  Widget build(BuildContext context) => child;
}
