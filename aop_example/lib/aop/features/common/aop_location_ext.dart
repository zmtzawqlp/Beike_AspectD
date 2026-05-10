import 'package:beike_aspectd/aspectd.dart';

extension AopLocationE on AopLocation {
  static const String _packageName = 'aop_example';

  /// 简单判断是否是项目根目录下的文件。
  bool isProjectRoot() {
    if (isFlutterSdk()) {
      return false;
    }

    if (ownerImportUri != null && ownerImportUri!.isNotEmpty) {
      return ownerImportUri!.startsWith('package:$_packageName/');
    }

    final String normalized = file.replaceAll('\\', '/');

    if (normalized.contains('/.pub-cache/') ||
        normalized.contains('/pub-cache/')) {
      return false;
    }

    if (normalized.startsWith('package:')) {
      return normalized.startsWith('package:$_packageName/');
    }

    if (normalized.contains('/$_packageName/lib/')) {
      return true;
    }

    return false;
  }
}
