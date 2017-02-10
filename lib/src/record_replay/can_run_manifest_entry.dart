import 'manifest_entry.dart';

/// An entry in the process invocation manifest for `canRun`.
class CanRunManifestEntry extends ManifestEntry {
  @override
  final String type = 'can_run';

  /// The name of the executable for which the run-ability is checked.
  final String executable;

  /// The result of the check.
  final bool result;

  /// Creates a new manifest entry with the given properties.
  CanRunManifestEntry({this.executable, this.result});

  /// Creates a new manifest entry populated with the specified JSON [data].
  ///
  /// If any required fields are missing from the JSON data, this will throw
  /// a [FormatException].
  factory CanRunManifestEntry.fromJson(Map<String, dynamic> data) {
    checkRequiredField(data, 'executable');
    checkRequiredField(data, 'result');
    CanRunManifestEntry entry = new CanRunManifestEntry(
      executable: data['executable'],
      result: data['result'],
    );
    return entry;
  }

  @override
  Map<String, dynamic> toJson() => new JsonBuilder()
      .add('executable', executable)
      .add('result', result)
      .entry;
}
