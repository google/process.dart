// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io
    show
        IOSink,
        Process,
        ProcessException,
        ProcessResult,
        ProcessSignal,
        ProcessStartMode,
        SYSTEM_ENCODING;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import '../interface/process_manager.dart';
import 'constants.dart';
import 'manifest.dart';
import 'manifest_entry.dart';
import 'recording_process_manager.dart';

/// Mocks out all process invocations by replaying a previously-recorded series
/// of invocations.
///
/// Fopo, throwing an
/// exception if the requested invocations substantively differ in any way
/// from those in the recording.
///
/// Recordings are expected to be of the form produced by
/// [RecordingProcessManager]. Namely, this includes:
///
/// - a [_kManifestName](manifest file) encoded as UTF-8 JSON that lists all
///   invocations in order, along with the following metadata for each
///   invocation:
///   - `pid` (required): The process id integer.
///   - `basename` (required): A string specifying the base filename from which
///     the incovation's `stdout` and `stderr` files can be located.
///   - `executable` (required): A string specifying the path to the executable
///     command that kicked off the process.
///   - `arguments` (required): A list of strings that were passed as arguments
///     to the executable.
///   - `workingDirectory` (required): The current working directory from which
///     the process was spawned.
///   - `environment` (required): A map from string environment variable keys
///     to their corresponding string values.
///   - `mode` (optional): A string specifying the [ProcessStartMode].
///   - `stdoutEncoding` (optional): The name of the encoding scheme that was
///     used in the `stdout` file. If unspecified, then the file was written
///     as binary data.
///   - `stderrEncoding` (optional): The name of the encoding scheme that was
///     used in the `stderr` file. If unspecified, then the file was written
///     as binary data.
///   - `exitCode` (required): The exit code of the process, or null if the
///     process was not responding.
///   - `daemon` (optional): A boolean indicating that the process is to stay
///     resident during the entire lifetime of the master Flutter tools process.
/// - a `stdout` file for each process invocation. The location of this file
///   can be derived from the `basename` manifest property like so:
///   `'$basename.stdout'`.
/// - a `stderr` file for each process invocation. The location of this file
///   can be derived from the `basename` manifest property like so:
///   `'$basename.stderr'`.
class ReplayProcessManager implements ProcessManager {
  final Manifest _manifest;
  final Directory _dir;

  ReplayProcessManager._(this._manifest, this._dir);

  /// Creates a new `ReplayProcessManager` capable of replaying a recording that
  /// was serialized to the specified [location] by [RecordingProcessManager].
  ///
  /// If [location] does not exist, or if it does not represent a valid
  /// recording (as determined by [RecordingProcessManager]), an [ArgumentError]
  /// will be thrown.
  static Future<ReplayProcessManager> create(Directory location) async {
    if (!location.existsSync()) {
      throw new ArgumentError.value(location.path, 'location', "Doesn't exist");
    }

    FileSystem fs = location.fileSystem;
    File manifestFile = fs.file(path.join(location.path, kManifestName));
    if (!manifestFile.existsSync()) {
      throw new ArgumentError.value(
          location, 'location', 'Does not represent a valid recording.');
    }

    String content = await manifestFile.readAsString();
    try {
      // We don't validate the existence of all stdout and stderr files
      // referenced in the manifest.
      Manifest manifest = new Manifest.fromJson(content);
      return new ReplayProcessManager._(manifest, location);
    } on FormatException catch (e) {
      throw new ArgumentError('$kManifestName is not a valid JSON file: $e');
    }
  }

  @override
  Future<io.Process> start(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    io.ProcessStartMode mode: io.ProcessStartMode.NORMAL,
  }) async {
    ManifestEntry entry = _popEntry(executable, arguments, mode: mode);
    _ReplayResult result =
        await _ReplayResult.create(executable, arguments, _dir, entry);
    return result.asProcess(entry.daemon);
  }

  @override
  Future<io.ProcessResult> run(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: io.SYSTEM_ENCODING,
    Encoding stderrEncoding: io.SYSTEM_ENCODING,
  }) async {
    ManifestEntry entry = _popEntry(executable, arguments,
        stdoutEncoding: stdoutEncoding, stderrEncoding: stderrEncoding);
    return await _ReplayResult.create(executable, arguments, _dir, entry);
  }

  @override
  io.ProcessResult runSync(
    String executable,
    List<String> arguments, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: io.SYSTEM_ENCODING,
    Encoding stderrEncoding: io.SYSTEM_ENCODING,
  }) {
    ManifestEntry entry = _popEntry(executable, arguments,
        stdoutEncoding: stdoutEncoding, stderrEncoding: stderrEncoding);
    return _ReplayResult.createSync(executable, arguments, _dir, entry);
  }

  /// Finds and returns the next entry in the process manifest that matches
  /// the specified process arguments. Once found, it marks the manifest entry
  /// as having been invoked and thus not eligible for invocation again.
  ManifestEntry _popEntry(
    String executable,
    List<String> arguments, {
    io.ProcessStartMode mode,
    Encoding stdoutEncoding,
    Encoding stderrEncoding,
  }) {
    ManifestEntry entry = _manifest.findPendingEntry(
      executable: executable,
      arguments: arguments,
      mode: mode,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );

    if (entry == null)
      throw new io.ProcessException(
          executable, arguments, 'No matching invocation found');

    entry.setInvoked();
    return entry;
  }

  @override
  bool killPid(int pid, [io.ProcessSignal signal = io.ProcessSignal.SIGTERM]) {
    throw new UnsupportedError(
        "$runtimeType.killPid() has not been implemented because at the time "
        "of its writing, it wasn't needed. If you're hitting this error, you "
        "should implement it.");
  }
}

