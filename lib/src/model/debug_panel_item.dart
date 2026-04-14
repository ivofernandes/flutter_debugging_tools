import 'package:flutter/material.dart';

/// A single panel item for the [DebuggingDrawer].
///
/// Each item has a [title] shown in the expansion panel header,
/// a [body] widget rendered when the panel is expanded,
/// and an [expanded] flag controlling the initial open/closed state.
class DebugPanelItem {
  final String title;
  final Widget body;
  bool expanded;

  DebugPanelItem(
    this.title,
    this.body, {
    this.expanded = false,
  });
}
