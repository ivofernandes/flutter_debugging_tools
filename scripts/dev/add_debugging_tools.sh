#!/usr/bin/env bash
# Convenience launcher for add_debugging_tools.py.
#
# Examples:
#   ./scripts/dev/add_debugging_tools.sh ../another_flutter_app
#   ./scripts/dev/add_debugging_tools.sh "/path/with spaces/my app"
#   ./scripts/dev/add_debugging_tools.sh ../app --dart lib/app.dart

set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$SCRIPT_DIR/add_debugging_tools.py" "$@"
