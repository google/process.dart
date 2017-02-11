import 'manifest.dart';
import 'replay_process_manager.dart';

/// An entry in the process invocation manifest.
///
/// Each entry in the [Manifest] represents a single recorded process
/// invocation.
abstract class ManifestEntry {
  /// Whether this entry has been "invoked" by [ReplayProcessManager].
  bool get invoked => _invoked;
  bool _invoked = false;

  /// Marks this entry as having been "invoked" by [ReplayProcessManager].
  void setInvoked() {
    _invoked = true;
  }

  /// The type of this [ManifestEntry].
  String get type;

  /// Returns a JSON-encodable representation of this manifest entry.
  Map<String, dynamic> toJson();
}

/// A lightweight class that provides a means of building a manifest entry
/// JSON object.
class JsonBuilder {
  /// The JSON-encodable object.
  final Map<String, dynamic> entry = <String, dynamic>{};

  /// Adds the specified key/value pair to the manifest entry iff the value
  /// is non-null. If [jsonValue] is specified, its value will be used instead
  /// of the raw value.
  JsonBuilder add(String name, dynamic value, [dynamic jsonValue()]) {
    if (value != null) {
      entry[name] = jsonValue == null ? value : jsonValue();
    }
    return this;
  }
}

/// Throws a [FormatException] if [data] does not contain [key].
void checkRequiredField(Map<String, dynamic> data, String key) {
  if (!data.containsKey(key))
    throw new FormatException('Required field missing: $key');
}
