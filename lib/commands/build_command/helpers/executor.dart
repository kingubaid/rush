import 'dart:io' show Directory, File, FileSystemEntity, Platform;

import 'package:path/path.dart' as p;
import 'package:rush_cli/helpers/cmd_utils.dart';
import 'package:rush_cli/helpers/process_streamer.dart';
import 'package:rush_prompt/rush_prompt.dart';
import 'package:dart_console/dart_console.dart' show ConsoleColor;
import 'package:process_runner/process_runner.dart' show ProcessRunnerException;

enum ExeType { d8, d8ForSup, proguard, jetifier }

class Executor {
  final String _cd;
  final String _dataDir;

  Executor(this._cd, this._dataDir);

  /// Executes the D8 tool which is required for dexing the extension.
  Future<void> execD8(String org, BuildStep step, bool deJet) async {
    final args = () {
      final d8 = File(p.join(_dataDir, 'tools', 'other', 'd8.jar'));

      final rawOrgDirX =
          Directory(p.join(_dataDir, 'workspaces', org, 'raw', 'x', org));
      final rawOrgDirSup =
          Directory(p.join(_dataDir, 'workspaces', org, 'raw', 'sup', org));

      final rawPath = deJet ? rawOrgDirSup.path : rawOrgDirX.path;

      final res = <String>['java'];

      res
        ..addAll(['-cp', d8.path])
        ..add('com.android.tools.r8.D8')
        ..addAll(['--lib', p.join(_cd, '.rush', 'dev-deps', 'android.jar')])
        ..addAll([
          '--release',
          '--output',
          p.join(rawPath, 'classes.jar'),
          p.join(rawPath, 'files', 'AndroidRuntime.jar'),
        ]);

      return res;
    };

    final stream = ProcessStreamer.stream(args());

    try {
      // ignore: unused_local_variable
      await for (final result in stream) {}
    } on ProcessRunnerException catch (e) {
      final errList = e.result!.stderr.split('\n');
      _prettyPrintErrors(errList, step);

      rethrow;
    }
  }

  /// Executes ProGuard which is used to optimize and obfuscate the code.
  Future<void> execProGuard(String org, BuildStep step) async {
    final args = () {
      final proguardJar =
          File(p.join(_dataDir, 'tools', 'other', 'proguard.jar'));

      final devDeps = Directory(p.join(_cd, '.rush', 'dev-deps'));
      final deps = Directory(p.join(_cd, 'deps'));

      final libraryJars = _generateClasspath([devDeps, deps]);

      final classesDir =
          Directory(p.join(_dataDir, 'workspaces', org, 'classes'));

      final injar = File(p.join(classesDir.path, 'art.jar'));
      final outjar = File(p.join(classesDir.path, 'art_opt.jar'));

      final pgRules = File(p.join(_cd, 'src', 'proguard-rules.pro'));

      final res = <String>['java', '-jar', proguardJar.path];
      res
        ..addAll(['-injars', injar.path])
        ..addAll(['-outjars', outjar.path])
        ..addAll(['-libraryjars', libraryJars])
        ..add('@${pgRules.path}');

      return res;
    };

    final stream = ProcessStreamer.stream(args());

    try {
      // ignore: unused_local_variable
      await for (final result in stream) {}
    } on ProcessRunnerException catch (e) {
      final errList = e.result!.stderr.split('\n');
      _prettyPrintErrors(errList, step);

      rethrow;
    }
  }

