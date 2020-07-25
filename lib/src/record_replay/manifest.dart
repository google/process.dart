// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io' show ProcessStartMode;

import 'can_run_manifest_entry.dart';
import 'manifest_entry.dart';
import 'run_manifest_entry.dart';

/// Tests if two lists contain pairwise equal elements.
bool _areListsEqual<T>(List<T> list1, List<T> list2) {
  int i = 0;
  return list1 != null &&
      list2 != null &&
      list1.length == list2.length &&
      list1.every((dynamic element) => element == list2[i++]);
}

/// Tells whether [testValue] is non-null and equal to [entryValue]. If
/// [isEqual] is specified, it will be used to determine said equality.
bool _isHit<T>(
  T entryValue,
  T testValue, [
  bool isEqual(T value1, T value2),
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
  /// Creates a new manifest.
  Manifest();

  /// Creates a new manifest populated with the specified [json] data.
  ///
  /// If [json] does not represent a valid JSON string (matching the format of
  /// [toJson]), a [FormatException] will be thrown.
  factory Manifest.fromJson(String json) {
    List<Map<String, dynamic>> decoded =
        (JsonDecoder().convert(json) as List<dynamic>)
            .cast<Map<String, dynamic>>();
    Manifest manifest = Manifest();
    decoded.forEach((Map<String, dynamic> entry) {
      switch (entry['type'] as String) {
        case 'run':
          manifest._entries.add(
              RunManifestEntry.fromJson(entry['body'] as Map<String, dynamic>));
          break;
        case 'can_run':
          manifest._entries.add(CanRunManifestEntry.fromJson(
              entry['body'] as Map<String, dynamic>));
          break;
        default:
          throw UnsupportedError('Manifest type ${entry['type']} is unkown.');
      }
    });
    return manifest;
  }

  final List<ManifestEntry> _entries = <ManifestEntry>[];

  /// Adds the specified [entry] to this manifest.
  void add(ManifestEntry entry) => _entries.add(entry);

  /// The number of entries currently in the manifest.
  int get length => _entries.length;

  /// Gets the entry whose [RunManifestEntry.pid] matches the specified [pid].
  ManifestEntry getRunEntry(int pid) {
    return _entries.firstWhere(
        (ManifestEntry entry) => entry is RunManifestEntry && entry.pid == pid);
  }

  /// Finds the first manifest entry that has not been invoked and whose
  /// metadata matches the specified criteria. If no arguments are specified,
  /// this will simply return the first entry that has not yet been invoked.
  ManifestEntry findPendingRunEntry({
    List<String> command,
    ProcessStartMode mode,
    Encoding stdoutEncoding,
    Encoding stderrEncoding,
  }) {
    return _entries.firstWhere(
      (ManifestEntry entry) {
        return entry is RunManifestEntry &&
            !entry.invoked &&
            _isHit(entry.command, command, _areListsEqual) &&
            _isHit(entry.mode, mode) &&
            _isHit(entry.stdoutEncoding, stdoutEncoding) &&
            _isHit(entry.stderrEncoding, stderrEncoding);
      },
      orElse: () => null,
    );
  }

  /// Finds the first manifest entry that has not been invoked and whose
  /// metadata matches the specified criteria. If no arguments are specified,
  /// this will simply return the first entry that has not yet been invoked.
  ManifestEntry findPendingCanRunEntry({
    String executable,
  }) {
    return _entries.firstWhere(
      (ManifestEntry entry) {
        return entry is CanRunManifestEntry &&
            !entry.invoked &&
            _isHit(entry.executable, executable);
      },
      orElse: () => null,
    );
  }

  /// Returns a JSON-encoded representation of this manifest.
  String toJson() {
    List<Map<String, dynamic>> list = <Map<String, dynamic>>[];
    _entries.forEach((ManifestEntry entry) => list.add(JsonBuilder()
        .add('type', entry.type)
        .add('body', entry.toJson())
        .entry));
    return const JsonEncoder.withIndent('  ').convert(list);
  }
}
