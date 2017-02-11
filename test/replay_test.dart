// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show Process, ProcessResult;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:process/process.dart';
import 'package:process/record_replay.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  FileSystem fs = new LocalFileSystem();

  group('ReplayProcessManager', () {
    ProcessManager manager;

    setUp(() async {
      Directory dir = fs.directory('test/data/replay');
      manager = await ReplayProcessManager.create(dir);
    });

    test('start', () async {
      Process process = await manager.start(<String>['sing', 'ppap']);
      int exitCode = await process.exitCode;
      List<int> stdout = await consume(process.stdout);
      List<int> stderr = await consume(process.stderr);
      expect(process.pid, 100);
      expect(exitCode, 0);
      expect(decode(stdout), <String>['I have a pen', 'I have a pineapple']);
      expect(decode(stderr), <String>['Uh, pineapple pen']);
    });

    test('run', () async {
      ProcessResult result =
          await manager.run(<String>['dance', 'gangnam-style']);
      expect(result.pid, 101);
      expect(result.exitCode, 2);
      expect(result.stdout, '');
      expect(result.stderr, 'No one can dance like Psy\n');
    });

    test('runSync', () {
      ProcessResult result =
          manager.runSync(<String>['dance', 'gangnam-style']);
      expect(result.pid, 101);
      expect(result.exitCode, 2);
      expect(result.stdout, '');
      expect(result.stderr, 'No one can dance like Psy\n');
    });

    test('canRun', () {
      bool result = manager.canRun('marathon');
      expect(result, true);
    });
  });
}
