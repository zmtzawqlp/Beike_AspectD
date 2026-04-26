import 'dart:io';

Future<bool> _runSnapshotStep(
  String dartPath,
  String startMessage,
  String successMessage,
  String failMessage,
  List<String> command,
  String workingDirectory,
) async {
  print(startMessage);
  final Process process = await Process.start(
    dartPath,
    command,
    workingDirectory: workingDirectory,
  );
  final Future<void> out = stdout.addStream(process.stdout);
  final Future<void> err = stderr.addStream(process.stderr);
  final int exitCode = await process.exitCode;
  await Future.wait(<Future<void>>[out, err]);
  if (exitCode == 0) {
    print(successMessage);
    return true;
  }
  print(failMessage);
  return false;
}

Future<int> runSnapshot(List<String> args) async {
  final Directory? repoRoot = _resolveRepoRoot(args);
  if (repoRoot == null) {
    print('Cannot resolve repository root.');
    print('Pass a root path by: snapshot.dart --root <repoRoot>');
    print('Or as first positional arg: snapshot.dart <repoRoot>');
    return 2;
  }

  final String sep = Platform.pathSeparator;
  final Directory innerDir = Directory('${repoRoot.path}${sep}inner');
  if (!innerDir.existsSync()) {
    print('inner directory not found: ${innerDir.path}');
    return 3;
  }

  final String dartPath = Platform.resolvedExecutable;

  final bool starterOk = await _runSnapshotStep(
    dartPath,
    'Start generating starter.snapshot...',
    'Generated starter.snapshot successfully!',
    'Failed to generate starter.snapshot!',
    <String>[
      '--snapshot=../lib/bin/starter.snapshot',
      'tool/starter.dart',
    ],
    innerDir.path,
  );
  if (!starterOk) {
    return 1;
  }
  
  // flutter use frontend_server_aot.dart.snapshot now
  // await _runSnapshotStep(
  //   dartPath,
  //   'Start generating frontend_server.dart.snapshot...',
  //   'Generated frontend_server.dart.snapshot successfully!',
  //   'Failed to generate frontend_server.dart.snapshot!',
  //   <String>[
  //     '--deterministic',
  //     '--snapshot=flutter_frontend_server/frontend_server.dart.snapshot',
  //     'flutter_frontend_server/starter.dart',
  //   ],
  //   innerDir.path,
  // );

  final bool aotOk = await _runSnapshotStep(
    dartPath,
    'Start generating frontend_server_aot.dart.snapshot...',
    'Generated frontend_server_aot.dart.snapshot successfully!',
    'Failed to generate frontend_server_aot.dart.snapshot!',
    <String>[
      'compile',
      'aot-snapshot',
      'flutter_frontend_server/starter.dart',
      '-o',
      'flutter_frontend_server/frontend_server_aot.dart.snapshot',
    ],
    innerDir.path,
  );

  return aotOk ? 0 : 1;
}

Future<void> main(List<String> args) async {
  exitCode = await runSnapshot(args);
}

Directory? _resolveRepoRoot(List<String> args) {
  final String? configuredPath = _readRootPathArg(args);
  if (configuredPath != null) {
    final Directory? resolved = _resolveFromCandidate(Directory(configuredPath));
    if (resolved != null) {
      return resolved;
    }
  }

  final List<Directory> starts = <Directory>[
    Directory.current,
    File.fromUri(Platform.script).parent,
  ];

  for (final Directory start in starts) {
    Directory current = start;
    for (int i = 0; i < 8; i++) {
      if (_isRepoRoot(current)) {
        return current;
      }
      final Directory parent = current.parent;
      if (parent.path == current.path) {
        break;
      }
      current = parent;
    }
  }

  return null;
}

Directory? _resolveFromCandidate(Directory candidate) {
  if (_isRepoRoot(candidate)) {
    return candidate;
  }

  final String sep = Platform.pathSeparator;
  final File innerStarter =
      File('${candidate.path}${sep}tool${sep}starter.dart');
  if (innerStarter.existsSync() && _isRepoRoot(candidate.parent)) {
    return candidate.parent;
  }

  return null;
}

bool _isRepoRoot(Directory dir) {
  final String sep = Platform.pathSeparator;
  final File pubspec = File('${dir.path}${sep}pubspec.yaml');
  final File innerSnapshot = File('${dir.path}${sep}inner${sep}snapshot.dart');
  return pubspec.existsSync() && innerSnapshot.existsSync();
}

String? _readRootPathArg(List<String> args) {
  for (int i = 0; i < args.length; i++) {
    final String arg = args[i];
    if (arg.startsWith('--root=')) {
      return arg.substring('--root='.length).trim();
    }
    if (arg == '--root' && i + 1 < args.length) {
      return args[i + 1].trim();
    }
    if (!arg.startsWith('--')) {
      return arg.trim();
    }
  }
  return null;
}
