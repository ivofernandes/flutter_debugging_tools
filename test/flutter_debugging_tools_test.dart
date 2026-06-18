import 'dart:io';

import 'package:flutter_debugging_tools/flutter_debugging_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'FileSystemDebugController creates and edits files below its root',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'debug_file_panel_test_',
      );
      final controller = FileSystemDebugController(rootDirectory: root);
      addTearDown(() async {
        controller.dispose();
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      await controller.initialize();
      await controller.createFolder('logs');
      await controller.createFile(
        'sample.txt',
        'hello',
        parentDirectory: 'logs',
      );

      expect(controller.directories, contains('logs'));
      expect(
        controller.files['logs${Platform.pathSeparator}sample.txt'],
        'hello',
      );

      await controller.editFile(
        originalPath: 'logs${Platform.pathSeparator}sample.txt',
        updatedName: 'renamed.txt',
        content: 'updated',
      );

      expect(
        controller.files['logs${Platform.pathSeparator}renamed.txt'],
        'updated',
      );
    },
  );

  test(
    'FileSystemDebugController discovers SQLite-looking database files',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'debug_file_panel_db_test_',
      );
      final controller = FileSystemDebugController(rootDirectory: root);
      addTearDown(() async {
        controller.dispose();
        if (await root.exists()) {
          await root.delete(recursive: true);
        }
      });

      await File(
        '${root.path}${Platform.pathSeparator}app.db',
      ).writeAsString('');
      await File(
        '${root.path}${Platform.pathSeparator}notes.txt',
      ).writeAsString('');
      await Directory('${root.path}${Platform.pathSeparator}nested').create();
      await File(
        '${root.path}${Platform.pathSeparator}nested${Platform.pathSeparator}cache.sqlite3',
      ).writeAsString('');

      await controller.initialize();

      expect(controller.sqliteDatabaseFilePaths, [
        'app.db',
        'nested${Platform.pathSeparator}cache.sqlite3',
      ]);
      expect(
        controller.absolutePath('app.db'),
        '${root.path}${Platform.pathSeparator}app.db',
      );
    },
  );
}
