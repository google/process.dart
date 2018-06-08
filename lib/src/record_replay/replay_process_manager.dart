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
        systemEncoding;

import 'package:file/file.dart';
import 'package:path/path.dart' as path;

import '../interface/process_manager.dart';
import 'can_run_manifest_entry.dart';
import 'common.dart';
import 'constants.dart';
import 'manifest.dart';
import 'run_manifest_entry.dart';
import 'recording_process_manager.dart';

/// Fakes all process invocations by replaying a previously-recorded series
/// of invocations.
///
/// Recordings exist as opaque directories that are produced by
/// [RecordingProcessManager].
class ReplayProcessManager implements ProcessManager {
  final Manifest _manifest;

  /// The location of the serialized recording that's driving this manager.
  final Directory location;

  /// If non-null, processes spawned by this manager will delay their
  /// `stdout` and `stderr` stream production by the this amount. See
  /// description of the associated parameter in [create].
  final Duration streamDelay;

  ReplayProcessManager._(this._manifest, this.location, this.streamDelay);

  /// Creates a new `ReplayProcessManager` capable of replaying a recording that
  /// was serialized to the specified [location] by [RecordingProcessManager].
  ///
  /// If [location] does not exist, or if it does not represent a valid
  /// recording (as determined by [RecordingProcessManager]), an [ArgumentError]
  /// will be thrown.
  ///
  /// If [streamDelay] is specified, processes spawned by this manager will
  /// delay their `stdout` and `stderr` stream production by the specified
  /// amount. This is useful in cases where the real process invocation had
  /// a necessary delay in stream production, and you need to mirror that
  /// behavior. e.g. you spawn a `tail` process to tail a log file, then in a
  /// follow-on event loop, you invoke a `startServer` process, which starts
  /// producing log output. In this case, you may need to delay the `tail`
  /// output to prevent its stream from flushing all its content before you
  /// start listening.
  static Future<ReplayProcessManager> create(
    Directory location, {
    Duration streamDelay: Duration.zero,
  }) async {
    assert(streamDelay != null);

    if (!location.existsSync()) {
      throw new ArgumentError.value(location.path, 'location', "Doesn't exist");
    }

    FileSystem fs = location.fileSystem;
    File manifestFile = fs.file(path.join(location.path, kManifestName));
    if (!manifestFile.existsSync()) {
      throw new ArgumentError.value(
          location, 'location', 'Does not represent a valid recording');
    }

    String content = await manifestFile.readAsString();
    try {
      // We don't validate the existence of all stdout and stderr files
      // referenced in the manifest.
      Manifest manifest = new Manifest.fromJson(content);
      return new ReplayProcessManager._(manifest, location, streamDelay);
    } on FormatException catch (e) {
      throw new ArgumentError('$kManifestName is not a valid JSON file: $e');
    }
  }

