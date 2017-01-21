// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show ProcessStartMode;

import 'manifest_entry.dart';

/// Tests if two lists contain pairwise equal elements.
bool _areListsEqual/*<T>*/(
    List<dynamic/*=T*/ > list1, List<dynamic/*=T*/ > list2) {
  int i = 0;
  return list1 != null &&
      list2 != null &&
      list1.length == list2.length &&
      list1.every((dynamic element) => element == list2[i++]);
}

/// Tells whether [testValue] is non-null and equal to [entryValue]. If
/// [isEqual] is specified, it will be used to determine said equality.
bool _isHit(
  dynamic entryValue,
  dynamic testValue, [
  bool isEqual(dynamic value1, dynamic value2),
]) {
  if (testValue == null) {
    return true;
  } else if (isEqual != null) {
    return isEqual(entryValue, testValue);
  }
  return entryValue == testValue;
}

/// The process invocation manifest, holding metadata about every recorded
/// process invocation.
class Manifest {
  final List<ManifestEntry> _entries = <ManifestEntry>[];

  /// Creates a new manifest.
  Manifest();

  /// Creates a new manifest populated with the specified [json] data.
  ///
  /// If [json] does not represent a valid JSON string (matching the format of
  /// [toJson]), a [FormatException] will be thrown.
  factory Manifest.fromJson(String json) {
    List<Map<String, dynamic>> decoded = new JsonDecoder().convert(json);
    Manifest manifest = new Manifest();
    decoded.forEach((Map<String, dynamic> entry) {
      manifest._entries.add(new ManifestEntry.fromJson(entry));
    });
    return manifest;
  }

  /// Adds the specified [entry] to this manifest.
  void add(ManifestEntry entry) => _entries.add(entry);

  /// The number of entries currently in the manifest.
  int get length => _entries.length;

  /// Gets the entry whose [ManifestEntry.pid] matches the specified [pid].
  ManifestEntry getEntry(int pid) {
    return _entries.firstWhere((ManifestEntry entry) => entry.pid == pid);
  }

  /// Finds the first manifest entry that has not been invoked and whose
  /// metadata matches the specified criteria. If no arguments are specified,
  /// this will simply return the first entry that has not yet been invoked.
  ManifestEntry findPendingEntry({
    String executable,
    List<String> arguments,
    ProcessStartMode mode,
    Encoding stdoutEncoding,
    Encoding stderrEncoding,
  }) {
    return _entries.firstWhere(
      (ManifestEntry entry) {
        bool hit = !entry.invoked;
        // Ignore workingDirectory & environment, as they could
        // yield false negatives.
        hit = hit && _isHit(entry.executable, executable);
        hit = hit && _isHit(entry.arguments, arguments, _areListsEqual);
        hit = hit && _isHit(entry.mode, mode);
        hit = hit && _isHit(entry.stdoutEncoding, stdoutEncoding);
        hit = hit && _isHit(entry.stderrEncoding, stderrEncoding);
        return hit;
      },
      orElse: () => null,
    );
  }

  /// Returns a JSON-encoded representation of this manifest.
  String toJson() {
    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    _entries.forEach((ManifestEntry entry) => list.add(entry.toJson()));
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}
