#!/usr/bin/env python3
"""add_debugging_tools.py

Automates adding the debugging_tools package to a Flutter project:

1. Adds ``debugging_tools`` to the ``dependencies`` section of pubspec.yaml.
2. Adds the import statement to a target Dart file.
3. Wraps the ``builder:`` return value inside ``DebuggingToolsWrapper``
   in a ``MaterialApp`` call.

Usage
-----
    python3 scripts/dev/add_debugging_tools.py \\
        --pubspec path/to/pubspec.yaml \\
        --dart    lib/my_app.dart

Both arguments default to files in the current working directory:
    pubspec  → ./pubspec.yaml
    dart     → ./lib/main.dart
"""

import argparse
import re
import sys
from pathlib import Path

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------
PACKAGE_NAME = "debugging_tools"
PACKAGE_DEPENDENCY = "  debugging_tools:\n    path: packages/debugging_tools\n"
IMPORT_LINE = "import 'package:debugging_tools/debugging_tools.dart';\n"
WRAPPER_OPEN = "DebuggingToolsWrapper(\n        child: "
WRAPPER_CLOSE = ",\n      )"


# --------------------------------------------------------------------------
# pubspec.yaml helpers
# --------------------------------------------------------------------------

def add_pubspec_dependency(pubspec_path: Path) -> None:
    """Insert the debugging_tools dependency if not already present."""
    text = pubspec_path.read_text(encoding="utf-8")

    if PACKAGE_NAME + ":" in text:
        print(f"✅  pubspec.yaml: '{PACKAGE_NAME}' already listed – skipping.")
        return

    # Insert right after the 'dependencies:' line.
    updated = re.sub(
        r"^(dependencies:\s*\n)",
        r"\g<1>" + PACKAGE_DEPENDENCY,
        text,
        count=1,
        flags=re.MULTILINE,
    )

    if updated == text:
        print(
            "⚠️   Could not find a 'dependencies:' section in pubspec.yaml.\n"
            "    Please add the following manually:\n\n"
            "    dependencies:\n"
            + PACKAGE_DEPENDENCY
        )
        return

    pubspec_path.write_text(updated, encoding="utf-8")
    print(f"✅  pubspec.yaml: added '{PACKAGE_NAME}' dependency.")
    print("    Run 'flutter pub get' to install it.")


# --------------------------------------------------------------------------
# Dart file helpers
# --------------------------------------------------------------------------

def add_import(dart_text: str) -> str:
    """Add the debugging_tools import if not already present."""
    if IMPORT_LINE.strip() in dart_text:
        print("✅  Dart file: import already present – skipping.")
        return dart_text

    # Insert before the first existing import or at the top.
    match = re.search(r"^import ", dart_text, re.MULTILINE)
    if match:
        pos = match.start()
        dart_text = dart_text[:pos] + IMPORT_LINE + dart_text[pos:]
    else:
        dart_text = IMPORT_LINE + dart_text

    print("✅  Dart file: added import statement.")
    return dart_text


def wrap_builder_return(dart_text: str) -> str:
    """
    Attempt to wrap the value returned from a ``builder:`` callback
    inside DebuggingToolsWrapper.

    Matches patterns like:
        builder: (context, child) => SomeWidget(...)
        builder: (context, child) { return SomeWidget(...); }

    This is a best-effort transformation; complex multi-line builders
    are printed as a manual-step instruction instead.
    """
    # Arrow function pattern:  builder: (x, y) => <expr>,
    arrow_pattern = re.compile(
        r"(builder\s*:\s*\([^)]*\)\s*=>\s*)"  # group 1: 'builder: (x, y) => '
        r"(DebuggingToolsWrapper\b)",           # already wrapped?
        re.DOTALL,
    )
    if arrow_pattern.search(dart_text):
        print("✅  Dart file: MaterialApp builder already uses DebuggingToolsWrapper.")
        return dart_text

    # Simple single-expression arrow: builder: (ctx, child) => Foo(...)
    # We only handle the common single-widget case to stay safe.
    simple_arrow = re.compile(
        r"(builder\s*:\s*\([^)]*\)\s*=>\s*)"
        r"([A-Z]\w*\s*\()",   # starts with a Widget constructor, e.g.  Scaffold(
        re.DOTALL,
    )
    match = simple_arrow.search(dart_text)
    if match:
        insert_pos = match.start(2)
        dart_text = (
            dart_text[:insert_pos]
            + WRAPPER_OPEN
            + dart_text[insert_pos:]
        )
        # Close the wrapper after the widget – find the balanced paren end.
        search_from = insert_pos + len(WRAPPER_OPEN)
        close_pos = _find_balanced_paren_end(dart_text, search_from)
        if close_pos != -1:
            dart_text = dart_text[:close_pos] + WRAPPER_CLOSE + dart_text[close_pos:]
            print("✅  Dart file: wrapped MaterialApp builder in DebuggingToolsWrapper.")
        else:
            print(
                "⚠️   Could not auto-close DebuggingToolsWrapper.\n"
                "    Please complete the wrapping manually (see instructions below)."
            )
        return dart_text

    # Could not transform automatically.
    _print_manual_instructions()
    return dart_text


