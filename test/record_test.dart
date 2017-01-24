// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show Process, ProcessResult, SYSTEM_ENCODING;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:process/process.dart';
import 'package:process/record_replay.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  FileSystem fs = new LocalFileSystem();

  group('RecordingProcessManager', () {
    Directory tmp;
    RecordingProcessManager manager;

    setUp(() {
      tmp = fs.systemTempDirectory.createTempSync('process_tests_');
      manager = new RecordingProcessManager(new LocalProcessManager(), tmp);
    });

    tearDown(() {
      tmp.deleteSync(recursive: true);
    });

    test('start', () async {
      Process process = await manager.start(<String>['echo', 'foo']);
      int pid = process.pid;
      int exitCode = await process.exitCode;
      List<int> stdout = await consume(process.stdout);
      List<int> stderr = await consume(process.stderr);
      expect(exitCode, 0);
      expect(decode(stdout), <String>['foo']);
      expect(stderr, isEmpty);

      // Force the recording to be written to disk.
      await manager.flush(finishRunningProcesses: true);

      _Recording recording = new _Recording(tmp);
      expect(recording.manifest, hasLength(1));
      Map<String, dynamic> entry = recording.manifest.first;
      expect(entry['pid'], pid);
      expect(entry['command'], <String>['echo', 'foo']);
      expect(entry['mode'], 'ProcessStartMode.NORMAL');
      expect(entry['exitCode'], exitCode);
      expect(recording.stdoutForEntryAt(0), stdout);
      expect(recording.stderrForEntryAt(0), stderr);
    });

    test('run', () async {
      ProcessResult result = await manager.run(<String>['echo', 'bar']);
      int pid = result.pid;
      int exitCode = result.exitCode;
      String stdout = result.stdout;
      String stderr = result.stderr;
      expect(exitCode, 0);
      expect(stdout, 'bar\n');
      expect(stderr, isEmpty);

      // Force the recording to be written to disk.
      await manager.flush(finishRunningProcesses: true);

      _Recording recording = new _Recording(tmp);
      expect(recording.manifest, hasLength(1));
      Map<String, dynamic> entry = recording.manifest.first;
      expect(entry['pid'], pid);
      expect(entry['command'], <String>['echo', 'bar']);
      expect(entry['stdoutEncoding'], 'system');
      expect(entry['stderrEncoding'], 'system');
      expect(entry['exitCode'], exitCode);
      expect(recording.stdoutForEntryAt(0), stdout);
      expect(recording.stderrForEntryAt(0), stderr);
    });

    test('runSync', () async {
      ProcessResult result = manager.runSync(<String>['echo', 'baz']);
      int pid = result.pid;
      int exitCode = result.exitCode;
      String stdout = result.stdout;
      String stderr = result.stderr;
      expect(exitCode, 0);
      expect(stdout, 'baz\n');
      expect(stderr, isEmpty);

      // Force the recording to be written to disk.
      await manager.flush(finishRunningProcesses: true);

      _Recording recording = new _Recording(tmp);
      expect(recording.manifest, hasLength(1));
      Map<String, dynamic> entry = recording.manifest.first;
      expect(entry['pid'], pid);
      expect(entry['command'], <String>['echo', 'baz']);
      expect(entry['stdoutEncoding'], 'system');
      expect(entry['stderrEncoding'], 'system');
      expect(entry['exitCode'], exitCode);
      expect(recording.stdoutForEntryAt(0), stdout);
      expect(recording.stderrForEntryAt(0), stderr);
    });
  });
}

/// A testing utility class that encapsulates a recording.
class _Recording {
  final Directory dir;

  _Recording(this.dir);

  List<Map<String, dynamic>> get manifest {
    return JSON.decoder.convert(_getFileContent('MANIFEST.txt', UTF8));
  }

  dynamic stdoutForEntryAt(int index) =>
      _getStdioContent(manifest[index], 'stdout');

  dynamic stderrForEntryAt(int index) =>
      _getStdioContent(manifest[index], 'stderr');

  dynamic _getFileContent(String name, Encoding encoding) {
    File file = dir.fileSystem.file('${dir.path}/$name');
    return encoding == null
        ? file.readAsBytesSync()
        : file.readAsStringSync(encoding: encoding);
  }

  dynamic _getStdioContent(Map<String, dynamic> entry, String type) {
    String basename = entry['basename'];
    String encodingName = entry['${type}Encoding'];
    Encoding encoding;
    if (encodingName != null)
      encoding = encodingName == 'system'
          ? SYSTEM_ENCODING
          : Encoding.getByName(encodingName);
    return _getFileContent('$basename.$type', encoding);
  }
}
