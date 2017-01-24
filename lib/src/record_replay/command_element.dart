// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:process/process.dart';

/// Callback used to [sanitize](CommandElement.sanitized) a [CommandElement]
/// for the purpose of recording.
typedef String CommandSanitizer(String rawValue);

/// A command element capable of holding both a raw and sanitized value.
///
/// Instances of this type can be used in the `command` list of the
/// [ProcessManager.start], [ProcessManager.run], and [ProcessManager.runSync]
/// methods.
///
/// Each command element has:
///   - A raw value, which is the value that should passed to the underlying
///     operating system to invoke the process.
///   - A sanitized value, which is the value that's serialized when used with
///     [RecordingProcessManager] and looked up in the replay log when used
///     with [ReplayProcessManager]. Sanitized values typically will remove
///     user-specific segments (such as the user's home directory) or random
///     segments (such as temporary file names). Sanitizing values allows you
///     to guarantee determinism in your process invocation lookups, thus
///     removing flakiness in tests.
///
/// This class implements [toString] to return the element's raw value, meaning
/// instances of this class can be passed directly to [LocalProcessManager]
/// and will work as intended.
class CommandElement {
  final CommandSanitizer _sanitizer;

  /// Creates a new command element with the specified [raw] value.
  ///
  /// If a [sanitizer] is specified, it will be used to generate this command
  /// element's [sanitized] value. If it is unspecified, the raw value will be
  /// used as the sanitized value.
  CommandElement(this.raw, {CommandSanitizer sanitizer})
      : _sanitizer = sanitizer;

  /// This command element's raw, unsanitized, value.
  ///
  /// This value is liable to contain non-deterministic segments, such as
  /// OS-generated temporary file names. It is suitable for passing to the
  /// operating system to invoke a process, but it is not suitable for
  /// record/replay.
  final String raw;

  /// This command element's sanitized value.
  ///
  /// This value has been stripped of any non-deterministic segments, such as
  /// OS-generated temporary file names or user-specific values. It is suitable
  /// for record/replay, but it is not suitable for passing to the operating
  /// system to invoke a process.
  String get sanitized => _sanitizer == null ? raw : _sanitizer(raw);

  @override
  String toString() => raw;
}
