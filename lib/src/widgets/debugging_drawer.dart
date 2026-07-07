import 'package:flutter/material.dart';

import '../model/debug_panel_item.dart';

/// A [Drawer] widget that renders a list of [DebugPanelItem]s as an
/// [ExpansionPanelList].
///
/// Typically placed in [Scaffold.drawer] or [Scaffold.endDrawer].
///
/// ```dart
/// Scaffold(
///   drawer: DebuggingDrawer(panels: [
///     DebugPanelItem('My Panel', MyPanelWidget()),
///   ]),
///   body: child,
/// )
/// ```
class DebuggingDrawer extends StatefulWidget {
  const DebuggingDrawer({
    required this.panels,
    this.headerText,
    this.width,
    this.widthFactor,
    this.resizable = true,
    this.minWidth = 304,
    this.maxWidth,
    this.onWidthChanged,
    this.onClose,
    super.key,
  }) : assert(width == null || width > 0),
       assert(widthFactor == null || widthFactor > 0 && widthFactor <= 1),
       assert(minWidth > 0),
       assert(maxWidth == null || maxWidth >= minWidth);

  /// The panels to display inside the drawer.
  final List<DebugPanelItem> panels;

  /// Optional text shown at the top of the drawer.
  final String? headerText;

  /// Optional fixed drawer width in logical pixels.
  ///
  /// Leave null to use Flutter's default [Drawer] width. For a drawer that
  /// takes the whole screen, prefer [widthFactor] with a value of `1` so the
  /// width follows orientation and window-size changes.
  final double? width;

  /// Optional drawer width as a fraction of the current screen width.
  ///
  /// Must be greater than `0` and less than or equal to `1`. A value of `1`
  /// makes the drawer take the entire screen width.
  final double? widthFactor;

  /// Whether users can drag the drawer edge to resize it at runtime.
  ///
  /// Enabled by default so the drawer can be widened while it is open.
  final bool resizable;

  /// Minimum width allowed when [resizable] is true.
  final double minWidth;

  /// Maximum width allowed when [resizable] is true.
  ///
  /// Defaults to the current screen width.
  final double? maxWidth;

  /// Called whenever the user drags the drawer to a new width.
  final ValueChanged<double>? onWidthChanged;

  /// Called when the close button in the drawer header is pressed.
  final VoidCallback? onClose;

  @override
  State<DebuggingDrawer> createState() => _DebuggingDrawerState();
}

class _DebuggingDrawerState extends State<DebuggingDrawer> {
  late final List<DebugPanelItem> _panels;
  double? _resizedWidth;

  @override
  void initState() {
    super.initState();
    _panels = List.of(widget.panels);
  }

  @override
  void didUpdateWidget(covariant DebuggingDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.width != widget.width ||
        oldWidget.widthFactor != widget.widthFactor ||
        oldWidget.resizable != widget.resizable ||
        oldWidget.minWidth != widget.minWidth ||
        oldWidget.maxWidth != widget.maxWidth) {
      _resizedWidth = null;
    }

    if (oldWidget.panels == widget.panels) return;

    final expandedByTitle = {
      for (final panel in _panels) panel.title: panel.expanded,
    };
    _panels
      ..clear()
      ..addAll(
        widget.panels.map(
          (panel) => DebugPanelItem(
            panel.title,
            panel.body,
            expanded: expandedByTitle[panel.title] ?? panel.expanded,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final widthFactor = widget.widthFactor;
    final configuredWidth = widget.width ??
        (widthFactor == null ? null : screenWidth * widthFactor);
    final maxResizableWidth = widget.maxWidth ?? screenWidth;
    final width = widget.resizable
        ? (_resizedWidth ?? configuredWidth ?? widget.minWidth)
            .clamp(widget.minWidth, maxResizableWidth)
            .toDouble()
        : configuredWidth;

    return Drawer(
      width: width,
      backgroundColor: colors.surface,
      child: Stack(
        children: [
          HeroControllerScope.none(
            child: Navigator(
              onGenerateRoute: (_) {
                return MaterialPageRoute<void>(
                  builder: (context) {
                    return SafeArea(
                      child: SingleChildScrollView(
                        child: ColoredBox(
                          color: colors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: 16,
                                  end: 4,
                                  top: 8,
                                  bottom: 8,
                                ),
                                child: Row(
                                  children: [
                                    if (widget.headerText != null)
                                      Expanded(
                                        child: Text(
                                          widget.headerText!,
                                          style: textTheme.titleMedium
                                              ?.copyWith(
                                                color: colors.onSurface,
                                              ),
                                        ),
                                      )
                                    else
                                      const Spacer(),
                                    IconButton(
                                      key: const Key(
                                        'debugging_drawer_close_button',
                                      ),
                                      tooltip: 'Close debug tools',
                                      icon: const Icon(Icons.close),
                                      onPressed: () {
                                        final scaffold = Scaffold.maybeOf(
                                          context,
                                        );
                                        if (scaffold?.isDrawerOpen ?? false) {
                                          scaffold!.closeDrawer();
                                          return;
                                        }
                                        widget.onClose?.call();
                                        if (widget.onClose == null) {
                                          Navigator.of(
                                            context,
                                            rootNavigator: true,
                                          ).maybePop();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              ExpansionPanelList(
                            expansionCallback: (int index, bool isExpanded) {
                              setState(() {
                                _panels[index].expanded = isExpanded;
                              });
                            },
                            children: _panels.map<ExpansionPanel>((
                              DebugPanelItem panel,
                            ) {
                              return ExpansionPanel(
                                headerBuilder:
                                    (BuildContext context, bool isExpanded) {
                                      return Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.only(
                                          left: 16,
                                        ),
                                        child: Text(
                                          panel.title,
                                          style: textTheme.titleSmall?.copyWith(
                                            color: colors.onSurface,
                                          ),
                                        ),
                                      );
                                    },
                                body: ColoredBox(
                                  color: colors.surface,
                                  child: Padding(
                                    padding: const EdgeInsets.only(
                                      left: 8,
                                      right: 8,
                                      bottom: 16,
                                    ),
                                    child: panel.body,
                                  ),
                                ),
                                backgroundColor: colors.surfaceContainerLow,
                                isExpanded: panel.expanded,
                                canTapOnHeader: true,
                              );
                            }).toList(),
                          ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.resizable)
            PositionedDirectional(
              top: 0,
              end: 0,
              bottom: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  key: const Key('debugging_drawer_resize_handle'),
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final currentWidth = width ?? widget.minWidth;
                      final nextWidth = (currentWidth + details.delta.dx)
                          .clamp(widget.minWidth, maxResizableWidth)
                          .toDouble();
                      _resizedWidth = nextWidth;
                      widget.onWidthChanged?.call(nextWidth);
                    });
                  },
                  child: const SizedBox(width: 24),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
