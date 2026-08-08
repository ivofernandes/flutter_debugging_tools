#!/usr/bin/env python3
"""Install flutter_debugging_tools into an existing Flutter application.

Pass a Flutter project folder as the first argument. By default the script uses
the current folder. It searches the project's ``lib`` folder for the Dart file
containing ``MaterialApp``; pass ``--dart`` when there is more than one.
"""

import argparse
import re
import sys
from pathlib import Path

PACKAGE_NAME = "flutter_debugging_tools"
PACKAGE_VERSION = "^0.0.1"
IMPORT_LINE = (
    "import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';\n"
)


def add_pubspec_dependency(pubspec_path: Path) -> bool:
    """Add the hosted package dependency, returning whether the file changed."""
    text = pubspec_path.read_text(encoding="utf-8")
    if re.search(rf"^\s{{2}}{PACKAGE_NAME}\s*:", text, re.MULTILINE):
        print(f"✅  pubspec.yaml: '{PACKAGE_NAME}' is already listed.")
        return False

    match = re.search(r"^dependencies\s*:\s*(?:#.*)?$", text, re.MULTILINE)
    if not match:
        raise ValueError("Could not find a 'dependencies:' section in pubspec.yaml")

    insertion = f"\n  {PACKAGE_NAME}: {PACKAGE_VERSION}"
    updated = text[: match.end()] + insertion + text[match.end() :]
    pubspec_path.write_text(updated, encoding="utf-8")
    print(f"✅  pubspec.yaml: added '{PACKAGE_NAME}: {PACKAGE_VERSION}'.")
    return True


def add_import(dart_text: str) -> str:
    """Add the public package import if it is not already present."""
    if IMPORT_LINE.strip() in dart_text:
        return dart_text
    match = re.search(r"^(?:import|export|part) ", dart_text, re.MULTILINE)
    position = match.start() if match else 0
    return dart_text[:position] + IMPORT_LINE + dart_text[position:]


def _code_mask(text: str) -> str:
    """Return text with comments and strings blanked, preserving positions."""
    chars = list(text)
    i = 0
    state = "code"
    quote = ""
    while i < len(chars):
        if state == "code" and text.startswith("//", i):
            state = "line"
        elif state == "code" and text.startswith("/*", i):
            state = "block"
            chars[i] = chars[i + 1] = " "
            i += 2
            continue
        elif state == "code" and chars[i] in "'\"":
            quote = chars[i]
            state = "string"
        elif state == "line" and chars[i] == "\n":
            state = "code"
        elif state == "block" and text.startswith("*/", i):
            chars[i] = chars[i + 1] = " "
            state = "code"
            i += 2
            continue
        elif state == "string" and chars[i] == quote and (
            i == 0 or chars[i - 1] != "\\"
        ):
            chars[i] = " "
            state = "code"
            i += 1
            continue

        if state != "code":
            chars[i] = "\n" if chars[i] == "\n" else " "
        i += 1
    return "".join(chars)


def _matching_paren(mask: str, opening: int) -> int:
    depth = 0
    for index in range(opening, len(mask)):
        if mask[index] == "(":
            depth += 1
        elif mask[index] == ")":
            depth -= 1
            if depth == 0:
                return index
    raise ValueError("MaterialApp has an unmatched opening parenthesis")


def _top_level_builder(mask: str, start: int, end: int) -> tuple[int, int] | None:
    """Find a top-level builder value and return its start/end offsets."""
    depths = {"(": 0, "[": 0, "{": 0}
    closes = {")": "(", "]": "[", "}": "{"}
    i = start
    while i < end:
        character = mask[i]
        if character in depths:
            depths[character] += 1
        elif character in closes:
            depths[closes[character]] -= 1
        elif all(value == 0 for value in depths.values()):
            match = re.match(r"builder\s*:", mask[i:])
            if match:
                value_start = i + match.end()
                while value_start < end and mask[value_start].isspace():
                    value_start += 1
                j = value_start
                nested = depths.copy()
                while j < end:
                    char = mask[j]
                    if char in nested:
                        nested[char] += 1
                    elif char in closes:
                        nested[closes[char]] -= 1
                    elif char == "," and all(v == 0 for v in nested.values()):
                        return value_start, j
                    j += 1
                return value_start, end
        i += 1
    return None


