// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'command_element.dart';

/// Sanitizes the specified [command] by running any non-deterministic
/// segments through a [sanitizer](CommandSanitizer) if possible.
List<String> sanitize(List<dynamic> command) {
  return command
      .map((dynamic element) {
        if (element is CommandElement) {
          return element.sanitized;
        }
        return element.toString();
      })
      .toList()
      .cast<String>();
}
