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
- **File-system panel** (auto-browse app documents by default, or browse a custom app-provided directory)
- **Network request + logs panels** (call URLs, inspect requests, copy cURL)
- **SQLite browser panel** (auto-detect `.db`, `.sqlite`, and `.sqlite3` files, switch databases, and inspect `sqflite` tables without writing SQL)
- **Custom panels** for app-specific workflows (state machine controls, network diagnostics, feature flags, etc.)

## Quick start

```dart
MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    navigatorKey: navigatorKey,
    showNavigationPanel: true,
    showSharedPreferencesPanel: true,
    showLocalStoragePanel: true,
    // Files and SQLite are auto-discovered from the application documents
    // directory by default. Pass fileSystemController only when you need a
    // custom root directory.
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
2. Pass only the non-obvious integrations, such as routes or a network client.

By default, the wrapper tries to inspect the most common local storage setup:
- it creates a file browser rooted at `getApplicationDocumentsDirectory()`;
- it scans that directory for files ending in `.db`, `.sqlite`, or `.sqlite3`;
- when database-looking files exist, it shows the SQLite panel automatically;
- the SQLite panel includes Open/Close controls and a detected-database picker.

You only need to pass a `FileSystemDebugController` when your app stores debug
files outside the documents directory or when you want to restrict browsing to a
smaller sandbox.

## File-system and network panels

The generic file-system panel is automatic for the application documents
directory. Override the root only when needed:

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

For the common `sqflite` setup, no SQLite configuration is required. If the
application documents directory contains files ending in `.db`, `.sqlite`, or
`.sqlite3`, `DebuggingToolsWrapper` opens the first one in a debug-only
connection and shows the SQLite panel automatically:

```dart
MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    child: child,
  ),
)
```

The panel lists tables, shows column metadata, previews rows, and includes:
- **Open database** / **Close database** lifecycle controls,
- a **detected database picker** that shows readable file names first and the
  parent path second,
- a manual **Change DB file** action for paths outside the discovered list,
- a collapsible SQL console for advanced debugging.

If your app already exposes a specific `Database` object that you want the panel
to inspect, you can still pass it directly:

```dart
SQLiteBrowserPanel(database: database)
```

## Example app

The `example/` app demonstrates an end-to-end debugging playground:
- use the automatically discovered app documents file tree,
- long-press files and folders to create, edit, rename, or delete items,
- toggle a runtime workflow state machine,
- use the packaged network request panel to call arbitrary URLs and fetch public IP,
- inspect automatically detected SQLite databases from the debug drawer.

See: `example/lib/main.dart`.

## Notes

- This package is intended for development/debug builds.
- For production apps, gate access to debug controls according to your release policy.
