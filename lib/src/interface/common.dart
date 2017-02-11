// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' show File, Directory;

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';

/// Searches the `PATH` for the actual executable that [commandName] is supposed
/// to launch.
///
/// Return `null` if the executable cannot be found.
@visibleForTesting
String getExecutablePath(String commandName, String workingDirectory,
    {Platform platform}) {
  platform ??= new LocalPlatform();
  workingDirectory ??= Directory.current.path;
  // TODO(goderbauer): refactor when github.com/google/platform.dart/issues/2
  //     is available.
  String pathSeparator = platform.isWindows ? ';' : ':';

  List<String> extensions = <String>[];
  if (platform.isWindows && p.extension(commandName).isEmpty) {
    extensions = platform.environment['PATHEXT'].split(pathSeparator);
  }

  List<String> candidates = <String>[];
  if (commandName.contains(p.separator)) {
    candidates =
        _getCandidatePaths(commandName, <String>[workingDirectory], extensions);
  } else {
    List<String> searchPath = platform.environment['PATH'].split(pathSeparator);
    candidates = _getCandidatePaths(commandName, searchPath, extensions);
  }
  return candidates.firstWhere((String path) => new File(path).existsSync(),
      orElse: () => null);
}

/// Returns all possible combinations of `$searchPath\$commandName.$ext` for
/// `searchPath` in [searchPaths] and `ext` in [extensions].
///
/// If [extensions] is empty, it will just enumerate all
/// `$searchPath\$commandName`.
/// If [commandName] is an absolute path, it will just enumerate
/// `$commandName.$ext`.
Iterable<String> _getCandidatePaths(
    String commandName, List<String> searchPaths, List<String> extensions) {
  List<String> withExtensions = extensions.isNotEmpty
      ? extensions.map((String ext) => '$commandName$ext').toList()
      : <String>[commandName];
  if (p.isAbsolute(commandName)) {
    return withExtensions;
  }
  return searchPaths
      .map((String path) =>
          withExtensions.map((String command) => p.join(path, command)))
      .expand((Iterable<String> e) => e)
      .toList();
}