/// A [ProcessResult] implementation that derives its data from a recording
/// fragment.
class _ReplayResult implements io.ProcessResult {
  @override
  final int pid;

  @override
  final int exitCode;

  @override
  final dynamic stdout;

  @override
  final dynamic stderr;

  _ReplayResult._({this.pid, this.exitCode, this.stdout, this.stderr});

  static Future<_ReplayResult> create(
    String executable,
    List<String> arguments,
    Directory dir,
    ManifestEntry entry,
  ) async {
    FileSystem fs = dir.fileSystem;
    String basePath = path.join(dir.path, entry.basename);
    try {
      return new _ReplayResult._(
        pid: entry.pid,
        exitCode: entry.exitCode,
        stdout: await _getData(fs, '$basePath.stdout', entry.stdoutEncoding),
        stderr: await _getData(fs, '$basePath.stderr', entry.stderrEncoding),
      );
    } catch (e) {
      throw new io.ProcessException(executable, arguments, e.toString());
    }
  }

  static Future<dynamic> _getData(
      FileSystem fs, String path, Encoding encoding) async {
    File file = fs.file(path);
    return encoding == null
        ? await file.readAsBytes()
        : await file.readAsString(encoding: encoding);
  }

  static _ReplayResult createSync(
    String executable,
    List<String> arguments,
    Directory dir,
    ManifestEntry entry,
  ) {
    FileSystem fs = dir.fileSystem;
    String basePath = path.join(dir.path, entry.basename);
    try {
      return new _ReplayResult._(
        pid: entry.pid,
        exitCode: entry.exitCode,
        stdout: _getDataSync(fs, '$basePath.stdout', entry.stdoutEncoding),
        stderr: _getDataSync(fs, '$basePath.stderr', entry.stderrEncoding),
      );
    } catch (e) {
      throw new io.ProcessException(executable, arguments, e.toString());
    }
  }

  static dynamic _getDataSync(FileSystem fs, String path, Encoding encoding) {
    File file = fs.file(path);
    return encoding == null
        ? file.readAsBytesSync()
        : file.readAsStringSync(encoding: encoding);
  }

  io.Process asProcess(bool daemon) {
    assert(stdout is List<int>);
    assert(stderr is List<int>);
    return new _ReplayProcess(this, daemon);
  }
}

/// A [Process] implementation derives its data from a recording fragment.
class _ReplayProcess implements io.Process {
  @override
  final int pid;

  final List<int> _stdout;
  final List<int> _stderr;
  final StreamController<List<int>> _stdoutController;
  final StreamController<List<int>> _stderrController;
  final int _exitCode;
  final Completer<int> _exitCodeCompleter;

  _ReplayProcess(_ReplayResult result, bool daemon)
      : pid = result.pid,
        _stdout = result.stdout,
        _stderr = result.stderr,
        _stdoutController = new StreamController<List<int>>(),
        _stderrController = new StreamController<List<int>>(),
        _exitCode = result.exitCode,
        _exitCodeCompleter = new Completer<int>() {
    // Don't flush our stdio streams until we reach the outer event loop. This
    // is necessary because some of our process invocations transform the stdio
    // streams into broadcast streams (e.g. DeviceLogReader implementations),
    // and delaying our stdio stream production until we reach the outer event
    // loop allows all code running in the microtask loop to register as
    // listeners on these streams before we flush them.
    //
    // TODO(tvolkert): Once https://github.com/flutter/flutter/issues/7166 is
    //                 resolved, running on the outer event loop should be
    //                 sufficient (as described above), and we should switch to
    //                 Duration.ZERO. In the meantime, native file I/O
    //                 operations are causing a Duration.ZERO callback here to
    //                 run before our ProtocolDiscovery instantiation, and thus,
    //                 we flush our stdio streams before our protocol discovery
    //                 is listening on them (causing us to timeout waiting for
    //                 the observatory port discovery).
    new Timer(const Duration(milliseconds: 50), () {
      _stdoutController.add(_stdout);
      _stderrController.add(_stderr);
      if (!daemon) kill();
    });
  }

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  // TODO(tvolkert): Remove this once dart-lang/sdk@e5a16b1 lands in stable SDK.
  @override // ignore: OVERRIDE_ON_NON_OVERRIDING_SETTER
  set exitCode(Future<int> exitCode) =>
      throw new UnsupportedError('set exitCode');

  @override
  io.IOSink get stdin => throw new UnimplementedError();

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.SIGTERM]) {
    if (!_exitCodeCompleter.isCompleted) {
      _stdoutController.close();
      _stderrController.close();
      _exitCodeCompleter.complete(_exitCode);
      return true;
    }
    return false;
  }
}
