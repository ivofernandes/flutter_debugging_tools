import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A viewport size that can be selected from [ScreenSizeSimulator].
@immutable
class DebugViewport {
  const DebugViewport(this.name, this.size);

  final String name;
  final Size size;
}

/// Controls the simulator exposed by [DebuggingToolsWrapper].
class ScreenSizeSimulatorController extends ChangeNotifier {
  bool _enabled = false;
  Size? _viewport;

  bool get enabled => _enabled;
  Size? get viewport => _viewport;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  void setViewport(Size? value) {
    if (_viewport == value) return;
    _viewport = value;
    notifyListeners();
  }
}

/// Constrains [child] to a selectable viewport and updates its [MediaQuery].
///
/// This is a debugging overlay rather than a responsive-layout primitive. In
/// release builds it returns [child] directly, so it is safe to leave in an
/// application's widget tree while controlling it with [enabled].
class ScreenSizeSimulator extends StatefulWidget {
  const ScreenSizeSimulator({
    required this.child,
    this.enabled = true,
    this.viewports = defaultViewports,
    this.controller,
    this.showControls = true,
    super.key,
  });

  final Widget child;
  final bool enabled;
  final List<DebugViewport> viewports;
  final ScreenSizeSimulatorController? controller;
  final bool showControls;

  static const defaultViewports = <DebugViewport>[
    DebugViewport('Phone', Size(375, 812)),
    DebugViewport('Phone landscape', Size(812, 375)),
    DebugViewport('Tablet', Size(768, 1024)),
    DebugViewport('Tablet landscape', Size(1024, 768)),
  ];

  @override
  State<ScreenSizeSimulator> createState() => _ScreenSizeSimulatorState();
}

class _ScreenSizeSimulatorState extends State<ScreenSizeSimulator> {
  Size? _viewport;

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_controllerChanged);
  }

  @override
  void didUpdateWidget(covariant ScreenSizeSimulator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_controllerChanged);
      widget.controller?.addListener(_controllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_controllerChanged);
    super.dispose();
  }

  void _controllerChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (kReleaseMode ||
        !widget.enabled ||
        (controller != null && !controller.enabled)) {
      return widget.child;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        final requestedSize =
            controller?.viewport ?? _viewport ?? availableSize;
        final viewport = Size(
          requestedSize.width.clamp(1, availableSize.width).toDouble(),
          requestedSize.height.clamp(1, availableSize.height).toDouble(),
        );

        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ClipRect(
                  child: SizedBox.fromSize(
                    size: viewport,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: viewport),
                      child: widget.child,
                    ),
                  ),
                ),
              ),
              if (widget.showControls)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _ViewportControls(
                    viewport: viewport,
                    availableSize: availableSize,
                    viewports: widget.viewports,
                    onChanged: (value) {
                      if (controller != null) {
                        controller.setViewport(value);
                      } else {
                        setState(() => _viewport = value);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Drawer controls for a [ScreenSizeSimulatorController].
class ScreenSizeSimulatorPanel extends StatelessWidget {
  const ScreenSizeSimulatorPanel({
    required this.controller,
    this.viewports = ScreenSizeSimulator.defaultViewports,
    super.key,
  });

  final ScreenSizeSimulatorController controller;
  final List<DebugViewport> viewports;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final available = MediaQuery.sizeOf(context);
        final viewport = controller.viewport ?? available;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulate screen size'),
              subtitle: Text(
                '${viewport.width.round()} × ${viewport.height.round()}',
              ),
              value: controller.enabled,
              onChanged: controller.setEnabled,
            ),
            DropdownButtonFormField<Size>(
              decoration: const InputDecoration(labelText: 'Viewport preset'),
              value: viewports.any((item) => item.size == controller.viewport)
                  ? controller.viewport
                  : null,
              items: [
                for (final preset in viewports)
                  DropdownMenuItem(
                    value: preset.size,
                    child: Text(preset.name),
                  ),
                if (!viewports.any((item) => item.size == available))
                  DropdownMenuItem(
                    value: available,
                    child: const Text('Full window'),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                controller.setViewport(value);
                controller.setEnabled(true);
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Rotate viewport',
                onPressed: () {
                  controller.setViewport(Size(viewport.height, viewport.width));
                  controller.setEnabled(true);
                },
                icon: const Icon(Icons.screen_rotation),
              ),
            ),
            _DimensionSlider(
              label: 'Width',
              value: viewport.width,
              max: available.width,
              onChanged: (value) {
                controller.setViewport(Size(value, viewport.height));
                controller.setEnabled(true);
              },
            ),
            _DimensionSlider(
              label: 'Height',
              value: viewport.height,
              max: available.height,
              onChanged: (value) {
                controller.setViewport(Size(viewport.width, value));
                controller.setEnabled(true);
              },
            ),
          ],
        );
      },
    );
  }
}

class _ViewportControls extends StatelessWidget {
  const _ViewportControls({
    required this.viewport,
    required this.availableSize,
    required this.viewports,
    required this.onChanged,
  });

  final Size viewport;
  final Size availableSize;
  final List<DebugViewport> viewports;
  final ValueChanged<Size> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: Theme.of(context).colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Viewport'),
                  const Spacer(),
                  Text(
                    '${viewport.width.round()} × ${viewport.height.round()}',
                  ),
                  IconButton(
                    tooltip: 'Rotate viewport',
                    onPressed: () => onChanged(
                      Size(viewport.height, viewport.width),
                    ),
                    icon: const Icon(Icons.screen_rotation),
                  ),
                  PopupMenuButton<Size>(
                    tooltip: 'Select viewport',
                    onSelected: onChanged,
                    itemBuilder: (context) => [
                      for (final preset in viewports)
                        PopupMenuItem(
                          value: preset.size,
                          child: Text(preset.name),
                        ),
                      PopupMenuItem(
                        value: availableSize,
                        child: const Text('Full window'),
                      ),
                    ],
                  ),
                ],
              ),
              _DimensionSlider(
                label: 'Width',
                value: viewport.width,
                max: availableSize.width,
                onChanged: (value) => onChanged(
                  Size(value, viewport.height),
                ),
              ),
              _DimensionSlider(
                label: 'Height',
                value: viewport.height,
                max: availableSize.height,
                onChanged: (value) => onChanged(
                  Size(viewport.width, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DimensionSlider extends StatelessWidget {
  const _DimensionSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveMax = max < 1 ? 1.0 : max;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label)),
        Expanded(
          child: Slider(
            min: 1,
            max: effectiveMax,
            value: value.clamp(1, effectiveMax).toDouble(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
