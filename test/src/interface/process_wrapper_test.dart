// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:process/process.dart';
import 'package:test/test.dart';

void main() {
  group('done', () {
    test('completes only when all done', () async {
      TestProcess delegate = new TestProcess();
      ProcessWrapper process = new ProcessWrapper(delegate);
      bool done = false;
      // ignore: unawaited_futures
      process.done.then((int result) {
        done = true;
      });
      expect(done, isFalse);
      delegate.exitCodeCompleter.complete(0);
      await Future<void>.value();
      expect(done, isFalse);
      await delegate.stdoutController.close();
      await Future<void>.value();
      expect(done, isFalse);
      await delegate.stderrController.close();
      await Future<void>.value();
      expect(done, isTrue);
      expect(await process.exitCode, 0);
    });
  });
}

class TestProcess implements io.Process {
  TestProcess([this.pid = 123])
      : exitCodeCompleter = new Completer<int>(),
        stdoutController = new StreamController<List<int>>(),
        stderrController = new StreamController<List<int>>();

  @override
  final int pid;
  final Completer<int> exitCodeCompleter;
  final StreamController<List<int>> stdoutController;
  final StreamController<List<int>> stderrController;

  @override
  Future<int> get exitCode => exitCodeCompleter.future;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    exitCodeCompleter.complete(-1);
    return true;
  }

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  io.IOSink get stdin => throw UnsupportedError('Not supported');

  @override
  Stream<List<int>> get stdout => stdoutController.stream;
}
