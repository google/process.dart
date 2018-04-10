#### 3.0.1

* General cleanup

#### 3.0.0

* Cleanup getExecutablePath() to better respect the platform

#### 2.0.9

* Bumped `package:file` dependency

### 2.0.8

* Fixed method getArguments to qualify the map method with the specific
  String type

### 2.0.7

* Remove `set exitCode` instances

### 2.0.6

* Fix SDK constraint.
* rename .analysis_options file to analaysis_options.yaml.
* Use covariant in place of @checked.
* Update comment style generics.

### 2.0.5

* Bumped maximum Dart SDK version to 2.0.0-dev.infinity

### 2.0.4

* relax dependency requirement for `intl`

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