def _find_balanced_paren_end(text: str, start: int) -> int:
    """
    Starting from ``start`` (which should be just after an opening '('),
    return the index of the matching ')'.  Returns -1 if not found.

    depth tracks how many unmatched '(' have been seen so far.  When the
    first ')' is encountered at depth == 0 it is the balancing close paren.
    """
    depth = 0
    i = start
    while i < len(text):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            if depth == 0:
                return i + 1
            depth -= 1
        i += 1
    return -1


def _print_manual_instructions() -> None:
    print(
        "\n⚠️   Could not automatically wrap the MaterialApp builder.\n"
        "    Please apply the following change manually:\n\n"
        "    BEFORE:\n"
        "        builder: (context, child) => YourWidget(\n"
        "          ...\n"
        "        ),\n\n"
        "    AFTER:\n"
        "        builder: (context, child) => DebuggingToolsWrapper(\n"
        "          child: YourWidget(\n"
        "            ...\n"
        "          ),\n"
        "        ),\n"
    )


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Add debugging_tools to a Flutter project.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--pubspec",
        default="pubspec.yaml",
        help="Path to pubspec.yaml (default: ./pubspec.yaml)",
    )
    parser.add_argument(
        "--dart",
        default="lib/main.dart",
        help="Path to the Dart file that contains MaterialApp (default: lib/main.dart)",
    )
    args = parser.parse_args()

    pubspec_path = Path(args.pubspec)
    dart_path = Path(args.dart)

    # Validate
    if not pubspec_path.exists():
        print(f"❌  pubspec.yaml not found: {pubspec_path}")
        sys.exit(1)
    if not dart_path.exists():
        print(f"❌  Dart file not found: {dart_path}")
        sys.exit(1)

    print(f"\n📦  Project: {pubspec_path.parent.resolve()}\n")

    # 1. pubspec
    add_pubspec_dependency(pubspec_path)

    # 2. Dart file
    dart_text = dart_path.read_text(encoding="utf-8")
    dart_text = add_import(dart_text)
    dart_text = wrap_builder_return(dart_text)
    dart_path.write_text(dart_text, encoding="utf-8")

    print(
        "\n────────────────────────────────────────────────────────────────────\n"
        "  Next steps\n"
        "────────────────────────────────────────────────────────────────────\n"
        "  1. Run:  flutter pub get\n"
        "  2. Customise the DebuggingToolsWrapper in your MaterialApp builder:\n"
        "       • showSharedPreferencesPanel: true/false\n"
        "       • showNavigationPanel:        true/false\n"
        "       • showLocalStoragePanel:      true/false\n"
        "       • routes:                     { '/name': (ctx) => Screen() }\n"
        "       • localStorageBuilder:        (ctx) => MyStorageWidget()\n"
        "       • extraPanels:                [ CustomConfigPanel.item(...) ]\n"
        "  3. The 🐛 button appears at the top-left; drag it anywhere.\n"
        "────────────────────────────────────────────────────────────────────\n"
    )


if __name__ == "__main__":
    main()
