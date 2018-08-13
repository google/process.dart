// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io
    show
        IOSink,
        Process,
        ProcessResult,
        ProcessSignal,
        ProcessStartMode,
        systemEncoding;

import 'package:file/file.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

import '../interface/process_manager.dart';
import 'can_run_manifest_entry.dart';
import 'common.dart';
import 'constants.dart';
import 'manifest.dart';
import 'replay_process_manager.dart';
import 'run_manifest_entry.dart';

/// Records process invocation activity and serializes it to disk.
///
/// A `RecordingProcessManager` decorates another `ProcessManager` instance by
/// recording all process invocation activity (including the stdout and stderr
/// of the associated processes) before delegating to the underlying manager.
///
/// This class enables "record / replay" tests, where you record the process
/// invocation activity during a real program run, serialize the activity to
/// disk, then fake all invocation activity during tests by replaying the
/// serialized recording.
///
/// See also:
///
/// * [ReplayProcessManager].
class RecordingProcessManager implements ProcessManager {
  static const List<String> _kSkippableExecutables = const <String>[
    'env',
    'xcrun',
  ];

  /// The manager to which this manager delegates.
  final ProcessManager delegate;

  /// The directory to which serialized invocation metadata will be written.
  final Directory destination;

  /// List of invocation metadata. Will be serialized as [kManifestName].
  final Manifest _manifest = new Manifest();

  /// Maps process IDs of running processes to exit code futures.
  final Map<int, Future<int>> _runningProcesses = <int, Future<int>>{};

  /// Constructs a new `RecordingProcessManager`.
  ///
  /// This manager will record all process invocations and serialize them to
  /// the specified [destination]. The underlying `ProcessManager` functionality
  /// will be delegated to [delegate].
  ///
  /// If [destination] does not already exist, or if it exists and is not empty,
  /// a [StateError] will be thrown.
  ///
  /// [destination] should be treated as opaque. Its contents are intended to
  /// be consumed only by [ReplayProcessManager] and are subject to change
  /// between versions of `package:process`.
  RecordingProcessManager(this.delegate, this.destination) {
    if (!destination.existsSync() || destination.listSync().isNotEmpty) {
      throw new StateError('Cannot record to ${destination.path}');
    }
  }

  /// The file system in which this manager will create recording files.
  FileSystem get fs => destination.fileSystem;

  @override
  Future<io.Process> start(
    List<dynamic> command, {
    String workingDirectory,
    Map<String, String> environment,
    bool includeParentEnvironment: true,
    bool runInShell: false,
    io.ProcessStartMode mode: io.ProcessStartMode.normal,
  }) async {
    io.Process process = await delegate.start(
      command,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );

    List<String> sanitizedCommand = sanitize(command);
    String basename = _getBasename(process.pid, sanitizedCommand);
    RunManifestEntry entry = new RunManifestEntry(
      pid: process.pid,
      basename: basename,
      command: sanitizedCommand,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      mode: mode,
    );
    _manifest.add(entry);

    _RecordingProcess result = new _RecordingProcess(
      manager: this,
      basename: basename,
      delegate: process,
    );
    await result.startRecording();
    _runningProcesses[process.pid] = result.exitCode.then((int exitCode) {
      _runningProcesses.remove(process.pid);
      entry.exitCode = exitCode;
      return exitCode;
    });

    return result;
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
    io.ProcessResult result = await delegate.run(
      command,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );

    List<String> sanitizedCommand = sanitize(command);
    String basename = _getBasename(result.pid, sanitizedCommand);
    _manifest.add(new RunManifestEntry(
      pid: result.pid,
      basename: basename,
      command: sanitizedCommand,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
      exitCode: result.exitCode,
    ));

    await _recordData(result.stdout, stdoutEncoding, '$basename.stdout');
    await _recordData(result.stderr, stderrEncoding, '$basename.stderr');

    return result;
  }

  Future<Null> _recordData(
      dynamic data, Encoding encoding, String basename) async {
    File file = fs.file('${destination.path}/$basename');
    IOSink recording = file.openWrite(encoding: encoding);
    try {
      if (encoding == null)
        recording.add(data);
      else
        recording.write(data);
      await recording.flush();
    } finally {
      await recording.close();
    }
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
    io.ProcessResult result = delegate.runSync(
      command,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );

    List<String> sanitizedCommand = sanitize(command);
    String basename = _getBasename(result.pid, sanitizedCommand);
    _manifest.add(new RunManifestEntry(
      pid: result.pid,
      basename: basename,
      command: sanitizedCommand,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
      exitCode: result.exitCode,
    ));

    _recordDataSync(result.stdout, stdoutEncoding, '$basename.stdout');
    _recordDataSync(result.stderr, stderrEncoding, '$basename.stderr');

    return result;
  }

  void _recordDataSync(dynamic data, Encoding encoding, String basename) {
    File file = fs.file('${destination.path}/$basename');
    if (encoding == null)
      file.writeAsBytesSync(data, flush: true);
    else
      file.writeAsStringSync(data, encoding: encoding, flush: true);
  }

  @override
  bool canRun(dynamic executable, {String workingDirectory}) {
    bool result =
        delegate.canRun(executable, workingDirectory: workingDirectory);
    _manifest.add(new CanRunManifestEntry(
        executable: executable.toString(), result: result));
    return result;
  }

