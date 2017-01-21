// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show ProcessStartMode, SYSTEM_ENCODING;

import 'manifest.dart';
import 'replay_process_manager.dart';

/// Throws a [FormatException] if [data] does not contain [key].
void _checkRequiredField(Map<String, dynamic> data, String key) {
  if (!data.containsKey(key))
    throw new FormatException('Required field missing: $key');
}

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
    return SYSTEM_ENCODING;
  } else if (encoding != null) {
    return Encoding.getByName(encoding);
  }
  return null;
}

/// An entry in the process invocation manifest.
///
/// Each entry in the [Manifest] represents a single recorded process
/// invocation.
class ManifestEntry {
  /// The process id.
  final int pid;

  /// The base file name for this entry. `stdout` and `stderr` files for this
  /// process will be serialized in the recording directory as
  /// `$basename.stdout` and `$basename.stderr`, respectively.
  final String basename;

  /// The name of the executable that spawned the process.
  final String executable;

  /// The list of arguments to [executable].
  final List<String> arguments;

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
  ManifestEntry({
    this.pid,
    this.basename,
    this.executable,
    this.arguments,
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
  factory ManifestEntry.fromJson(Map<String, dynamic> data) {
    _checkRequiredField(data, 'pid');
    _checkRequiredField(data, 'basename');
    _checkRequiredField(data, 'executable');
    _checkRequiredField(data, 'arguments');
    ManifestEntry entry = new ManifestEntry(
      pid: data['pid'],
      basename: data['basename'],
      executable: data['executable'],
      arguments: data['arguments'],
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

  /// Indicates that the process is a daemon.
  bool get daemon => _daemon;
  bool _daemon = false;
  set daemon(bool value) => _daemon = value ?? false;

  /// Indicates that the process did not respond to `SIGTERM`.
  bool get notResponding => _notResponding;
  bool _notResponding = false;
  set notResponding(bool value) => _notResponding = value ?? false;

  /// Whether this entry has been "invoked" by [ReplayProcessManager].
  bool get invoked => _invoked;
  bool _invoked = false;

  /// Marks this entry as having been "invoked" by [ReplayProcessManager].
  void setInvoked() {
    _invoked = true;
  }

  /// Returns a JSON-encodable representation of this manifest entry.
  Map<String, dynamic> toJson() => new _JsonBuilder()
      .add('pid', pid)
      .add('basename', basename)
      .add('executable', executable)
      .add('arguments', arguments)
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

/// A lightweight class that provides a means of building a manifest entry
/// JSON object.
class _JsonBuilder {
  final Map<String, dynamic> entry = <String, dynamic>{};

  /// Adds the specified key/value pair to the manifest entry iff the value
  /// is non-null. If [jsonValue] is specified, its value will be used instead
  /// of the raw value.
  _JsonBuilder add(String name, dynamic value, [dynamic jsonValue()]) {
    if (value != null) {
      entry[name] = jsonValue == null ? value : jsonValue();
    }
    return this;
  }
}
