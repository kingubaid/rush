import 'dart:io' show Directory, File, exit;

import 'package:archive/archive.dart';
import 'package:args/args.dart';
import 'package:dart_console/dart_console.dart' show ConsoleColor;
import 'package:hive/hive.dart';
import 'package:path/path.dart' as p;
import 'package:rush_cli/commands/build/hive_adapters/build_box.dart';
import 'package:rush_cli/models/rush_lock/rush_lock.dart';
import 'package:rush_cli/models/rush_yaml/rush_yaml.dart';
import 'package:rush_cli/utils/cmd_utils.dart';
import 'package:rush_cli/services/file_service.dart';
import 'package:rush_cli/templates/intellij_files.dart';
import 'package:rush_prompt/rush_prompt.dart';

class BuildUtils {
  /// Gets time difference between the given two `DateTime`s.
  static String getTimeDifference(DateTime timeOne, DateTime timeTwo) {
    final diff = timeTwo.difference(timeOne).inMilliseconds;

    final brightBlack = '\u001b[30;1m';
    final cyan = '\u001b[36m';
    final reset = '\u001b[0m';

    final seconds = diff ~/ 1000;
    final millis = diff % 1000;

    var res = '$brightBlack[$reset';
    res += cyan;
    if (seconds > 0) {
      res += '${seconds}s ';
    }
    res += '${millis}ms';
    res += '$brightBlack]$reset';

    return res;
  }

  /// Returns `true` if the current extension needs to be optimized.
  static bool needsOptimization(ArgResults args) {
    if (args['optimize'] as bool) {
      return true;
    }

    return false;
  }

  /// Prints "• Build Failed" to the console
  static void printFailMsg(DateTime startTime) {
    final timeDiff = BuildUtils.getTimeDifference(startTime, DateTime.now());
    final store = ErrWarnStore();

    final brightBlack = '\u001b[30;1m';
    final red = '\u001b[31m';
    final yellow = '\u001b[33m';
    final reset = '\u001b[0m';

    var errWarn = '$brightBlack[$reset';

    if (store.getErrors > 0) {
      errWarn += red;
      errWarn += store.getErrors > 1
          ? '${store.getErrors} errors'
          : '${store.getErrors} error';
      errWarn += reset;

      if (store.getWarnings > 0) {
        errWarn += '$brightBlack;$reset ';
      }
    }

    if (store.getWarnings > 0) {
      errWarn += yellow;
      errWarn += store.getWarnings > 1
          ? '${store.getWarnings} warnings'
          : '${store.getWarnings} warning';
      errWarn += reset;
    }

    errWarn = errWarn.length == 1 ? '' : '$errWarn$brightBlack]$reset';
    Logger.logCustom('Build failed $timeDiff $errWarn',
        prefix: '\n• ', prefixFG: ConsoleColor.red);
    exit(1);
  }

  /// Deletes the list of previously logged messages from build box.
  static Future<void> deletePreviouslyLoggedFromBuildBox() async {
    final buildBox = await Hive.openBox<BuildBox>('build');
    buildBox.updatePreviouslyLogged([]);
  }

  /// Checks whether the .idea/libraries/dev_deps.xml file defines the correct
  /// dev deps and updates it if required. This is required since Rush v1.2.2
  /// as this release centralized the dev deps directory for all the Rush projects.
  /// So, therefore, to not break IDE features for old projects, this file needs
  /// to point to the correct location of dev deps.
  static void updateDevDepsXml(String projectRoot, String dataDir) {
    final devDepsXmlFile = () {
      final file =
          File(p.join(projectRoot, '.idea', 'libraries', 'dev-deps.xml'));
      if (file.existsSync()) {
        return file;
      } else {
        return File(p.join(projectRoot, '.idea', 'libraries', 'dev_deps.xml'))
          ..createSync(recursive: true);
      }
    }();

    final devDepsXml = getDevDepsXml(dataDir);
    if (devDepsXmlFile.readAsStringSync() != devDepsXml) {
      CmdUtils.writeFile(devDepsXmlFile.path, devDepsXml);
    }
  }

  static List<String> getDepJarPaths(
    String projectRoot,
    RushYaml rushYaml,
    DepScope scope,
    RushLock? rushLock,
  ) {
    final allEntries = rushYaml.deps?.where((el) => el.scope() == scope);
    final localJars = allEntries
            ?.where((el) => !el.value().contains(':'))
            .map((el) => p.join(projectRoot, 'deps', el.value())) ??
        [];

    if (rushLock == null) {
      return localJars.toList();
    }

    final remoteJars = rushLock.resolvedArtifacts
        .where((el) => el.scope == scope.value())
        .map((el) {
      if (el.type == 'aar') {
        final outputDir = Directory(p.join(
            p.dirname(el.path), p.basenameWithoutExtension(el.path)))
          ..createSync(recursive: true);
        final classesJar = File(p.join(outputDir.path, 'classes.jar'));

        if (!classesJar.existsSync()) {
          unzip(el.path, outputDir.path);
        }
        return classesJar.path;
      }
      return el.path;
    });

    return [...localJars, ...remoteJars];
  }

  static String classpathStringForDeps(
    FileService fs,
    RushYaml rushYaml,
    RushLock? rushLock,
  ) {
    final depJars = [
      ...getDepJarPaths(fs.cwd, rushYaml, DepScope.implement, rushLock),
      ...getDepJarPaths(fs.cwd, rushYaml, DepScope.compileOnly, rushLock)
    ];

    final devDepsDir = Directory(p.join(fs.dataDir, 'dev-deps'));
    for (final el in devDepsDir.listSync(recursive: true)) {
      if (el is File) {
        depJars.add(el.path);
      }
    }

    return depJars.join(CmdUtils.cpSeparator());
  }

  static void unzip(String zipFilePath, String outputDirPath) {
    final archive =
        ZipDecoder().decodeBytes(File(zipFilePath).readAsBytesSync());

    for (final file in archive.files) {
      if (file.isFile) {
        final bytes = file.content as List<int>;
        try {
          File(p.join(outputDirPath, file.name))
            ..createSync(recursive: true)
            ..writeAsBytesSync(bytes);
        } catch (e) {
          Logger.log(LogType.erro, e.toString());
          exit(1);
        }
      }
    }
  }
}