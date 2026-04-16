import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';

void main() {
  runApp(const ExampleApp());
}

enum AppMode { demo, staging, production }

extension on AppMode {
  String get label => switch (this) {
    AppMode.demo => 'Demo',
    AppMode.staging => 'Staging',
    AppMode.production => 'Production',
  };
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  AppMode _mode = AppMode.demo;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  final ValueNotifier<List<String>> _visitedRoutes = ValueNotifier<List<String>>(
    const ['/'],
  );

  @override
  void dispose() {
    _visitedRoutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeSeed = switch (_mode) {
      AppMode.demo => Colors.indigo,
      AppMode.staging => Colors.orange,
      AppMode.production => Colors.green,
    };

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'debugging_tools example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeSeed),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => HomeScreen(
          mode: _mode,
          onModeChanged: _handleModeChanged,
        ),
        '/catalog': (_) => CatalogScreen(mode: _mode),
        '/settings': (_) => SettingsScreen(
          mode: _mode,
          onModeChanged: _handleModeChanged,
        ),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/catalog/item') {
          final itemName = settings.arguments as String? ?? 'Unknown Item';
          return MaterialPageRoute<void>(
            builder: (_) => CatalogItemScreen(itemName: itemName, mode: _mode),
            settings: settings,
          );
        }
        return null;
      },
      navigatorObservers: [
        _RouteTracker(
          onVisited: (name) {
            _visitedRoutes.value = [..._visitedRoutes.value, name];
          },
        ),
      ],
      builder: (context, child) => DebuggingToolsWrapper(
        showSharedPreferencesPanel: true,
        showNavigationPanel: true,
        showLocalStoragePanel: true,
        navigatorKey: _navigatorKey,
        routes: {
          '/': (_) => HomeScreen(
            mode: _mode,
            onModeChanged: _handleModeChanged,
          ),
          '/catalog': (_) => CatalogScreen(mode: _mode),
          '/settings': (_) => SettingsScreen(
            mode: _mode,
            onModeChanged: _handleModeChanged,
          ),
        },
        localStorageBuilder: (ctx) => LocalStoragePreview(mode: _mode),
        extraPanels: [
          CustomConfigPanel.item(
            title: 'Runtime State',
            child: RuntimeStatePanel(mode: _mode, visitedRoutes: _visitedRoutes),
            expanded: true,
          ),
        ],
        drawerHeaderText: '🐛 debugging_tools demo',
        child: child,
      ),
    );
  }

  void _handleModeChanged(AppMode value) {
    setState(() => _mode = value);
  }
}

class _RouteTracker extends NavigatorObserver {
  _RouteTracker({required this.onVisited});

  final ValueChanged<String> onVisited;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name;
    if (name != null) {
      onVisited(name);
    }
    super.didPush(route, previousRoute);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final AppMode mode;
  final ValueChanged<AppMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debugging Tools Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Current Mode: ${mode.label}',
            key: const Key('current-mode-label'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'This app includes mode switching, route navigation, and custom debug state.',
          ),
          const SizedBox(height: 16),
          SegmentedButton<AppMode>(
            key: const Key('mode-segmented-button'),
            segments: AppMode.values
                .map(
                  (value) => ButtonSegment<AppMode>(
                    value: value,
                    label: Text(value.label),
                  ),
                )
                .toList(),
            selected: {mode},
            onSelectionChanged: (selection) {
              onModeChanged(selection.first);
            },
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            key: const Key('open-catalog-button'),
            onPressed: () => Navigator.of(context).pushNamed('/catalog'),
            child: const Text('Open Catalog'),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('open-settings-button'),
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.mode});

  final AppMode mode;

  static const _items = ['Widget Inspector', 'Network Logs', 'Crash Reporter'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog')),
      body: ListView.builder(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return ListTile(
            key: Key('catalog-item-$index'),
            title: Text(item),
            subtitle: Text('Available in ${mode.label} mode'),
            onTap: () => Navigator.of(context).pushNamed(
              '/catalog/item',
              arguments: item,
            ),
          );
        },
      ),
    );
  }
}

class CatalogItemScreen extends StatelessWidget {
  const CatalogItemScreen({
    super.key,
    required this.itemName,
    required this.mode,
  });

  final String itemName;
  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catalog Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(itemName, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('Running in ${mode.label} mode'),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('catalog-item-back-home-button'),
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  final AppMode mode;
  final ValueChanged<AppMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          for (final candidate in AppMode.values)
            RadioListTile<AppMode>(
              key: Key('mode-radio-${candidate.name}'),
              title: Text(candidate.label),
              value: candidate,
              groupValue: mode,
              onChanged: (value) {
                if (value != null) {
                  onModeChanged(value);
                }
              },
            ),
        ],
      ),
    );
  }
}

class LocalStoragePreview extends StatelessWidget {
  const LocalStoragePreview({super.key, required this.mode});

  final AppMode mode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Custom Storage Preview',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Persisted mode key: app_mode = ${mode.name}'),
      ],
    );
  }
}

class RuntimeStatePanel extends StatelessWidget {
  const RuntimeStatePanel({
    super.key,
    required this.mode,
    required this.visitedRoutes,
  });

  final AppMode mode;
  final ValueNotifier<List<String>> visitedRoutes;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<String>>(
      valueListenable: visitedRoutes,
      builder: (context, routes, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mode: ${mode.label}'),
            const SizedBox(height: 8),
            Text('Visited routes: ${routes.join(' → ')}'),
          ],
        );
      },
    );
  }
}