def wrap_material_app(dart_text: str) -> str:
    """Add or compose MaterialApp.builder with DebuggingToolsWrapper."""
    mask = _code_mask(dart_text)
    if re.search(r"\bDebuggingToolsWrapper\s*\(", mask):
        print("✅  Dart file: DebuggingToolsWrapper is already configured.")
        return dart_text

    material_apps = list(re.finditer(r"\bMaterialApp(?:\.router)?\s*\(", mask))
    if not material_apps:
        raise ValueError("Could not find a MaterialApp or MaterialApp.router call")
    if len(material_apps) > 1:
        raise ValueError("Found multiple MaterialApp calls; move one to another file or edit manually")

    opening = mask.find("(", material_apps[0].start())
    closing = _matching_paren(mask, opening)
    builder = _top_level_builder(mask, opening + 1, closing)
    line_start = dart_text.rfind("\n", 0, opening) + 1
    base_indent = re.match(r"\s*", dart_text[line_start:opening]).group()
    property_indent = base_indent + "  "

    if builder:
        value_start, value_end = builder
        old_builder = dart_text[value_start:value_end].rstrip()
        replacement = (
            "(context, child) => DebuggingToolsWrapper(\n"
            f"{property_indent}  child: ({old_builder})(context, child),\n"
            f"{property_indent})"
        )
        updated = dart_text[:value_start] + replacement + dart_text[value_end:]
        print("✅  Dart file: wrapped the existing MaterialApp builder.")
        return updated

    insertion = (
        f"\n{property_indent}builder: (context, child) => DebuggingToolsWrapper(\n"
        f"{property_indent}  child: child,\n"
        f"{property_indent}),"
    )
    if dart_text[opening + 1 : opening + 2] != "\n":
        insertion += f"\n{property_indent}"
    print("✅  Dart file: added DebuggingToolsWrapper to MaterialApp.builder.")
    return dart_text[: opening + 1] + insertion + dart_text[opening + 1 :]


def find_material_app(project_root: Path, explicit: str | None) -> Path:
    if explicit:
        path = Path(explicit)
        return path if path.is_absolute() else project_root / path

    candidates = []
    for path in sorted((project_root / "lib").rglob("*.dart")):
        if re.search(r"\bMaterialApp(?:\.router)?\s*\(", _code_mask(path.read_text())):
            candidates.append(path)
    if not candidates:
        raise ValueError("No MaterialApp was found under lib/")
    if len(candidates) > 1:
        listed = "\n    ".join(str(path) for path in candidates)
        raise ValueError(f"Multiple MaterialApp files found; select one with --dart:\n    {listed}")
    return candidates[0]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "project_path",
        nargs="?",
        help="Flutter project folder (default: current folder)",
    )
    parser.add_argument(
        "--project",
        dest="project_option",
        help="Flutter project folder (alternative to the positional argument)",
    )
    parser.add_argument(
        "--pubspec",
        help="pubspec path, relative to the project folder by default",
    )
    parser.add_argument("--dart", help="Dart file to edit (otherwise searches PROJECT/lib)")
    args = parser.parse_args()
    if args.project_path and args.project_option:
        parser.error("provide the project either positionally or with --project, not both")

    project = Path(args.project_option or args.project_path or ".").expanduser().resolve()
    if args.pubspec:
        supplied_pubspec = Path(args.pubspec).expanduser()
        pubspec = supplied_pubspec if supplied_pubspec.is_absolute() else project / supplied_pubspec
    else:
        pubspec = project / "pubspec.yaml"

    try:
        if not pubspec.is_file():
            raise ValueError(f"pubspec.yaml not found: {pubspec}")
        dart = find_material_app(project, args.dart)
        if not dart.is_file():
            raise ValueError(f"Dart file not found: {dart}")

        print(f"📦  Project: {project}")
        print(f"🎯  MaterialApp: {dart}")
        add_pubspec_dependency(pubspec)
        original = dart.read_text(encoding="utf-8")
        updated = add_import(wrap_material_app(original))
        if updated != original:
            dart.write_text(updated, encoding="utf-8")
        print("\nNext: run `flutter pub get` and format the changed Dart file.")
        print("Add custom drawer entries with DebuggingToolsWrapper.extraPanels.")
    except (OSError, ValueError) as error:
        print(f"❌  {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