  @override
  Future<io.Process> start(
    List<dynamic> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    io.ProcessStartMode mode: io.ProcessStartMode.normal,
  }) async {
    RunManifestEntry entry = _popRunEntry(command, mode: mode);
    _ReplayResult result = await _ReplayResult.create(this, entry);
    return result.asProcess(entry.daemon);
  }

  @override
  Future<io.ProcessResult> run(
    List<dynamic> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: io.systemEncoding,
    Encoding stderrEncoding: io.systemEncoding,
  }) async {
    RunManifestEntry entry = _popRunEntry(command,
        stdoutEncoding: stdoutEncoding, stderrEncoding: stderrEncoding);
    return await _ReplayResult.create(this, entry);
  }

  @override
  io.ProcessResult runSync(
    List<dynamic> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    Encoding stdoutEncoding: io.systemEncoding,
    Encoding stderrEncoding: io.systemEncoding,
  }) {
    RunManifestEntry entry = _popRunEntry(command,
        stdoutEncoding: stdoutEncoding, stderrEncoding: stderrEncoding);
    return _ReplayResult.createSync(this, entry);
  }

  /// Finds and returns the next entry in the process manifest that matches
  /// the specified process arguments. Once found, it marks the manifest entry
  /// as having been invoked and thus not eligible for invocation again.
  RunManifestEntry _popRunEntry(
    List<dynamic> command, {
    io.ProcessStartMode mode,
    Encoding stdoutEncoding,
    Encoding stderrEncoding,
  }) {
    List<String> sanitizedCommand = sanitize(command);
    RunManifestEntry entry = _manifest.findPendingRunEntry(
      command: sanitizedCommand,
      mode: mode,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );

    if (entry == null) {
      throw new io.ProcessException(sanitizedCommand.first,
          sanitizedCommand.skip(1).toList(), 'No matching invocation found');
    }

    entry.setInvoked();
    return entry;
  }

  @override
  bool canRun(dynamic executable, {String workingDirectory}) {
    CanRunManifestEntry entry = _manifest.findPendingCanRunEntry(
      executable: executable.toString(),
    );
    if (entry == null) {
      throw new ArgumentError('No matching invocation found for $executable');
    }
    entry.setInvoked();
    return entry.result;
  }

  @override
  bool killPid(int pid, [io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    throw new UnsupportedError(
        "$runtimeType.killPid() has not been implemented because at the time "
        "of its writing, it wasn't needed. If you're hitting this error, you "
        "should implement it.");
  }
}

/// A [ProcessResult] implementation that derives its data from a recording
/// fragment.
class _ReplayResult implements io.ProcessResult {
  final ReplayProcessManager manager;

  @override
  final int pid;

  @override
  final int exitCode;

  @override
  final dynamic stdout;

  @override
  final dynamic stderr;

  _ReplayResult._({
    this.manager,
    this.pid,
    this.exitCode,
    this.stdout,
    this.stderr,
  });

  static Future<_ReplayResult> create(
    ReplayProcessManager manager,
    RunManifestEntry entry,
  ) async {
    FileSystem fs = manager.location.fileSystem;
    String basePath = path.join(manager.location.path, entry.basename);
    try {
      return new _ReplayResult._(
        manager: manager,
        pid: entry.pid,
        exitCode: entry.exitCode,
        stdout: await _getData(fs, '$basePath.stdout', entry.stdoutEncoding),
        stderr: await _getData(fs, '$basePath.stderr', entry.stderrEncoding),
      );
    } catch (e) {
      throw new io.ProcessException(
          entry.executable, entry.arguments, e.toString());
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
    ReplayProcessManager manager,
    RunManifestEntry entry,
  ) {
    FileSystem fs = manager.location.fileSystem;
    String basePath = path.join(manager.location.path, entry.basename);
    try {
      return new _ReplayResult._(
        manager: manager,
        pid: entry.pid,
        exitCode: entry.exitCode,
        stdout: _getDataSync(fs, '$basePath.stdout', entry.stdoutEncoding),
        stderr: _getDataSync(fs, '$basePath.stderr', entry.stderrEncoding),
      );
    } catch (e) {
      throw new io.ProcessException(
          entry.executable, entry.arguments, e.toString());
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
    // Don't flush our stdio streams until we at least reach the outer event
    // loop. i.e. even if `streamDelay` is zero, we still want to use the timer.
    new Timer(result.manager.streamDelay, () {
      if (!_stdoutController.isClosed) {
        _stdoutController.add(_stdout);
      }
      if (!_stderrController.isClosed) {
        _stderrController.add(_stderr);
      }
      if (!daemon) kill();
    });
  }

  @override
  Stream<List<int>> get stdout => _stdoutController.stream;

  @override
  Stream<List<int>> get stderr => _stderrController.stream;

  @override
  Future<int> get exitCode => _exitCodeCompleter.future;

  @override
  io.IOSink get stdin => throw new UnimplementedError();

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    if (!_exitCodeCompleter.isCompleted) {
      _stdoutController.close();
      _stderrController.close();
      _exitCodeCompleter.complete(_exitCode);
      return true;
    }
    return false;
  }
}
