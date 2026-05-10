/// 单次 Widget build 事件。
class BuildEvent {
  const BuildEvent({
    required this.widgetType,
    required this.durationMicros,
    required this.rebuildCount,
    this.file,
    this.line,
    this.routeName,
  });

  /// Widget 类型名，例如 `MyHomePage`。
  final String widgetType;

  /// build 耗时（微秒）。
  final int durationMicros;

  /// 当前帧内该 Element 已触发的重建次数（>=3 即为异常重建）。
  final int rebuildCount;

  /// 源文件路径（仅项目内 Widget 有值）。
  final String? file;

  /// 源文件行号。
  final int? line;

  /// 当前路由名。
  final String? routeName;

  bool get isSlowBuild => durationMicros >= BuildEvent.slowThresholdMicros;
  bool get isExcessiveRebuild => rebuildCount >= 5;

  /// 慢 build 阈值：8000 微秒（8ms）。半个 60Hz 帧预算，profile 模式下单 widget build 超过此值才算真实问题。
  static const int slowThresholdMicros = 8000;

  @override
  String toString() {
    final String duration = durationMicros >= 1000
        ? '${(durationMicros / 1000).toStringAsFixed(1)}ms'
        : '$durationMicros\u03bcs';
    final String location = file != null ? ' | ${_shortFile(file!)}:$line' : '';
    final String route = routeName != null ? ' | $routeName' : '';
    return '[BUILD] $widgetType | $duration | rebuild×$rebuildCount$location$route';
  }

  static String _shortFile(String file) {
    final int idx = file.lastIndexOf('/');
    return idx >= 0 ? file.substring(idx + 1) : file;
  }
}

/// 单帧耗时事件。
class FrameEvent {
  const FrameEvent({
    required this.frameSequence,
    required this.totalMicros,
    required this.buildMicros,
    required this.rasterMicros,
    required this.vsyncOverheadMicros,
    required this.droppedFrames60Hz,
    required this.isOver60HzBudget,
    required this.isOver120HzBudget,
    this.routeName,
  });

  /// 当前采样序号（运行期自增）。
  final int frameSequence;

  /// 帧总耗时（微秒）。
  final int totalMicros;

  /// build 阶段耗时（微秒）。
  final int buildMicros;

  /// raster 阶段耗时（微秒）。
  final int rasterMicros;

  /// vsync 等待 / 额外开销（微秒）。
  final int vsyncOverheadMicros;

  /// 以 60Hz 预算估算的掉帧数。
  final int droppedFrames60Hz;

  /// 是否超过 60Hz 帧预算（16.67ms）。
  final bool isOver60HzBudget;

  /// 是否超过 120Hz 帧预算（8.33ms）。
  final bool isOver120HzBudget;

  /// 当前路由名。
  final String? routeName;

  @override
  String toString() {
    final String total = _toMs(totalMicros);
    final String build = _toMs(buildMicros);
    final String raster = _toMs(rasterMicros);
    final String route = routeName != null ? ' | $routeName' : '';
    final String budgetTag = isOver60HzBudget
        ? 'over60'
        : (isOver120HzBudget ? 'over120' : 'ok');
    return '[FRAME] #$frameSequence | total:$total | build:$build | '
        'raster:$raster | dropped60:$droppedFrames60Hz | $budgetTag$route';
  }

  static String _toMs(int micros) {
    return '${(micros / 1000).toStringAsFixed(2)}ms';
  }
}

/// 单帧 build/layout/paint 分段事件。
class FramePhaseEvent {
  const FramePhaseEvent({
    required this.frameTimestampMicros,
    required this.buildScopeMicros,
    required this.layoutMicros,
    required this.paintMicros,
    required this.totalMicros,
    required this.isOver60HzBudget,
    required this.isOver120HzBudget,
    this.routeName,
    this.suspectWidgets = const <String>[],
  });

  final int frameTimestampMicros;
  final int buildScopeMicros;
  final int layoutMicros;
  final int paintMicros;
  final int totalMicros;
  final bool isOver60HzBudget;
  final bool isOver120HzBudget;
  final String? routeName;

  /// 本帧内 build 耗时较高的项目内 Widget 列表（格式：WidgetType  file:line  Xms ×N）。
  final List<String> suspectWidgets;

  @override
  String toString() {
    final String route = routeName != null ? ' | $routeName' : '';
    final String budgetTag = isOver60HzBudget
        ? 'over60'
        : (isOver120HzBudget ? 'over120' : 'ok');
    final String suspects = suspectWidgets.isNotEmpty
        ? '\n  suspects: ${suspectWidgets.join(' / ')}'
        : '';
    return '[PHASE] build:${_toMs(buildScopeMicros)} | '
        'layout:${_toMs(layoutMicros)} | '
        'paint:${_toMs(paintMicros)} | '
        'total:${_toMs(totalMicros)} | $budgetTag$route$suspects';
  }

  static String _toMs(int micros) {
    return '${(micros / 1000).toStringAsFixed(2)}ms';
  }
}

enum ImageEventType { cacheHit, cacheMiss, decode }

/// 图片缓存与解码事件。
class ImageEvent {
  const ImageEvent({
    required this.type,
    required this.durationMicros,
    required this.isSlow,
    this.key,
    this.codecApi,
    this.routeName,
    this.error,
  });

  static const int slowCacheLookupMicros = 3000;
  static const int slowDecodeMicros = 4000;

  final ImageEventType type;
  final int durationMicros;
  final bool isSlow;
  final Object? key;
  final String? codecApi;
  final String? routeName;
  final Object? error;

  @override
  String toString() {
    final String route = routeName != null ? ' | $routeName' : '';
    final String keyPart = key != null ? ' | key:$key' : '';
    final String apiPart = codecApi != null ? ' | api:$codecApi' : '';
    final String errorPart = error != null ? ' | error:$error' : '';
    final String slowTag = isSlow ? 'slow' : 'ok';
    return '[IMAGE] $type | ${_toMs(durationMicros)} | $slowTag'
        '$keyPart$apiPart$route$errorPart';
  }

  static String _toMs(int micros) {
    return '${(micros / 1000).toStringAsFixed(2)}ms';
  }
}
