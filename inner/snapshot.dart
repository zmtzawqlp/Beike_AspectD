import 'dart:io';

Future<bool> _runSnapshotStep(
  String dartPath,
  String startMessage,
  String successMessage,
  String failMessage,
  List<String> command,
) async {
  print(startMessage);
  final Process process = await Process.start(dartPath, command);
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

void main(List<String> args) async {
  final String dartPath = Platform.executable;

  await _runSnapshotStep(
    dartPath,
    'Start generating starter.snapshot...',
    'Generated starter.snapshot successfully!',
    'Failed to generate starter.snapshot!',
    <String>[
      '--snapshot=../lib/bin/starter.snapshot',
      'tool/starter.dart',
    ],
  );
  
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
  // );

  await _runSnapshotStep(
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
  );
}