  @override
  bool killPid(int pid, [io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    return delegate.killPid(pid, signal);
  }

  /// Returns a human-readable identifier for the specified executable.
  String _getBasename(int pid, List<String> sanitizedCommand) {
    String index = new NumberFormat('000').format(_manifest.length);
    String identifier = 'executable';
    for (String element in sanitizedCommand) {
      if (element.startsWith('-')) {
        // Ignore flags.
        continue;
      }
      identifier = path.basename(element);
      if (!_kSkippableExecutables.contains(identifier)) {
        break;
      }
    }
    return '$index.$identifier.$pid';
  }

  /// Flushes pending data to [destination].
  ///
  /// This manager may buffer invocation metadata in memory as it sees fit.
  /// Calling `flush` will force the manager to write any pending data to disk.
  /// This returns a future that completes when all pending data has been
  /// written to disk.
  ///
  /// Failure to call this method before the current process exits will likely
  /// cause invocation data to be lost.
  ///
  /// If [finishRunningProcesses] is true, the returned future will only
  /// complete after all running processes have exited, thus guaranteeing that
  /// no new invocation data will be generated until new processes are invoked.
  /// Any processes that don't exit on their own within the specified [timeout]
  /// will be marked as daemon processes in the serialized metadata and will be
  /// signalled with `SIGTERM`. If such processes *still* don't exit within the
  /// specified [timeout] after being signalled, they'll be marked as not
  /// responding in the serialized metadata.
  ///
  /// If [finishRunningProcesses] is false (the default), then [timeout] is
  /// ignored.
  Future<Null> flush({
    bool finishRunningProcesses: false,
    Duration timeout: const Duration(milliseconds: 20),
  }) async {
    if (finishRunningProcesses) {
      await _waitForRunningProcessesToExit(timeout);
    }
    await _writeManifestToDisk();
  }

  /// Waits for all running processes to exit, and records their exit codes in
  /// the process manifest. Any process that doesn't exit within [timeout]
  /// will be marked as a [RunManifestEntry.daemon] and be signalled with
  /// `SIGTERM`. If such processes *still* don't exit within [timeout] after
  /// being signalled, they'll be marked as [RunManifestEntry.notResponding].
  Future<Null> _waitForRunningProcessesToExit(Duration timeout) async {
    await _waitForRunningProcessesToExitWithTimeout(
        timeout: timeout,
        onTimeout: (RunManifestEntry entry) {
          entry.daemon = true;
          delegate.killPid(entry.pid);
        });
    // Now that we explicitly signalled the processes that timed out asking
    // them to shutdown, wait one more time for those processes to exit.
    await _waitForRunningProcessesToExitWithTimeout(
        timeout: timeout,
        onTimeout: (RunManifestEntry entry) {
          entry.notResponding = true;
        });
  }

  Future<Null> _waitForRunningProcessesToExitWithTimeout({
    Duration timeout,
    void onTimeout(RunManifestEntry entry),
  }) async {
    void callOnTimeout(int pid) => onTimeout(_manifest.getRunEntry(pid));
    await Future.wait(new List<Future<int>>.from(_runningProcesses.values))
        .timeout(timeout, onTimeout: () {
      _runningProcesses.keys.forEach(callOnTimeout);
      return null;
    });
  }

  /// Writes our process invocation manifest to disk in the destination folder.
  Future<Null> _writeManifestToDisk() async {
    File manifestFile = fs.file('${destination.path}/$kManifestName');
    await manifestFile.writeAsString(_manifest.toJson(), flush: true);
  }
}

/// A [Process] implementation that records `stdout` and `stderr` stream events
/// to disk before forwarding them on to the underlying stream listener.
class _RecordingProcess implements io.Process {
  final io.Process delegate;
  final String basename;
  final RecordingProcessManager manager;

  // ignore: close_sinks
  final StreamController<List<int>> _stdout = new StreamController<List<int>>();
  // ignore: close_sinks
  final StreamController<List<int>> _stderr = new StreamController<List<int>>();

  bool _started = false;

  _RecordingProcess({this.manager, this.basename, this.delegate});

  Future<Null> startRecording() async {
    assert(!_started);
    _started = true;
    await Future.wait(<Future<Null>>[
      _recordStream(delegate.stdout, _stdout, 'stdout'),
      _recordStream(delegate.stderr, _stderr, 'stderr'),
    ]);
  }

  Future<Null> _recordStream(
    Stream<List<int>> stream,
    StreamController<List<int>> controller,
    String suffix,
  ) async {
    String path = '${manager.destination.path}/$basename.$suffix';
    File file = await manager.fs.file(path).create();
    RandomAccessFile recording = await file.open(mode: FileMode.write);
    stream.listen(
      (List<int> data) {
        // Write synchronously to guarantee that the order of data
        // within our recording is preserved across stream notifications.
        recording.writeFromSync(data);
        // Flush immediately so that if the program crashes, forensic
        // data from the recording won't be lost.
        recording.flushSync();
        controller.add(data);
      },
      onError: (dynamic error, StackTrace stackTrace) {
        recording.closeSync();
        controller.addError(error, stackTrace);
      },
      onDone: () {
        recording.closeSync();
        controller.close();
      },
    );
  }

  @override
  Future<int> get exitCode => delegate.exitCode;

  @override
  Stream<List<int>> get stdout {
    assert(_started);
    return _stdout.stream;
  }

  @override
  Stream<List<int>> get stderr {
    assert(_started);
    return _stderr.stream;
  }

  @override
  io.IOSink get stdin {
    // We don't currently support recording `stdin`.
    return delegate.stdin;
  }

  @override
  int get pid => delegate.pid;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) =>
      delegate.kill(signal);
}
