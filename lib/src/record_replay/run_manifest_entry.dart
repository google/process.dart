// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show ProcessStartMode, systemEncoding;

import 'manifest_entry.dart';

/// Gets a `ProcessStartMode` value by its string name.
ProcessStartMode _getProcessStartMode(String value) {
  if (value != null) {
    for (ProcessStartMode mode in ProcessStartMode.values) {
      if (mode.toString() == value) {
        return mode;
      }
    }
    throw new FormatException('Invalid value for mode: $value');
  }
  return null;
}

/// Gets an `Encoding` instance by the encoding name.
Encoding _getEncoding(String encoding) {
  if (encoding == 'system') {
    return systemEncoding;
  } else if (encoding != null) {
    return Encoding.getByName(encoding);
  }
  return null;
}

/// An entry in the process invocation manifest for running an executable.
class RunManifestEntry extends ManifestEntry {
  @override
  final String type = 'run';

  /// The process id.
  final int pid;

  /// The base file name for this entry. `stdout` and `stderr` files for this
  /// process will be serialized in the recording directory as
  /// `$basename.stdout` and `$basename.stderr`, respectively.
  final String basename;

  /// The command that was run. The first element is the executable, and the
  /// remaining elements are the arguments to the executable.
  final List<String> command;

  /// The process' working directory when it was spawned.
  final String workingDirectory;

  /// The environment variables that were passed to the process.
  final Map<String, String> environment;

  /// Whether the invoker's environment was made available to the process.
  final bool includeParentEnvironment;

  /// Whether the process was spawned through a system shell.
  final bool runInShell;

  /// The mode with which the process was spawned.
  final ProcessStartMode mode;

  /// The encoding used for the `stdout` of the process.
  final Encoding stdoutEncoding;

  /// The encoding used for the `stderr` of the process.
  final Encoding stderrEncoding;

  /// The exit code of the process.
  int exitCode;

  /// Creates a new manifest entry with the given properties.
  RunManifestEntry({
    this.pid,
    this.basename,
    this.command,
    this.workingDirectory,
    this.environment,
    this.includeParentEnvironment,
    this.runInShell,
    this.mode,
    this.stdoutEncoding,
    this.stderrEncoding,
    this.exitCode,
  });

  /// Creates a new manifest entry populated with the specified JSON [data].
  ///
  /// If any required fields are missing from the JSON data, this will throw
  /// a [FormatException].
  factory RunManifestEntry.fromJson(Map<String, dynamic> data) {
    checkRequiredField(data, 'pid');
    checkRequiredField(data, 'basename');
    checkRequiredField(data, 'command');
    RunManifestEntry entry = new RunManifestEntry(
      pid: data['pid'],
      basename: data['basename'],
      command: data['command']?.cast<String>(),
      workingDirectory: data['workingDirectory'],
      environment: data['environment'],
      includeParentEnvironment: data['includeParentEnvironment'],
      runInShell: data['runInShell'],
      mode: _getProcessStartMode(data['mode']),
      stdoutEncoding: _getEncoding(data['stdoutEncoding']),
      stderrEncoding: _getEncoding(data['stderrEncoding']),
      exitCode: data['exitCode'],
    );
    entry.daemon = data['daemon'];
    entry.notResponding = data['notResponding'];
    return entry;
  }

  /// The executable that was invoked.
  String get executable => command.first;

  /// The arguments that were passed to [executable].
  List<String> get arguments => command.skip(1).toList();

  /// Indicates that the process is a daemon.
  bool get daemon => _daemon;
  bool _daemon = false;
  set daemon(bool value) => _daemon = value ?? false;

  /// Indicates that the process did not respond to `SIGTERM`.
  bool get notResponding => _notResponding;
  bool _notResponding = false;
  set notResponding(bool value) => _notResponding = value ?? false;

  /// Returns a JSON-encodable representation of this manifest entry.
  @override
  Map<String, dynamic> toJson() => new JsonBuilder()
      .add('pid', pid)
      .add('basename', basename)
      .add('command', command)
      .add('workingDirectory', workingDirectory)
      .add('environment', environment)
      .add('includeParentEnvironment', includeParentEnvironment)
      .add('runInShell', runInShell)
      .add('mode', mode, () => mode.toString())
      .add('stdoutEncoding', stdoutEncoding, () => stdoutEncoding.name)
      .add('stderrEncoding', stderrEncoding, () => stderrEncoding.name)
      .add('daemon', daemon)
      .add('notResponding', notResponding)
      .add('exitCode', exitCode)
      .entry;
}
