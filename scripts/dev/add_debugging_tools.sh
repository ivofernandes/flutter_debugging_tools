#!/bin/bash
# add_debugging_tools.sh
#
# Adds the debugging_tools package dependency to the nearest pubspec.yaml
# and prints a code snippet showing how to wire it into MaterialApp.
#
# Usage:
#   ./scripts/dev/add_debugging_tools.sh [path/to/project]
#
# If no argument is provided, the script uses the current directory.
# -------------------------------------------------------------------------

set -euo pipefail

# Resolve project root
if [ -n "${1:-}" ]; then
  PROJECT_DIR="$1"
else
  PROJECT_DIR="$(pwd)"
fi

PUBSPEC="$PROJECT_DIR/pubspec.yaml"

if [ ! -f "$PUBSPEC" ]; then
  echo "❌  No pubspec.yaml found in: $PROJECT_DIR"
  echo "    Run this script from the Flutter project root, or pass the path as an argument."
  exit 1
fi

echo "📄  Found pubspec.yaml at: $PUBSPEC"

# --------------------------------------------------------------------------
# 1. Check if the dependency already exists
# --------------------------------------------------------------------------
if grep -q "debugging_tools:" "$PUBSPEC"; then
  echo "✅  debugging_tools is already listed in pubspec.yaml – nothing to add."
else
  # Insert the dependency after the 'dependencies:' block header.
  # Works on both GNU sed (Linux) and BSD sed (macOS) via a temp file.
  TMP=$(mktemp)
  awk '
    /^dependencies:/ { print; print "  debugging_tools:"; print "    path: packages/debugging_tools"; next }
    { print }
  ' "$PUBSPEC" > "$TMP" && mv "$TMP" "$PUBSPEC"
  echo "✅  Added debugging_tools dependency to pubspec.yaml."
  echo "    Run 'flutter pub get' to install it."
fi

# --------------------------------------------------------------------------
# 2. Print integration snippet
# --------------------------------------------------------------------------
cat <<'SNIPPET'

────────────────────────────────────────────────────────────────────────────
  Integration snippet  –  paste this into your MaterialApp file
────────────────────────────────────────────────────────────────────────────

1. Add the import at the top of the file:

    import 'package:debugging_tools/debugging_tools.dart';

2. Wrap your MaterialApp builder (or add one) like this:

    MaterialApp(
      // ... your existing config ...
      builder: (context, child) => DebuggingToolsWrapper(
        // Toggle built-in panels:
        showSharedPreferencesPanel: true,
        showNavigationPanel: true,
        showLocalStoragePanel: true,

        // (Optional) named routes to show as navigation buttons:
        routes: {
          '/home': (ctx) => const HomeScreen(),
        },

        // (Optional) inject a custom storage inspector widget:
        localStorageBuilder: (ctx) => MyStorageWidget(),

        // (Optional) add your own panels:
        extraPanels: [
          CustomConfigPanel.item(
            title: 'Feature Flags',
            child: MyFeatureFlagsWidget(),
          ),
        ],

        child: child,
      ),
    )

   Or, if you manage the Scaffold yourself, use the lower-level API:

    Scaffold(
      key: _scaffoldKey,
      drawer: DebuggingDrawer(
        panels: [
          DebugPanelItem('Shared Prefs', SharedPreferencesPanel()),
          DebugPanelItem('Navigation',   NavigationPanel(routes: myRoutes)),
          DebugPanelItem('Storage',      LocalStoragePanel()),
          CustomConfigPanel.item(title: 'My Panel', child: MyWidget()),
        ],
      ),
      body: Stack(
        children: [
          child,
          DebuggingSettingsButton(scaffoldKey: _scaffoldKey),
        ],
      ),
    )

────────────────────────────────────────────────────────────────────────────
SNIPPET
