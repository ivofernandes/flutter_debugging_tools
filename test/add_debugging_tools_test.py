import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).parents[1] / "scripts/dev/add_debugging_tools.py"
SPEC = importlib.util.spec_from_file_location("add_debugging_tools", SCRIPT)
TOOLS = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(TOOLS)


class AddDebuggingToolsTest(unittest.TestCase):
    def test_adds_hosted_dependency(self):
        with tempfile.TemporaryDirectory() as directory:
            pubspec = Path(directory) / "pubspec.yaml"
            pubspec.write_text("name: app\ndependencies:\n  flutter:\n    sdk: flutter\n")

            self.assertTrue(TOOLS.add_pubspec_dependency(pubspec))
            self.assertIn(
                "dependencies:\n  flutter_debugging_tools: ^0.0.1\n",
                pubspec.read_text(),
            )
            self.assertFalse(TOOLS.add_pubspec_dependency(pubspec))

    def test_finds_material_app_and_adds_builder(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "lib/src").mkdir(parents=True)
            app = root / "lib/src/app.dart"
            app.write_text(
                "import 'package:flutter/material.dart';\n"
                "Widget app() => MaterialApp(\n"
                "  title: 'builder: is not code',\n"
                "  home: const Placeholder(),\n"
                ");\n"
            )

            self.assertEqual(TOOLS.find_material_app(root, None), app)
            updated = TOOLS.add_import(TOOLS.wrap_material_app(app.read_text()))
            self.assertIn("package:flutter_debugging_tools/", updated)
            self.assertIn("builder: (context, child) => DebuggingToolsWrapper(", updated)
            self.assertIn("child: child,", updated)

    def test_composes_with_existing_multiline_builder(self):
        source = """Widget app() => MaterialApp(
  builder: (context, child) {
    return MediaQuery(data: const MediaQueryData(), child: child!);
  },
  home: const Placeholder(),
);
"""
        updated = TOOLS.wrap_material_app(source)

        self.assertIn("child: ((context, child) {", updated)
        self.assertIn("})(context, child),", updated)
        self.assertIn("home: const Placeholder()", updated)

    def test_is_idempotent_when_wrapper_exists(self):
        source = """MaterialApp(
  builder: (_, child) => DebuggingToolsWrapper(child: child),
)
"""
        self.assertEqual(TOOLS.wrap_material_app(source), source)

    def test_formats_insert_before_single_line_properties(self):
        updated = TOOLS.wrap_material_app(
            "MaterialApp(home: const Placeholder());\n"
        )

        self.assertIn("  ),\n  home: const Placeholder()", updated)

    def test_shell_launcher_configures_a_different_folder(self):
        with tempfile.TemporaryDirectory(prefix="flutter app ") as directory:
            root = Path(directory)
            (root / "lib").mkdir()
            (root / "pubspec.yaml").write_text(
                "name: app\ndependencies:\n  flutter:\n    sdk: flutter\n"
            )
            main = root / "lib/main.dart"
            main.write_text("Widget app() => MaterialApp(home: Home());\n")

            subprocess.run(
                [str(SCRIPT.with_suffix(".sh")), str(root)],
                check=True,
                cwd=Path(__file__).parents[1],
                capture_output=True,
                text=True,
            )

            self.assertIn(
                "flutter_debugging_tools: ^0.0.1",
                (root / "pubspec.yaml").read_text(),
            )
            self.assertIn("DebuggingToolsWrapper(", main.read_text())


if __name__ == "__main__":
    unittest.main()
