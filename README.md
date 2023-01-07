# Process

[![build](https://github.com/google/process.dart/actions/workflows/process.yml/badge.svg)](https://github.com/google/process.dart/actions/workflows/process.yml)
 [![pub package](https://img.shields.io/pub/v/process.svg)](https://pub.dev/packages/process)

A generic process invocation abstraction for Dart.

Like `dart:io`, `package:process` supplies a rich, Dart-idiomatic API for
spawning OS processes.

Unlike `dart:io`, `package:process`:

- Can be used to implement custom process invocation backends.
- Comes with a record-replay implementation out-of-the-box, making it super
  easy to test code that spawns processes in a hermetic way.

## Usage

Basic usage of 'package:process' is as follows:

Importing the package:

```dart
import 'package:process/process.dart';
```

Instantiate a `ProcessManager`:

```dart
final ProcessManager processManager = const LocalProcessManager();
```

Starts a process and runs it non-interactively to completion:

```dart
final Process process = await processManager.run(<String>[
  'ls',
]);

final ProcessResult result = await process.exitCode; // Waits for the process to exit.
print(result.stdout);
```

Returns true if the [executable] exists and if it can be executed:

```dart
final bool exists = await processManager.canRun('ls');
print(exists);
```

There are more process management APIs available, you can read more about them in [API docs](https://pub.dev/documentation/process/latest/process/process-library.html).
