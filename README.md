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
- **Local storage slot** (inject your own storage inspector)
- **File-system panel** (browse and edit files under an app-provided directory)
- **Network request + logs panels** (call URLs, inspect requests, copy cURL)
- **SQLite browser panel** (inspect `sqflite` tables, columns, and rows without writing SQL)
- **Custom panels** for app-specific workflows (state machine controls, network diagnostics, feature flags, etc.)

## Quick start

```dart
MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    navigatorKey: navigatorKey,
    showNavigationPanel: true,
    showSharedPreferencesPanel: true,
    showLocalStoragePanel: true,
    // Optional: provide a sandbox directory controller to enable the
    // packaged file browser panel in the drawer.
    fileSystemController: fileSystemController,
    // Optional: share one debug client between URL calls and request logs.
    networkClient: debugHttpClient,
    showNetworkRequestPanel: true,
    showNetworkLogsPanel: true,
    routes: {
      '/': (_) => const HomeScreen(),
      '/settings': (_) => const SettingsScreen(),
    },
    // Optional: inject your own app-specific storage inspector.
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
- the packaged file-system panel,
- the packaged network request/log panels,
- a state machine panel.

This keeps the package lightweight for simple apps while still supporting advanced debugging use cases.


## File-system and network panels

The generic file-system panel lives in the package now. The host app only
provides the root directory it is safe to mutate:

```dart
final docs = await getApplicationDocumentsDirectory();
final fileSystemController = FileSystemDebugController(
  rootDirectory: Directory('${docs.path}/debug_files'),
);
await fileSystemController.initialize();

DebuggingToolsWrapper(
  fileSystemController: fileSystemController,
  child: child,
)
```

For network diagnostics, share a `DebugHttpClient` between app code, the
packaged request tester, and the log panel:

```dart
final debugHttpClient = DebugHttpClient();

DebuggingToolsWrapper(
  networkClient: debugHttpClient,
  showNetworkRequestPanel: true,
  showNetworkLogsPanel: true,
  child: child,
)
```

## SQLite browser panel

Apps that use `sqflite` can add the packaged DB Browser-style panel to the debug drawer by passing the app's open database instance:

```dart
DebuggingToolsWrapper(
  // ...
  extraPanels: [
    CustomConfigPanel.item(
      title: 'SQLite',
      child: SQLiteBrowserPanel(database: database),
    ),
  ],
  child: child,
)
```

The panel lists tables, shows column metadata, and previews rows. A collapsible SQL console is still available for advanced debugging.

## Example app

The `example/` app demonstrates an end-to-end debugging playground:
- use the packaged Finder-like file tree for app documents storage,
- long-press files and folders to create, edit, rename, or delete items,
- toggle a runtime workflow state machine,
- use the packaged network request panel to call arbitrary URLs and fetch public IP,
- inspect and change all the above from the debug drawer.

See: `example/lib/main.dart`.

## Notes

- This package is intended for development/debug builds.
- For production apps, gate access to debug controls according to your release policy.
