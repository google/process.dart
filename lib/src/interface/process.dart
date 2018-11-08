// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

/// A wrapper around an [io.Process] class that adds some convenience methods.
class Process implements io.Process {
  /// Constructs a [Process] object that delegates to the specified underlying
  /// object.
  const Process(this.delegate);

  final io.Process delegate;

  @override
  Future<int> get exitCode => delegate.exitCode;

  /// A [Future] that completes when the process has exited and its standard
  /// output and error streams have closed.
  ///
  /// This exists as an alternative to [exitCode], which does not guarantee
  /// that the stdio streams have closed (it is possible for the exit code to
  /// be available before stdout and stderr have closed).
  ///
  /// The future returned here will complete with the exit code of the process.
  Future<int> get done async {
    int result;
    await Future.wait<void>(<Future<void>>[
      delegate.stdout.length,
      delegate.stderr.length,
      delegate.exitCode.then((int value) { result = value; }),
    ]);
    assert(result != null);
    return result;
  }

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    return delegate.kill(signal);
  }

  @override
  int get pid => delegate.pid;

  @override
  Stream<List<int>> get stderr => delegate.stderr;

  @override
  io.IOSink get stdin => delegate.stdin;

  @override
  Stream<List<int>> get stdout => delegate.stdout;
}
