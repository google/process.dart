### 2.0.3
* relax dependency requirement for `platform`

#### 2.0.2

* Fix a strong mode function expression return type inference bug with Dart
  1.23.0-dev.10.0.

#### 2.0.1

* Fixed bug in `ReplayProcessManager` whereby it could try to write to `stdout`
  or `stderr` after the streams were closed.

#### 2.0.0

* Bumped `package:file` dependency to 2.0.1

#### 1.1.0

* Added support to transparently find the right executable under Windows.

#### 1.0.1

* The `executable` and `arguments` parameters have been merged into one
  `command` parameter in the `run`, `runSync`, and `start` methods of
  `ProcessManager`.
* Added support for sanitization of command elements in
  `RecordingProcessManager` and `ReplayProcessManager` via the `CommandElement`
  class.

#### 1.0.0

* Initial version
