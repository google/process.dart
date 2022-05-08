[![Process Package](https://github.com/google/process.dart/actions/workflows/process.yml/badge.svg)](https://github.com/google/process.dart/actions/workflows/process.yml)
[![pub package](https://img.shields.io/pub/v/process.svg)](https://pub.dev/packages/process)

A generic process invocation abstraction for Dart.

Like `dart:io`, `package:process` supplies a rich, Dart-idiomatic API for
spawning OS processes.

Unlike `dart:io`, `package:process`:

- Can be used to implement custom process invocation backends.
- Comes with a record-replay implementation out-of-the-box, making it super
  easy to test code that spawns processes in a hermetic way.
