import 'package:path/path.dart' as path;

const String _vmEntryPoint = 'vm:entry-point';

/// Interface for classes that track the source code location the their
/// constructor was called from.
///
/// {@macro flutter.widgets.WidgetInspectorService.getChildrenSummaryTree}
/// 为每一个widget 包一层 _CustomHasCreationLocation，方便获取文件位置 参考 官方的 Flutter Inspector
@pragma(_vmEntryPoint)
abstract class AopHasCreationLocation {
  AopLocation get aopLocation;
}

/// inner\transformer\plugins\aop\location\track_widget_constructor_locations.dart
/// ConstructorInvocation _constructLocation(
/// 164 行，参数来源
@pragma(_vmEntryPoint)
class AopLocation {
  const AopLocation({
    required this.file,
    required this.line,
    required this.column,
    this.name,
    this.ownerImportUri,
  });

  final String file;
  final int line;
  final int column;
  final String? name;

  /// 额外新增参数用来判断是否为 Flutter SDK 里的文件
  final String? ownerImportUri;

  bool isFlutterSdk() {
    if (ownerImportUri != null &&
        ownerImportUri!.startsWith('package:flutter/')) {
      return true;
    }
    if (file.contains(path.join('packages', 'flutter'))) {
      return true;
    }
    return false;
  }

  @override
  String toString() {
    return 'AopLocation{file: $file, line: $line, column: $column, name: $name, ownerImportUri: $ownerImportUri}';
  }
}
