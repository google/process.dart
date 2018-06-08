// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show Platform, Process, ProcessResult, systemEncoding;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:path/path.dart' as p;
import 'package:process/process.dart';
import 'package:process/record_replay.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  FileSystem fs = new LocalFileSystem();
  // TODO(goderbauer): refactor when github.com/google/platform.dart/issues/1
  //     is available.
  String newline = Platform.isWindows ? '\r\n' : '\n';

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
      Process process =
          await manager.start(<String>['echo', 'foo'], runInShell: true);
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
      expect(entry['type'], 'run');
      Map<String, dynamic> body = entry['body'];
      expect(body['pid'], pid);
      expect(body['command'], <String>['echo', 'foo']);
      expect(body['mode'], 'normal');
      expect(body['exitCode'], exitCode);
      expect(recording.stdoutForEntryAt(0), stdout);
      expect(recording.stderrForEntryAt(0), stderr);
    });

    test('run', () async {
      ProcessResult result =
          await manager.run(<String>['echo', 'bar'], runInShell: true);
      int pid = result.pid;
      int exitCode = result.exitCode;
      String stdout = result.stdout;
      String stderr = result.stderr;
      expect(exitCode, 0);
      expect(stdout, 'bar$newline');
      expect(stderr, isEmpty);

      // Force the recording to be written to disk.
      await manager.flush(finishRunningProcesses: true);

      _Recording recording = new _Recording(tmp);
      expect(recording.manifest, hasLength(1));
      Map<String, dynamic> entry = recording.manifest.first;
      expect(entry['type'], 'run');
      Map<String, dynamic> body = entry['body'];
      expect(body['pid'], pid);
      expect(body['command'], <String>['echo', 'bar']);
      expect(body['stdoutEncoding'], 'system');
      expect(body['stderrEncoding'], 'system');
      expect(body['exitCode'], exitCode);
      expect(recording.stdoutForEntryAt(0), stdout);
      expect(recording.stderrForEntryAt(0), stderr);
    });

    test('runSync', () async {
      ProcessResult result =
          manager.runSync(<String>['echo', 'baz'], runInShell: true);
      int pid = result.pid;
      int exitCode = result.exitCode;
      String stdout = result.stdout;
      String stderr = result.stderr;
      expect(exitCode, 0);
      expect(stdout, 'baz$newline');
      expect(stderr, isEmpty);

      // Force the recording to be written to disk.
      await manager.flush(finishRunningProcesses: true);

      _Recording recording = new _Recording(tmp);
      expect(recording.manifest, hasLength(1));
      Map<String, dynamic> entry = recording.manifest.first;
      expect(entry['type'], 'run');
      Map<String, dynamic> body = entry['body'];
      expect(body['pid'], pid);
      expect(body['command'], <String>['echo', 'baz']);
      expect(body['stdoutEncoding'], 'system');
      expect(body['stderrEncoding'], 'system');
      expect(body['exitCode'], exitCode);
      expect(recording.stdoutForEntryAt(0), stdout);
      expect(recording.stderrForEntryAt(0), stderr);
    });

    test('canRun', () async {
      String executable = p.join(tmp.path, 'bla.exe');
      fs.file(executable).createSync();

      bool result = manager.canRun(executable);

      // Force the recording to be written to disk.
      await manager.flush(finishRunningProcesses: true);

      _Recording recording = new _Recording(tmp);
      expect(recording.manifest, hasLength(1));
      Map<String, dynamic> entry = recording.manifest.first;
      expect(entry['type'], 'can_run');
      Map<String, dynamic> body = entry['body'];
      expect(body['executable'], executable);
      expect(body['result'], result);
    });
  });
}

/// A testing utility class that encapsulates a recording.
class _Recording {
  final Directory dir;

  _Recording(this.dir);

  List<Map<String, dynamic>> get manifest {
    return json.decoder
        .convert(_getFileContent('MANIFEST.txt', utf8))
        .cast<Map<String, dynamic>>();
  }

  dynamic stdoutForEntryAt(int index) =>
      _getStdioContent(manifest[index]['body'], 'stdout');

  dynamic stderrForEntryAt(int index) =>
      _getStdioContent(manifest[index]['body'], 'stderr');

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
          ? systemEncoding
          : Encoding.getByName(encodingName);
    return _getFileContent('$basename.$type', encoding);
  }
}