  /// Executes Jetifier standalone in reverse mode. Returns true if de-jetification
  /// (androidx -> support lib) is required, otherwise false.
  Future<bool> execJetifier(String org, BuildStep step) async {
    final args = () {
      final rawOrgDir =
          Directory(p.join(_dataDir, 'workspaces', org, 'raw', 'x', org));
      final rawOrgDirSup =
          Directory(p.join(_dataDir, 'workspaces', org, 'raw', 'sup', org))
            ..createSync(recursive: true);

      CmdUtils.copyDir(rawOrgDir, rawOrgDirSup);

      final androidRuntimeSup =
          File(p.join(rawOrgDirSup.path, 'files', 'AndroidRuntime.jar'));

      final exe = p.join(_dataDir, 'tools', 'jetifier-standalone', 'bin',
          'jetifier-standalone' + (Platform.isWindows ? '.bat' : ''));

      final res = <String>[exe];
      res
        ..addAll(['-i', androidRuntimeSup.path])
        ..addAll(['-o', androidRuntimeSup.path])
        ..add('-r');

      return res;
    };

    final stream = ProcessStreamer.stream(args());

    var isDeJetNeeded = true;

    try {
      final pattern =
          RegExp(r'WARNING: \[Main\] No references were rewritten.');

      await for (final result in stream) {
        if (isDeJetNeeded) {
          isDeJetNeeded = !result.output.contains(pattern);
        }
      }
    } on ProcessRunnerException catch (e) {
      final errList = e.result!.stderr.split('\n');
      _prettyPrintErrors(errList, step);

      rethrow;
    }

    return isDeJetNeeded;
  }

  /// Analyzes [errList] and prints it accordingly to stdout/stderr in
  /// different colors.
  void _prettyPrintErrors(List<String> errList, BuildStep step) {
    final errPattern = RegExp(r'\s*error:?\s?', caseSensitive: false);
    final warnPattern = RegExp(r'\s*warning:?\s?', caseSensitive: false);
    final noteInfoPattern =
        RegExp(r'\s*(note|info):?\s?', caseSensitive: false);

    var previouslyItWas = 'err';

    for (final err in errList) {
      if (err.startsWith(errPattern)) {
        final msg = err.replaceFirst(errPattern, '').trim();
        previouslyItWas = 'err';

        step.logErr(msg, addSpace: true);
      } else if (err.startsWith(warnPattern)) {
        final msg = err.replaceFirst(warnPattern, '').trim();
        previouslyItWas = 'warn';

        step.logWarn(msg, addSpace: true);
      } else if (err.startsWith(noteInfoPattern)) {
        final msg = err.replaceFirst(noteInfoPattern, '').trim();
        previouslyItWas = 'note';

        step.log(
          msg,
          ConsoleColor.cyan,
          addSpace: true,
          prefix: 'NOTE',
          prefBG: ConsoleColor.cyan,
          prefFG: ConsoleColor.black,
        );
      } else {
        switch (previouslyItWas) {
          case 'err':
            final msg = err.replaceFirst(errPattern, '').trim();
            previouslyItWas = 'err';

            step.logErr(' ' * 4 + msg, addPrefix: false);
            break;

          case 'warn':
            final msg = err.replaceFirst(warnPattern, '').trim();
            previouslyItWas = 'warn';

            step.logWarn(' ' * 5 + msg, addPrefix: false);
            break;

          default:
            final msg = err.replaceFirst(noteInfoPattern, '').trim();
            previouslyItWas = 'note';

            step.log(
              ' ' * 5 + msg,
              ConsoleColor.cyan,
            );
            break;
        }
      }
    }
  }

  /// Returns a `;` or `:` separated string of dependencies.
  static String _generateClasspath(List<FileSystemEntity> entities,
      {List<String> exclude = const [''], Directory? classesDir}) {
    final jars = [];

    entities.forEach((entity) {
      if (entity is Directory) {
        entity
            .listSync(recursive: true)
            .whereType<File>()
            .where((el) =>
                p.extension(el.path) == '.jar' &&
                !exclude.contains(p.basename(el.path)))
            .forEach((el) {
          jars.add(p.relative(el.path));
        });
      } else if (entity is File) {
        jars.add(p.relative(entity.path));
      }
    });

    if (classesDir != null) {
      jars.add(classesDir.path);
    }

    return jars.join(_getSeparator());
  }

  /// Returns `;` if building on Windows, otherwise `:`.
  static String _getSeparator() {
    if (Platform.isWindows) {
      return ';';
    }
    return ':';
  }
}