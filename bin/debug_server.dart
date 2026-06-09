// debug_server.dart
//
// AOP frontend_server 源码级调试入口。
//
// ═══════════════════════════════════════════════════════════════════
//  如何在 VS Code 中调试（推荐方式）
// ═══════════════════════════════════════════════════════════════════
// 1. 打开「运行和调试」面板（Ctrl+Shift+D）。
// 2. 在下拉框中选择「Debug debug_server.dart (inner packages)」。
// 3. 按 F5 启动。可在 inner/flutter_frontend_server/ 任意位置设置断点。
//
// .vscode/launch.json 中的启动配置会通过 vmAdditionalArgs 传入：
//   --packages=inner/.dart_tool/package_config.json
// 这是必须的 —— 没有此参数，Dart VM 无法解析
// package:frontend_server / package:kernel / package:vm
// （这些包位于 inner/pkg/，并不在根目录的 pubspec.yaml 中声明）。
//
// ⚠️  请勿直接点击编辑器的「Run」按钮，也不要执行
// "dart bin/debug_server.dart"，那样会使用错误的 package_config，
// 立刻报错：Not found: 'package:frontend_server'
//
// ═══════════════════════════════════════════════════════════════════
//  两种运行模式
// ═══════════════════════════════════════════════════════════════════
// • 自动发现模式（不传参数）：脚本自动推断所有参数。
//     - Flutter SDK 根目录  从 example/.dart_tool/package_config.json 读取
//     - 构建 hash 目录       取 example/.dart_tool/flutter_build/ 下最新目录
//     - 版本 -D 标志         通过 `flutter --version --machine` 动态获取
//     - 自动删除旧的 app.dill，让 AOP transformer 对全新 kernel 执行
//       （@Aspect() 注解在首次 transform 后会被删除；
//        复用旧 dill 会导致 aopItemInfoList 为空）。
//
// • 手动透传模式（传入参数）：将参数直接转发给 server.starter。
//   适合从 flutter_tools 日志中复制「Debug frontend_server start args:」
//   那一行，去掉开头的 snapshot 路径后，作为 Program arguments 粘贴。

// ignore_for_file: unintended_html_in_doc_comment

import 'dart:convert';
import 'dart:io';

import '../inner/flutter_frontend_server/server.dart' as server;

// 修改这里即可切换要调试的 demo 工程目录（例如: example、aop_exmaple）。
 
