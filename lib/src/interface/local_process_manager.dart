// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show
        Process,
        ProcessResult,
        ProcessSignal,
        ProcessStartMode,
        SYSTEM_ENCODING;

import 'process_manager.dart';

/// Local implementation of the `ProcessManager` interface.
///
/// This implementation delegates directly to the corresponding static methods
/// in `dart:io`.
class LocalProcessManager implements ProcessManager {
  @override
  Future<Process> start(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    ProcessStartMode mode: ProcessStartMode.NORMAL,
  }) {
    return Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }

  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: SYSTEM_ENCODING,
    Encoding stderrEncoding: SYSTEM_ENCODING,
  }) {
    return Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  ProcessResult runSync(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: SYSTEM_ENCODING,
    Encoding stderrEncoding: SYSTEM_ENCODING,
  }) {
    return Process.runSync(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.SIGTERM]) {
    return Process.killPid(pid, signal);
  }
}
