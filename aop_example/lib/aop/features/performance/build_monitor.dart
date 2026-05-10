import 'dart:async';

import 'package:beike_aspectd/aspectd.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../runtime/aop_public_api.dart';
import '../common/aop_location_ext.dart';
import 'performance_event.dart';

/// 监控 [StatefulElement.performRebuild] 的耗时与帧内重建次数。
class BuildMonitor {
  BuildMonitor({required AopPublicApi routeApi}) : _routeApi = routeApi;

  final AopPublicApi _routeApi;

  // 帧内重建计数：element identity -> count
  Duration _lastFrameTimestamp = Duration.zero;
  final Map<int, int> _rebuildCounts = <int, int>{};

  // 帧内贡献者列表：project widget 且耗时 >1ms 或重建次数较多
  // FrameMonitor 在 paint 结束时调用 drainFrameContributors() 取走并附加到 FramePhaseEvent
  final List<String> _currentFrameContributors = <String>[];

  final StreamController<BuildEvent> _controller =
      StreamController<BuildEvent>.broadcast();

  /// 所有超阈值 / 异常重建事件的流。
  Stream<BuildEvent> get events => _controller.stream;

  /// 由 [FrameMonitor] 在 paint 结束时调用，返回本帧的 build 贡献者列表并清空。
  List<String> drainFrameContributors() {
    if (_currentFrameContributors.isEmpty) {
      return const <String>[];
    }
    final List<String> result = List<String>.from(_currentFrameContributors);
    _currentFrameContributors.clear();
    return result;
  }

  void onPerformRebuild(Element element, VoidCallback proceed) {
    // currentFrameTimeStamp 只在帧内（persistentCallbacks 阶段）有效，
    // _firstBuild / mount 发生在帧外，跳过帧边界检测避免 assert 崩溃。
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    final bool inFrame =
        phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.transientCallbacks;

    if (inFrame) {
      final Duration frameTs = SchedulerBinding.instance.currentFrameTimeStamp;
      if (frameTs != _lastFrameTimestamp) {
        _lastFrameTimestamp = frameTs;
        _rebuildCounts.clear();
        _currentFrameContributors.clear();
      }
    }

    final int id = identityHashCode(element);
    _rebuildCounts[id] = (_rebuildCounts[id] ?? 0) + 1;
    final int rebuildCount = _rebuildCounts[id]!;

    final Stopwatch sw = Stopwatch()..start();
    proceed();
    sw.stop();
    final int durationMicros = sw.elapsedMicroseconds;

    String? file;
    int? line;
    final Widget widget = element.widget;
    final AopLocation? loc = widget is AopHasCreationLocation
        ? (widget as AopHasCreationLocation).aopLocation
        : null;
    if (loc != null && loc.isProjectRoot()) {
      file = loc.file;
      line = loc.line;
    }

    // 追踪帧内贡献者（低阈值：>1ms 或多次重建），用于帧事件归因
    if (file != null && (durationMicros > 1000 || rebuildCount >= 3)) {
      _currentFrameContributors.add(
        '${widget.runtimeType}  ${_shortFile(file)}:$line  '
        '${_fmtMicros(durationMicros)} ×$rebuildCount',
      );
    }

    // 只上报：项目内 Widget 慢 build，或项目内 Widget 帧内重建次数 >= 5
    final bool isSlow =
        file != null && durationMicros >= BuildEvent.slowThresholdMicros;
    final bool isExcessiveRebuild = file != null && rebuildCount >= 5;
    if (!isSlow && !isExcessiveRebuild) {
      return;
    }

    final String? routeName = _routeApi.getTopPage()?.settings.name;

    final BuildEvent event = BuildEvent(
      widgetType: widget.runtimeType.toString(),
      durationMicros: durationMicros,
      rebuildCount: rebuildCount,
      file: file,
      line: line,
      routeName: routeName,
    );

    debugPrint(event.toString());
    _controller.add(event);
  }

  void dispose() {
    _controller.close();
  }

  static String _shortFile(String file) {
    final int idx = file.lastIndexOf('/');
    return idx >= 0 ? file.substring(idx + 1) : file;
  }

  static String _fmtMicros(int us) =>
      us >= 1000 ? '${(us / 1000).toStringAsFixed(1)}ms' : '${us}μs';
}
