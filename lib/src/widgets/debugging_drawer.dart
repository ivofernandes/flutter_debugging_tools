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
  const DebuggingDrawer({required this.panels, this.headerText, super.key});

  /// The panels to display inside the drawer.
  final List<DebugPanelItem> panels;

  /// Optional text shown at the top of the drawer.
  final String? headerText;

  @override
  State<DebuggingDrawer> createState() => _DebuggingDrawerState();
}

class _DebuggingDrawerState extends State<DebuggingDrawer> {
  late final List<DebugPanelItem> _panels;

  @override
  void initState() {
    super.initState();
    _panels = List.of(widget.panels);
  }

  @override
  void didUpdateWidget(covariant DebuggingDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
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

    return Drawer(
      backgroundColor: colors.surface,
      child: HeroControllerScope.none(
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
                          if (widget.headerText != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Text(
                                widget.headerText!,
                                style: textTheme.titleMedium?.copyWith(
                                  color: colors.onSurface,
                                ),
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
    );
  }
}
