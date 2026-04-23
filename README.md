# flutter_debugging_tools

`flutter_debugging_tools` is a drop-in developer drawer for Flutter apps that helps teams inspect and mutate runtime state while debugging.

## Why this package exists

When debugging mobile apps, engineers often need to:
- inspect navigation state,
- quickly change persisted values,
- test app behavior against local file changes,
- poke runtime state machines,
- run quick network checks.

This package provides a consistent debug drawer so those tools can be surfaced in-app with minimal boilerplate.

## What you get

Out of the box, `DebuggingToolsWrapper` can expose:
- **Navigation panel** (route jump + route metadata)
- **Shared preferences panel** (inspect/update key-value entries)
- **Local storage slot** (inject your own storage/file inspector)
- **Custom panels** for app-specific workflows (state machine controls, network diagnostics, feature flags, etc.)

## Quick start

```dart
MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    navigatorKey: navigatorKey,
    showNavigationPanel: true,
    showSharedPreferencesPanel: true,
    showLocalStoragePanel: true,
    routes: {
      '/': (_) => const HomeScreen(),
      '/settings': (_) => const SettingsScreen(),
    },
    // Optional: inject your own file/storage inspector.
    localStorageBuilder: (context) => const MyStorageDebugWidget(),
    // Optional: add custom runtime panels.
    extraPanels: [
      CustomConfigPanel.item(
        title: 'Runtime State',
        child: const MyRuntimeStateDebugWidget(),
      ),
    ],
    child: child,
  ),
)
```

## Integration philosophy (low configuration)

Use the package in two steps:
1. Wrap your app with `DebuggingToolsWrapper`.
2. Pass only the panels you need.

You can start with navigation + shared preferences only, then progressively add:
- a local file panel,
- a network tester panel,
- a state machine panel.

This keeps the package lightweight for simple apps while still supporting advanced debugging use cases.

## Example app

The `example/` app demonstrates an end-to-end debugging playground:
- create/edit/delete real files in app documents storage,
- mutate file contents with slider-driven operations,
- toggle a runtime workflow state machine,
- call arbitrary URLs and fetch public IP,
- inspect and change all the above from the debug drawer.

See: `example/lib/main.dart`.

## Notes

- This package is intended for development/debug builds.
- For production apps, gate access to debug controls according to your release policy.
