# Flutter Debugging Tools

`flutter_debugging_tools` adds an in-app developer drawer to a Flutter
application. It puts navigation, storage, files, SQLite, assets, HTTP requests,
and application logs in one place, so developers and testers can inspect a
running app without repeatedly attaching a debugger or building temporary
screens.

![Flutter debugging tools](https://raw.githubusercontent.com/ivofernandes/flutter_debugging_tools/main/doc/screenshot.png?raw=true)

> This package is designed for development and controlled diagnostic use. The
> drawer is disabled in release builds by default.

## Contents

- [Features](#features)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Using the drawer](#using-the-drawer)
- [Using application logs](#using-application-logs)
- [Using network logs](#using-network-logs)
- [Storage, files, and SQLite](#storage-files-and-sqlite)
- [Navigation and custom panels](#navigation-and-custom-panels)
- [Configuration reference](#configuration-reference)
- [Release builds and sensitive data](#release-builds-and-sensitive-data)
- [Device and simulator helpers](#device-and-simulator-helpers)

## Features

| Panel | What it provides | Example uses |
| --- | --- | --- |
| **Navigation** | A live route stack, a named-route tree, and buttons that jump directly to registered routes. | Reproduce deep-screen bugs, verify route order, or skip onboarding during testing. |
| **Shared preferences** | Inspect, add, update, and remove persisted key/value entries. | Test first-run flows, feature preferences, and corrupted or missing values. |
| **Local storage** | A slot for an app-provided storage widget. | Expose Hive boxes, secure-storage diagnostics, caches, or repository state. |
| **File system** | Browse the application documents directory, or a custom root directory. | Inspect downloads and generated files or validate offline data. |
| **Asset bundle** | Search asset keys and inspect byte sizes and UTF-8 text previews. | Confirm an asset was bundled and inspect JSON/configuration assets. |
| **SQLite browser** | Discover common database files, inspect tables, columns, and rows, switch databases, and use an optional SQL console. | Verify migrations, investigate cached records, or compare database files. |
| **Network request** | Call a URL from inside the app and inspect the status and a response preview. | Check device connectivity, DNS, authentication environments, or backend availability. |
| **Network logs** | Display requests made through `DebugHttpClient`, including status/failure summaries and copyable cURL commands. | Reproduce a request outside the app or share a failing endpoint with a teammate. |
| **App logs** | Capture structured, timestamped in-memory logs with severity levels, tags, errors, and stack traces. Search, filter, copy, or clear them in the drawer. | Follow user actions and state transitions, correlate failures, and collect a focused bug report. |
| **Custom panels** | Add any app-specific widget to the drawer. | Control feature flags, simulate state machines, or expose domain-specific diagnostics. |

The drawer can also be resized for wide tables and logs, and its floating bug
button can be dragged out of the way.

## Installation

Add the package to `pubspec.yaml`:

```yaml
dependencies:
  flutter_debugging_tools: ^0.0.1
```

Then import it:

```dart
import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
```

The repository also includes a one-command installer. Give the shell launcher
the folder of any Flutter app (relative paths, absolute paths, and paths with
spaces are supported):

```shell
path/to/flutter_debugging_tools/scripts/dev/add_debugging_tools.sh \
  path/to/your_flutter_app
```

The launcher updates the dependency, finds the Dart file containing
`MaterialApp`, adds the import, and installs the wrapper without discarding an
existing `builder`. With no folder argument it updates the current folder. If
the app has multiple `MaterialApp` files, select one with
`--dart lib/path/to/app.dart`:

```shell
path/to/add_debugging_tools.sh ../another_app --dart lib/app.dart
```

You can invoke `add_debugging_tools.py` directly with the same positional
folder argument. The command is safe to run again after configuration.

## Quick start

Use `DebuggingToolsWrapper` in `MaterialApp.builder`. The wrapper keeps the app
content as its child and overlays the draggable bug button that opens the
drawer.

```dart
final navigatorKey = GlobalKey<NavigatorState>();
final navigationHistoryObserver = NavigationHistoryObserver();
final debugHttpClient = DebugHttpClient();

MaterialApp(
  navigatorKey: navigatorKey,
  navigatorObservers: [navigationHistoryObserver],
  builder: (context, child) => DebuggingToolsWrapper(
    child: child,
    navigatorKey: navigatorKey,
    historyObserver: navigationHistoryObserver,
    routes: {
      '/': (_) => const HomeScreen(),
      '/settings': (_) => const SettingsScreen(),
    },
    networkClient: debugHttpClient,
    showNetworkRequestPanel: true,
    showNetworkLogsPanel: true,
    showAppLogsPanel: true,
  ),
)
```

Most local inspection features require no further configuration. The file
browser uses `getApplicationDocumentsDirectory()`, the SQLite browser searches
that directory for `.db`, `.sqlite`, and `.sqlite3` files, and the asset browser
reads Flutter's asset manifest.

## Using the drawer

1. Run the app in debug or profile mode.
2. Tap the floating bug button. Drag the button first if it covers part of the
   interface.
3. Select a panel in the drawer.
4. Inspect or change data, then reproduce the behavior without restarting the
   app.

A useful debugging workflow is to inspect the navigation stack, change a
preference or database value, reproduce the problem, filter the app logs by a
feature tag, and copy the relevant entries into a bug report. Network failures
can be copied separately as cURL commands for reproduction from a terminal.

## Using application logs

`AppLogger` is for events produced by your application: user actions, lifecycle
events, state transitions, business decisions, and caught failures. It is
separate from network logging, which only sees calls made with
`DebugHttpClient`.

### Enable the panel

`AppLogger()` returns the shared singleton. Pass that logger to the wrapper and
write to the same instance from anywhere in the app:

```dart
final logger = AppLogger();

MaterialApp(
  builder: (context, child) => DebuggingToolsWrapper(
    child: child,
    appLogger: logger,
    showAppLogsPanel: true,
    appLogsInitialMinimumLevel: AppLogLevel.info,
  ),
);
```

If `appLogger` is omitted, the enabled panel uses the shared singleton anyway.
The exported top-level `appLogger` variable is a convenient handle to that same
logger:

```dart
appLogger.trace('Polling sensor');
appLogger.debug('Saving settings', tags: const ['settings']);
appLogger.info('Opened network screen', tags: const ['navigation', 'network']);
appLogger.warning('Cache is almost full', tags: const ['cache']);

try {
  await repository.saveSettings();
} catch (error, stackTrace) {
  appLogger.error('Could not save settings', error, stackTrace);
}
```

Use the levels consistently:

- **TRACE** for very frequent, fine-grained execution details.
- **DEBUG** for values and decisions useful while developing a feature.
- **INFO** for meaningful, successful user or application events.
- **WARNING** for recoverable or unexpected conditions.
- **ERROR** for failed operations; include the error and stack trace when they
  are available.

Tags make logs easier to search. Prefer a small, stable vocabulary such as
`auth`, `sync`, `navigation`, or `settings` rather than putting all context in
the message. The panel searches the full copied text, so a search matches the
timestamp, level, tags, message, error, or stack trace. Severity chips apply a
minimum level independently of the text search.

### Read and share logs

Each entry is formatted as a grep-friendly line:

```text
[2026-07-04T12:34:56.000Z] INFO navigation.network Opened network screen
```

In the **App logs** panel you can:

- select a minimum level (for example, `WARNING` shows warnings and errors);
- search by level, tag, message, error, or stack-trace text;
- copy one complete entry, including its stack trace;
- copy only the entries currently visible after filtering; or
- clear the in-memory history before reproducing a bug.

The shared logger keeps the newest 500 entries by default and also emits them
through `dart:developer`; in debug mode it prints copyable text to the console.
For an isolated buffer or a different limit, create a detached logger:

```dart
final importLogger = AppLogger.detached(maxEntries: 1000);
```

Clearing the panel only clears the in-memory `AppLogger` entries. Logs are not
persisted or uploaded by this package.

## Using network logs

Only requests sent through a `DebugHttpClient` are captured. Share one client
between application services and the wrapper:

```dart
final debugHttpClient = DebugHttpClient(maxEntries: 100);

final response = await debugHttpClient.get(
  Uri.parse('https://api.example.com/health'),
);

DebuggingToolsWrapper(
  child: child,
  networkClient: debugHttpClient,
  showNetworkRequestPanel: true,
  showNetworkLogsPanel: true,
)
```

The **Network request** panel is a manual URL tester. The **Network logs** panel
shows recent calls from both that tester and application code using the shared
client. Each log includes the method, URL, status or failure, and the first part
of the response. Use **Copy cURL** to reproduce the method and URL in a terminal,
or **Clear** to begin a clean capture.

The generated cURL command currently contains the HTTP method and URL only; it
does not include request headers or a request body. The client stores the newest
50 requests by default (or `maxEntries` if configured) and response previews are
limited to 400 characters. Close the client when its owning service is disposed.

## Storage, files, and SQLite

### Automatic discovery

With the default configuration, the wrapper:

1. creates a file browser rooted at `getApplicationDocumentsDirectory()`;
2. recursively looks for `.db`, `.sqlite`, and `.sqlite3` files;
3. opens the first detected database using a debug-only connection; and
4. displays a database picker when more than one database is found.

The SQLite panel lists tables, column metadata, and rows. It also provides
open/close controls, a manual **Change DB file** action, and a collapsible SQL
console for advanced inspection.

### Use a custom file root

Provide a controller when files live elsewhere or when the drawer should see
only a smaller sandbox:

```dart
final controller = FileSystemDebugController(
  rootDirectory: Directory('/path/to/debug_files'),
);
await controller.initialize();

DebuggingToolsWrapper(
  child: child,
  fileSystemController: controller,
)
```

You can also provide a specific open `sqflite` database:

```dart
DebuggingToolsWrapper(
  child: child,
  sqliteDatabase: database,
)
```

The local-storage panel is intentionally app-defined because storage libraries
have different APIs:

```dart
DebuggingToolsWrapper(
  child: child,
  localStorageBuilder: (context) => const MyHiveInspector(),
)
```

## Navigation and custom panels

For complete navigation diagnostics, use the same observer and navigator key in
both `MaterialApp` and `DebuggingToolsWrapper`, as shown in the quick start.
Pass only routes that should be directly reachable from the tool.

Add app-specific workflows with `extraPanels`:

```dart
DebuggingToolsWrapper(
  child: child,
  extraPanels: [
    CustomConfigPanel.item(
      title: 'Runtime state',
      child: const RuntimeStateDebugWidget(),
    ),
  ],
)
```

Custom panels are useful for feature flags, fake sensor values, state-machine
controls, cache invalidation, and other diagnostics that a generic package
cannot infer.

## Configuration reference

Built-in shared preferences, navigation, local storage, file-system, asset, and
SQLite panels are enabled by default. Network and app-log panels are opt-in.

| Option | Default | Purpose |
| --- | --- | --- |
| `enabled` | `!kReleaseMode` | Mount or completely omit the debugging overlay. |
| `showSharedPreferencesPanel` | `true` | Inspect and edit shared preferences. |
| `showNavigationPanel` | `true` | Show named routes and optional live history. |
| `showLocalStoragePanel` | `true` | Show the app-provided local-storage widget. |
| `showFileSystemPanel` | `true` | Browse automatic or configured files. |
| `showAssetBundlePanel` | `true` | Search bundled assets and preview text assets. |
| `showSQLiteBrowserPanel` | `true` | Inspect an explicit or automatically discovered database. |
| `showNetworkRequestPanel` | `false` | Show the manual URL caller. |
| `showNetworkLogsPanel` | `false` | Show requests recorded by `networkClient`. |
| `showAppLogsPanel` | `false` | Show entries recorded by `appLogger`. |
| `drawerHeaderText` | package default | Customize the drawer heading. |
| `drawerResizable` | `true` | Allow the drawer edge to be dragged. |

For wide tables or logs, configure the drawer dimensions:

```dart
DebuggingToolsWrapper(
  child: child,
  drawerWidthFactor: 1, // full screen
  drawerMinWidth: 320,
  drawerMaxWidth: 720,
)
```

Use `drawerWidth: 560` instead for a fixed width. The user's resized width is
kept while the wrapper remains mounted.

## Release builds and sensitive data

`enabled` defaults to `!kReleaseMode`, so the overlay is omitted from release
builds. If production diagnostics are required, gate them behind an
authenticated or otherwise protected application-level dev mode:

```dart
DebuggingToolsWrapper(
  enabled: !kReleaseMode || authorizedDevMode,
  child: child,
)
```

The tools may reveal preferences, local files, database contents, URLs,
response previews, log messages, errors, and stack traces. Do not log passwords,
access tokens, personal data, or other secrets. Restrict custom file roots and
panels to the minimum data needed, and define who may enable, view, copy, and
share diagnostics before exposing the drawer outside development builds.

## Device and simulator helpers

`DeviceUtils` provides `isMobile`, `isDesktop`,
`isPhysicalMobileDevice`, `platformName`, `isEmulator`, and the `isSimulator`
alias. 

```dart
if(!DeviceUtils.isSimulator){
  // Simulate the reading of data that a simulator can not provide
}
```

## Example app

The `example/` application demonstrates the drawer, automatic file and SQLite
discovery, file editing, runtime state controls, and network requests. See
`example/lib/main.dart` for a complete integration.
