// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:platform/platform.dart';
import 'package:process/src/interface/common.dart';
import 'package:test/test.dart';

void main() {
  group('getExecutablePath', () {
    late FileSystem fs;
    late Directory workingDir, dir1, dir2, dir3;

    void initialize(FileSystemStyle style) {
      setUp(() {
        fs = MemoryFileSystem(style: style);
        workingDir = fs.systemTempDirectory.createTempSync('work_dir_');
        dir1 = fs.systemTempDirectory.createTempSync('dir1_');
        dir2 = fs.systemTempDirectory.createTempSync('dir2_');
        dir3 = fs.systemTempDirectory.createTempSync('dir3_');
      });
    }

    tearDown(() {
      <Directory>[workingDir, dir1, dir2, dir3]
          .forEach((Directory d) => d.deleteSync(recursive: true));
    });

    group('on windows', () {
      late Platform platform;

      initialize(FileSystemStyle.windows);

      setUp(() {
        platform = FakePlatform(
          operatingSystem: 'windows',
          environment: <String, String>{
            'PATH': '${dir1.path};${dir2.path}',
            'PATHEXT': '.exe;.bat'
          },
        );
      });

      test('absolute', () {
        String command = fs.path.join(dir3.path, 'bla.exe');
        String expectedPath = command;
        fs.file(command).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in path', () {
        String command = 'bla.exe';
        String expectedPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in path multiple times', () {
        String command = 'bla.exe';
        String expectedPath = fs.path.join(dir1.path, command);
        String wrongPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();
        fs.file(wrongPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in subdir of work dir', () {
        String command = fs.path.join('.', 'foo', 'bla.exe');
        String expectedPath = fs.path.join(workingDir.path, command);
        fs.file(expectedPath).createSync(recursive: true);

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in work dir', () {
        String command = fs.path.join('.', 'bla.exe');
        String expectedPath = fs.path.join(workingDir.path, command);
        String wrongPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();
        fs.file(wrongPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);

        command = fs.path.withoutExtension(command);
        executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('with multiple extensions', () {
        String command = 'foo';
        String expectedPath = fs.path.join(dir1.path, '$command.exe');
        String wrongPath1 = fs.path.join(dir1.path, '$command.bat');
        String wrongPath2 = fs.path.join(dir2.path, '$command.exe');
        fs.file(expectedPath).createSync();
        fs.file(wrongPath1).createSync();
        fs.file(wrongPath2).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('not found', () {
        String command = 'foo.exe';

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        expect(executablePath, isNull);
      });

      test('when path has spaces', () {
        expect(
            sanitizeExecutablePath('Program Files\\bla.exe',
                platform: platform),
            '"Program Files\\bla.exe"');
        expect(
            sanitizeExecutablePath('ProgramFiles\\bla.exe', platform: platform),
            'ProgramFiles\\bla.exe');
        expect(
            sanitizeExecutablePath('"Program Files\\bla.exe"',
                platform: platform),
            '"Program Files\\bla.exe"');
        expect(
            sanitizeExecutablePath('\"Program Files\\bla.exe\"',
                platform: platform),
            '\"Program Files\\bla.exe\"');
        expect(
            sanitizeExecutablePath('C:\\\"Program Files\"\\bla.exe',
                platform: platform),
            'C:\\\"Program Files\"\\bla.exe');
      });

      test('with absolute path when currentDirectory getter throws', () {
        FileSystem fsNoCwd = MemoryFileSystemNoCwd(fs);
        String command = fs.path.join(dir3.path, 'bla.exe');
        String expectedPath = command;
        fs.file(command).createSync();

        String? executablePath = getExecutablePath(
          command,
          null,
          platform: platform,
          fs: fsNoCwd,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('with relative path when currentDirectory getter throws', () {
        FileSystem fsNoCwd = MemoryFileSystemNoCwd(fs);
        String command = fs.path.join('.', 'bla.exe');

        String? executablePath = getExecutablePath(
          command,
          null,
          platform: platform,
          fs: fsNoCwd,
        );
        expect(executablePath, isNull);
      });
    });

    group('on Linux', () {
      late Platform platform;

      initialize(FileSystemStyle.posix);

      setUp(() {
        platform = FakePlatform(
            operatingSystem: 'linux',
            environment: <String, String>{'PATH': '${dir1.path}:${dir2.path}'});
      });

      test('absolute', () {
        String command = fs.path.join(dir3.path, 'bla');
        String expectedPath = command;
        String wrongPath = fs.path.join(dir3.path, 'bla.bat');
        fs.file(command).createSync();
        fs.file(wrongPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('in path multiple times', () {
        String command = 'xxx';
        String expectedPath = fs.path.join(dir1.path, command);
        String wrongPath = fs.path.join(dir2.path, command);
        fs.file(expectedPath).createSync();
        fs.file(wrongPath).createSync();

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        _expectSamePath(executablePath, expectedPath);
      });

      test('not found', () {
        String command = 'foo';

        String? executablePath = getExecutablePath(
          command,
          workingDir.path,
          platform: platform,
          fs: fs,
        );
        expect(executablePath, isNull);
      });

      test('when path has spaces', () {
        expect(
            sanitizeExecutablePath('/usr/local/bin/foo bar',
                platform: platform),
            '/usr/local/bin/foo bar');
      });
    });
  });
}

void _expectSamePath(String? actual, String? expected) {
  expect(actual, isNotNull);
  expect(actual!.toLowerCase(), expected!.toLowerCase());
}

class MemoryFileSystemNoCwd extends ForwardingFileSystem {
  MemoryFileSystemNoCwd(FileSystem delegate) : super(delegate);

  @override
  Directory get currentDirectory {
    throw FileSystemException('Access denied');
  }
}
