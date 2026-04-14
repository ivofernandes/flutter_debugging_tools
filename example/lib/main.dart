import 'package:flutter/material.dart';
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'debugging_tools example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      builder: (context, child) => DebuggingToolsWrapper(
        // Show all built-in panels
        showSharedPreferencesPanel: true,
        showNavigationPanel: true,
        showLocalStoragePanel: true,
        // Provide a named route so the Navigation panel shows buttons
        routes: {
          '/counter': (ctx) => const _CounterScreen(),
        },
        // Inject a custom local storage widget
        localStorageBuilder: (ctx) => const _CustomStorageWidget(),
        // Add a completely custom panel
        extraPanels: [
          CustomConfigPanel.item(
            title: 'Feature Flags',
            child: const _FeatureFlagsWidget(),
            expanded: true,
          ),
        ],
        drawerHeaderText: '🐛 debugging_tools demo',
        child: child,
      ),
      home: const _HomeScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// Sample screens / widgets
// ---------------------------------------------------------------------------

class _HomeScreen extends StatelessWidget {
  const _HomeScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Drag the 🐛 button to open the debug drawer.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(builder: (_) => const _CounterScreen()),
              ),
              child: const Text('Go to Counter'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterScreen extends StatefulWidget {
  const _CounterScreen();

  @override
  State<_CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<_CounterScreen> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text(
          'Count: $_count',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _CustomStorageWidget extends StatelessWidget {
  const _CustomStorageWidget();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Custom Storage Inspector',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text('This widget was injected via localStorageBuilder.'),
      ],
    );
  }
}

class _FeatureFlagsWidget extends StatefulWidget {
  const _FeatureFlagsWidget();

  @override
  State<_FeatureFlagsWidget> createState() => _FeatureFlagsWidgetState();
}

class _FeatureFlagsWidgetState extends State<_FeatureFlagsWidget> {
  bool _darkMode = false;
  bool _betaFeature = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Dark Mode'),
          value: _darkMode,
          onChanged: (v) => setState(() => _darkMode = v),
        ),
        SwitchListTile(
          title: const Text('Beta Feature'),
          value: _betaFeature,
          onChanged: (v) => setState(() => _betaFeature = v),
        ),
      ],
    );
  }
}
