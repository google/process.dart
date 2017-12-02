// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show IOException;

/// Exception thrown when a process cannot be spawned.
class ProcessException implements IOException {
  /// Creates a new process exception.
  const ProcessException(this.executable, this.arguments,
      [this.message = '', this.errorCode = 0]);

  /// Contains the arguments provided for the process.
  final List<String> arguments;

  /// Contains the executable provided for the process.
  final String executable;

  /// Contains the OS error code for the process exception if any.
  final int errorCode;

  /// Contains the system message for the process exception if any.
  final String message;

  /// Returns a string representation of this object.
  @override
  String toString() {
    String msg = (message == null) ? 'OS error code: $errorCode' : message;
    String args = arguments.join(' ');
    return 'ProcessException: $msg\n  Command: $executable $args';
  }
}
