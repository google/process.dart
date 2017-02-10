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

import 'package:meta/meta.dart';

import 'common.dart';
import 'process_manager.dart';

/// Local implementation of the `ProcessManager` interface.
///
/// This implementation delegates directly to the corresponding static methods
/// in `dart:io`.
///
/// All methods that take a `command` will run `toString()` on the command
/// elements to derive the executable and arguments that should be passed to
/// the underlying `dart:io` methods. Thus, the degenerate case of
/// `List<String>` will trivially work as expected.
class LocalProcessManager implements ProcessManager {
  /// Creates a new `LocalProcessManager`.
  const LocalProcessManager();

  @override
  Future<Process> start(
    @checked List<Object> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    ProcessStartMode mode: ProcessStartMode.NORMAL,
  }) {
    return Process.start(
      _getExecutable(command, workingDirectory, runInShell),
      _getArguments(command),
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
  }

  @override
  Future<ProcessResult> run(
    @checked List<Object> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: SYSTEM_ENCODING,
    Encoding stderrEncoding: SYSTEM_ENCODING,
  }) {
    return Process.run(
      _getExecutable(command, workingDirectory, runInShell),
      _getArguments(command),
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
    @checked List<Object> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: SYSTEM_ENCODING,
    Encoding stderrEncoding: SYSTEM_ENCODING,
  }) {
    return Process.runSync(
      _getExecutable(command, workingDirectory, runInShell),
      _getArguments(command),
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
  }

  @override
  bool canRun(@checked Object executable, {String workingDirectory}) =>
      getExecutablePath(executable, workingDirectory) != null;

  @override
  bool killPid(int pid, [ProcessSignal signal = ProcessSignal.SIGTERM]) {
    return Process.killPid(pid, signal);
  }
}

String _getExecutable(
    List<dynamic> command, String workingDirectory, bool runInShell) {
  String commandName = command.first.toString();
  if (runInShell) {
    return commandName;
  }
  String exe = getExecutablePath(commandName, workingDirectory);
  if (exe == null) {
    throw new ArgumentError('Cannot find executable for $commandName.');
  }
  return exe;
}

List<String> _getArguments(List<dynamic> command) =>
    command.skip(1).map((dynamic element) => element.toString()).toList();