Future<void> main(List<String> args) async {
  
  final targetDemoDir = args.first;

  // --- 自动发现模式 ---

  final scriptFile = File.fromUri(Platform.script);
  final repoRoot = _resolveRepoRoot(scriptFile.parent);
  if (repoRoot == null) {
    stderr.writeln('ERROR: Cannot resolve repository root from script path.');
    stderr.writeln('       Script: ${scriptFile.path}');
    exitCode = 1;
    return;
  }

  final sep = Platform.pathSeparator;
  final exampleDir = Directory('${repoRoot.path}$sep$targetDemoDir');
  if (!exampleDir.existsSync()) {
    stderr.writeln(
      'ERROR: $targetDemoDir/ directory not found at: ${exampleDir.path}',
    );
    exitCode = 2;
    return;
  }

  // 1. 从 package_config.json 获取 Flutter SDK 根目录
  final flutterRoot = _findFlutterRoot(exampleDir);
  if (flutterRoot == null) {
    stderr.writeln('ERROR: Cannot determine Flutter SDK root.');
    stderr.writeln('       Run `flutter pub get` inside $targetDemoDir/ first.');
    exitCode = 3;
    return;
  }

  // 2. 获取最新的 flutter_build hash 目录
  final buildHashDir = _findLatestBuildHashDir(exampleDir);
  if (buildHashDir == null) {
    stderr.writeln('ERROR: No flutter_build hash directory found.');
    stderr.writeln('       Run a build first:');
    stderr.writeln('         cd $targetDemoDir && flutter build apk --debug');
    exitCode = 4;
    return;
  }

    // 3. 查找上一次构建写入的 depfile（优先使用 Flutter debug 模式对应的文件）。
    final depfilePath =
      _findDepfile(buildHashDir) ??
      '${buildHashDir.path}${sep}kernel_snapshot_program.d';

  final sdkRoot =
      '$flutterRoot${sep}bin${sep}cache${sep}artifacts${sep}engine'
      '${sep}common${sep}flutter_patched_sdk$sep';
  final packageConfig =
      '${exampleDir.path}$sep.dart_tool${sep}package_config.json';
  final outputDill = '${buildHashDir.path}${sep}app.dill';

  // 删除旧的 dill，让 server 执行完整的全量编译。
  // 上一次 `flutter run` 产生的 dill 已被 AOP transformer 删除了所有
  // @Aspect() 注解，通过 --initialize-from-dill 加载会导致 aopItemInfoList 为空。
  final File outputDillFile = File(outputDill);
  if (outputDillFile.existsSync()) {
    outputDillFile.deleteSync();
    stdout.writeln('Deleted stale app.dill to force full AOP recompile.');
  }

  // 从本地 Flutter SDK 动态读取构建版本 -D 定义。
  final flutterInfo = await _readFlutterVersionInfo(flutterRoot);
  final flutterVersion = flutterInfo['frameworkVersion'] ?? '';
  final flutterChannel = flutterInfo['channel'] ?? '';
  final flutterGitUrl = flutterInfo['repositoryUrl'] ?? '';
  final flutterFrameworkRevision = flutterInfo['frameworkRevision'] ?? '';
  final flutterEngineRevision = flutterInfo['engineRevision'] ?? '';
  final flutterDartVersion = _normalizeDartVersion(flutterInfo['dartSdkVersion'] ?? '');

  final builtArgs = <String>[
    '--sdk-root', sdkRoot,
    '--target=flutter',
    '--no-print-incremental-dependencies',
    '-DFLUTTER_VERSION=$flutterVersion',
    '-DFLUTTER_CHANNEL=$flutterChannel',
    '-DFLUTTER_GIT_URL=$flutterGitUrl',
    '-DFLUTTER_FRAMEWORK_REVISION=$flutterFrameworkRevision',
    '-DFLUTTER_ENGINE_REVISION=$flutterEngineRevision',
    '-DFLUTTER_DART_VERSION=$flutterDartVersion',
    '-DFLUTTER_APP_FLAVOR=',
    '-Ddart.vm.profile=false',
    '-Ddart.vm.product=false',
    '--enable-asserts',
    '--track-widget-creation',
    '--no-link-platform',
    '--packages', packageConfig,
    '--output-dill', outputDill,
    '--depfile', depfilePath,
    '--incremental',
    '--aop', '1',
    '--verbosity=error',
    'package:$targetDemoDir/main.dart',
  ];

  stdout.writeln('Flutter root  : $flutterRoot');
  stdout.writeln('Build hash dir: ${buildHashDir.path}');
  stdout.writeln('Depfile       : $depfilePath');
  stdout.writeln('');
  stdout.writeln('frontend_server args:');
  stdout.writeln('  ${builtArgs.join(' ')}');
  stdout.writeln('');

  exitCode = await server.starter(builtArgs);
}

