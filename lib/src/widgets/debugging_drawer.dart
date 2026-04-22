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
    super.key,
  });

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
  Widget build(BuildContext context) {
    return Drawer(
      child: HeroControllerScope.none(
        child: Navigator(
          onGenerateRoute: (_) {
            return MaterialPageRoute<void>(
              builder: (context) {
                return SafeArea(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.headerText != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(
                              widget.headerText!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ExpansionPanelList(
                          expansionCallback: (int index, bool isExpanded) {
                            setState(() {
                              _panels[index].expanded = isExpanded;
                            });
                          },
                          children: _panels.map<ExpansionPanel>((DebugPanelItem panel) {
                            return ExpansionPanel(
                              headerBuilder: (BuildContext context, bool isExpanded) {
                                return Container(
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 16),
                                  child: Text(panel.title),
                                );
                              },
                              body: Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  right: 8,
                                  bottom: 16,
                                ),
                                child: panel.body,
                              ),
                              isExpanded: panel.expanded,
                              canTapOnHeader: true,
                            );
                          }).toList(),
                        ),
                      ],
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
