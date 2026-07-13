# flutter_debugging_tools

`flutter_debugging_tools` is a drop-in developer drawer for Flutter apps that helps teams inspect and mutate runtime state while debugging.

![Flutter debugging tools](https://raw.githubusercontent.com/ivofernandes/flutter_debugging_tools/main/doc/screenshot.png?raw=true)

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
- **Asset bundle panel** (search `AssetManifest.json`, inspect bundled asset keys, sizes, and text previews)
- **Network request + logs panels** (call URLs, inspect requests, copy cURL)
- **App logs panel** (record app actions, search timestamped lines, copy visible logs)
- **SQLite browser panel** (auto-detect `.db`, `.sqlite`, and `.sqlite3` files, switch databases, and inspect `sqflite` tables without writing SQL)
- **Custom panels** for app-specific workflows (state machine controls, network diagnostics, feature flags, etc.)

## Quick start

```dart
MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    // Defaults to !kReleaseMode. Set this from an authenticated app-level
    // dev-mode flag when you intentionally need diagnostics in production.
    enabled: !kReleaseMode || devModeEnabled,
    navigatorKey: navigatorKey,
    showNavigationPanel: true,
    showSharedPreferencesPanel: true,
    showLocalStoragePanel: true,
    showAssetBundlePanel: true,
    // Files and SQLite are auto-discovered from the application documents
    // directory by default. Pass fileSystemController only when you need a
    // custom root directory.
    // Optional: share one debug client between URL calls and request logs.
    networkClient: debugHttpClient,
    showNetworkRequestPanel: true,
    showNetworkLogsPanel: true,
    // Optional: surface timestamped app logs from your own code paths.
    appLogger: appLogger,
    showAppLogsPanel: true,
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


## Release builds and production dev mode

`DebuggingToolsWrapper.enabled` defaults to `!kReleaseMode`, so the drawer is
mounted in debug/profile builds and omitted from release builds by default. If
your app has an authenticated or otherwise protected dev-mode flag, pass it to
`enabled` to intentionally expose the tools in production:

```dart
DebuggingToolsWrapper(
  enabled: !kReleaseMode || devModeEnabled,
  child: child,
)
```


## Drawer width

The debug drawer uses Flutter's default drawer width unless you configure it.
For wide tables, logs, or storage browsers, provide a fixed width or a screen
fraction. By default, users can also drag the drawer edge to adjust the width
while the drawer is open; the chosen width is kept when the drawer is closed and
opened again. Set `drawerWidthFactor` to `1` to let the tools take the entire
screen width while still opening from the same debug button:

```dart
DebuggingToolsWrapper(
  drawerWidthFactor: 1, // full screen width
  child: child,
)

DebuggingToolsWrapper(
  drawerWidth: 560, // fixed logical pixels
  child: child,
)

DebuggingToolsWrapper(
  drawerMinWidth: 320, // edge dragging is enabled by default
  drawerMaxWidth: 720,
  child: child,
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

## Asset bundle panel

The asset bundle panel is enabled by default and reads Flutter's
`AssetManifest.json` from the app bundle. It lets you filter bundled asset
keys, select an asset, view its byte size, and preview UTF-8 text assets.
Binary assets are identified without trying to render their contents.

```dart
DebuggingToolsWrapper(
  showAssetBundlePanel: true,
  child: child,
)
```

Set `showAssetBundlePanel: false` if you do not want bundled asset metadata
visible in the debug drawer.

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


## App logs panel

Use `AppLogger` to record app-specific actions, state transitions, and caught
errors. Pass the same logger to `DebuggingToolsWrapper` so the debug drawer can
show live log counts, grep-like filtering, selectable log lines, copy actions,
level chips for quickly switching the visible minimum severity, and clearing
controls.

```dart
// AppLogger() is a singleton, so this can be called anywhere.
final appLogger = AppLogger();

MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    appLogger: appLogger,
    showAppLogsPanel: true,
    // Start the panel at INFO+ logs; developers can switch levels in the UI.
    appLogsInitialMinimumLevel: AppLogLevel.info,
    child: child,
  ),
);

void openNetworkScreen() {
  appLogger.info(
    'Open network screen',
    tags: const ['app', 'navigation'],
  );
  navigatorKey.currentState?.pushNamed('/network');
}

Future<void> saveSettings() async {
  try {
    appLogger.debug('Saving settings', tags: const ['settings']);
    await repository.saveSettings();
    appLogger.info('Settings saved', tags: const ['settings']);
  } catch (error, stackTrace) {
    appLogger.error('Failed to save settings', error, stackTrace);
  }
}
```

You can also use the top-level `appLogger` shortcut exported by the package:

```dart
appLogger.warning('Cache is almost full');
appLogger.trace('Prefetched home feed');
```

Log lines are formatted for copy/paste and command-line filtering, for example:

```text
[2026-07-04T12:34:56.000Z] INFO app.navigation Open network screen
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