Future<Map<String, String>> _readFlutterVersionInfo(String flutterRoot) async {
  final String sep = Platform.pathSeparator;
  final String flutterToolPath = Platform.isWindows
      ? '$flutterRoot${sep}bin${sep}flutter.bat'
      : '$flutterRoot${sep}bin${sep}flutter';

  final File flutterTool = File(flutterToolPath);
  if (!flutterTool.existsSync()) {
    return <String, String>{};
  }

  try {
    final ProcessResult result = await Process.run(
      flutterToolPath,
      <String>['--version', '--machine'],
    );
    if (result.exitCode != 0) {
      return <String, String>{};
    }

    final String output = (result.stdout as String).trim();
    if (output.isEmpty) {
      return <String, String>{};
    }

    final Object decoded = jsonDecode(output);
    if (decoded is! Map<String, dynamic>) {
      return <String, String>{};
    }

    String readString(String key) {
      final Object? value = decoded[key];
      return value is String ? value : '';
    }

    return <String, String>{
      'frameworkVersion': readString('frameworkVersion'),
      'channel': readString('channel'),
      'repositoryUrl': readString('repositoryUrl'),
      'frameworkRevision': readString('frameworkRevision'),
      'engineRevision': readString('engineRevision'),
      'dartSdkVersion': readString('dartSdkVersion'),
    };
  } catch (_) {
    return <String, String>{};
  }
}

String _normalizeDartVersion(String raw) {
  if (raw.isEmpty) {
    return '';
  }
  return raw.split(' ').first;
}

// ---------------------------------------------------------------------------
// 辅助函数
// ---------------------------------------------------------------------------

/// 从 [scriptDir] 向上遍历，找到同时包含 pubspec.yaml 和
/// inner/flutter_frontend_server/ 的目录，即仓库根目录。
Directory? _resolveRepoRoot(Directory scriptDir) {
  var current = scriptDir;
  for (var i = 0; i < 6; i++) {
    final pubspec = File(
        '${current.path}${Platform.pathSeparator}pubspec.yaml');
    final frontendServer = Directory(
        '${current.path}${Platform.pathSeparator}inner'
        '${Platform.pathSeparator}flutter_frontend_server');
    if (pubspec.existsSync() && frontendServer.existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) break;
    current = parent;
  }
  return null;
}

/// 解析 <targetDemoDir>/.dart_tool/package_config.json，找到 'flutter' 包条目，
/// 并从其 rootUri 推导出 Flutter SDK 根目录。
String? _findFlutterRoot(Directory exampleDir) {
  final packageConfigFile = File(
      '${exampleDir.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}package_config.json');
  if (!packageConfigFile.existsSync()) return null;

  try {
    final json =
        jsonDecode(packageConfigFile.readAsStringSync()) as Map<String, dynamic>;
    final packages = json['packages'] as List<dynamic>;
    for (final pkg in packages) {
      final map = pkg as Map<String, dynamic>;
      if (map['name'] == 'flutter') {
        final rootUri = map['rootUri'] as String;
        // rootUri 形如 "file:///D:/Flutter/.../flutter/packages/flutter"
        // SDK 根目录在两级之上：.../packages/flutter -> SDK 根目录
        final flutterPkgDir =
            Directory.fromUri(Uri.parse(rootUri));
        return flutterPkgDir.parent.parent.path;
      }
    }
  } catch (_) {
    // 解析失败，返回 null。
  }
  return null;
}

/// 返回 <targetDemoDir>/.dart_tool/flutter_build/ 下修改时间最新的 hash 目录。
Directory? _findLatestBuildHashDir(Directory exampleDir) {
  final flutterBuildDir = Directory(
      '${exampleDir.path}${Platform.pathSeparator}.dart_tool'
      '${Platform.pathSeparator}flutter_build');
  if (!flutterBuildDir.existsSync()) return null;

  final dirs = flutterBuildDir
      .listSync(followLinks: false)
      .whereType<Directory>()
      .toList();
  if (dirs.isEmpty) return null;

  dirs.sort((a, b) =>
      b.statSync().modified.compareTo(a.statSync().modified));
  return dirs.first;
}

/// 在 [hashDir] 中查找上一次构建写入的第一个 *.d depfile。
String? _findDepfile(Directory hashDir) {
  for (final entity in hashDir.listSync(followLinks: false)) {
    if (entity is File && entity.path.endsWith('.d')) {
      return entity.path;
    }
  }
  return null;
}
