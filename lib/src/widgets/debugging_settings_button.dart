import 'package:flutter/material.dart';

/// A draggable floating button that opens the [Scaffold] drawer.
///
/// Place this inside a [Stack] on top of your app content and pass the
/// [scaffoldKey] of the [Scaffold] that owns the [DebuggingDrawer].
///
/// The button is draggable so it never blocks the UI permanently.
class DebuggingSettingsButton extends StatefulWidget {
  const DebuggingSettingsButton({
    required this.scaffoldKey,
    this.openEndDrawer = false,
    super.key,
  });

  /// Key of the [Scaffold] whose drawer will be opened.
  final GlobalKey<ScaffoldState> scaffoldKey;

  /// When `true`, opens the end drawer instead of the start drawer.
  final bool openEndDrawer;

  @override
  State<DebuggingSettingsButton> createState() => _DebuggingSettingsButtonState();
}

class _DebuggingSettingsButtonState extends State<DebuggingSettingsButton> {
  double _top = 60;
  double _left = 16;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _top += details.delta.dy;
      _left += details.delta.dx;
    });
  }

  void _openDrawer() {
    final state = widget.scaffoldKey.currentState;
    if (state == null) return;
    if (widget.openEndDrawer) {
      state.openEndDrawer();
    } else {
      state.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onTap: _openDrawer,
        onPanUpdate: _onDragUpdate,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(24),
          color: Colors.black54,
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.bug_report,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
