import 'dart:async';
import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../runtime/aop_public_api.dart';
import 'performance_event.dart';

/// 监控每帧耗时并产出掉帧事件。
class FrameMonitor {
  FrameMonitor({
    required AopPublicApi routeApi,
    /// 在 paint 结束时调用，返回本帧内 build 贡献者列表（由 BuildMonitor 提供）。
    List<String> Function()? widgetDrainer,
  })  : _routeApi = routeApi,
        _widgetDrainer = widgetDrainer;

  static const double _frameBudget60HzMs = 1000.0 / 60.0;

  final AopPublicApi _routeApi;
  final List<String> Function()? _widgetDrainer;
  final StreamController<FrameEvent> _controller =
      StreamController<FrameEvent>.broadcast();
  final StreamController<FramePhaseEvent> _phaseController =
      StreamController<FramePhaseEvent>.broadcast();

  final Map<int, _FramePhaseBucket> _phaseBuckets = <int, _FramePhaseBucket>{};

  int _frameSequence = 0;
  bool _started = false;

  Stream<FrameEvent> get events => _controller.stream;
  Stream<FramePhaseEvent> get phaseEvents => _phaseController.stream;

  void start() {
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final FrameTiming timing in timings) {
      _frameSequence += 1;

      final int totalMicros = timing.totalSpan.inMicroseconds;
      final int buildMicros = timing.buildDuration.inMicroseconds;
      final int rasterMicros = timing.rasterDuration.inMicroseconds;
      final int vsyncOverheadMicros = timing.vsyncOverhead.inMicroseconds;

      // isOver60HzBudget：>33ms，真实掉至少一帧（用户可感知卡顿）。
      // isOver120HzBudget：>16.67ms，超出 60Hz 预算但未必可见（偶发性波动）。
      final bool isOver60HzBudget = totalMicros > 33333;
      final bool isOver120HzBudget = totalMicros > 16667;

      if (!isOver60HzBudget && !isOver120HzBudget) {
        continue;
      }

      final double ratio = totalMicros / (_frameBudget60HzMs * 1000.0);
      final int droppedFrames60Hz = ratio.floor() > 0 ? ratio.floor() - 1 : 0;

      final FrameEvent event = FrameEvent(
        frameSequence: _frameSequence,
        totalMicros: totalMicros,
        buildMicros: buildMicros,
        rasterMicros: rasterMicros,
        vsyncOverheadMicros: vsyncOverheadMicros,
        droppedFrames60Hz: droppedFrames60Hz,
        isOver60HzBudget: isOver60HzBudget,
        isOver120HzBudget: isOver120HzBudget,
        routeName: _routeApi.getTopPage()?.settings.name,
      );

      debugPrint(event.toString());
      _controller.add(event);
    }
  }

  void onBuildScope(VoidCallback proceed) {
    _measurePhase(_PhaseKind.buildScope, proceed);
  }

  void onFlushLayout(VoidCallback proceed) {
    _measurePhase(_PhaseKind.layout, proceed);
  }

  void onFlushPaint(VoidCallback proceed) {
    _measurePhase(_PhaseKind.paint, proceed);
  }

  void _measurePhase(_PhaseKind kind, VoidCallback proceed) {
    final int? frameKey = _getCurrentFrameKeyMicros();
    if (frameKey == null) {
      proceed();
      return;
    }

    final Stopwatch stopwatch = Stopwatch()..start();
    proceed();
    stopwatch.stop();

    final _FramePhaseBucket bucket = _phaseBuckets.putIfAbsent(
      frameKey,
      _FramePhaseBucket.new,
    );
    final int elapsedMicros = stopwatch.elapsedMicroseconds;

    switch (kind) {
      case _PhaseKind.buildScope:
        bucket.buildScopeMicros += elapsedMicros;
        break;
      case _PhaseKind.layout:
        bucket.layoutMicros += elapsedMicros;
        break;
      case _PhaseKind.paint:
        bucket.paintMicros += elapsedMicros;
        _emitPhaseEvent(frameKey, bucket);
        _phaseBuckets.remove(frameKey);
        break;
    }
  }

  int? _getCurrentFrameKeyMicros() {
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    final bool inFrame =
        phase != SchedulerPhase.idle &&
        phase != SchedulerPhase.transientCallbacks;
    if (!inFrame) {
      return null;
    }
    return SchedulerBinding.instance.currentFrameTimeStamp.inMicroseconds;
  }

  void _emitPhaseEvent(int frameKey, _FramePhaseBucket bucket) {
    final int totalMicros =
        bucket.buildScopeMicros + bucket.layoutMicros + bucket.paintMicros;
    // UI 线程侧（build+layout+paint）：>20ms 为严重问题，>12ms 为轻微超预算。
    final bool isOver60HzBudget = totalMicros > 20000;
    final bool isOver120HzBudget = totalMicros > 12000;

    if (!isOver60HzBudget && !isOver120HzBudget) {
      return;
    }

    final List<String> suspects = _widgetDrainer?.call() ?? const <String>[];

    final FramePhaseEvent event = FramePhaseEvent(
      frameTimestampMicros: frameKey,
      buildScopeMicros: bucket.buildScopeMicros,
      layoutMicros: bucket.layoutMicros,
      paintMicros: bucket.paintMicros,
      totalMicros: totalMicros,
      isOver60HzBudget: isOver60HzBudget,
      isOver120HzBudget: isOver120HzBudget,
      routeName: _routeApi.getTopPage()?.settings.name,
      suspectWidgets: suspects,
    );

    debugPrint(event.toString());
    _phaseController.add(event);
  }

  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeTimingsCallback(_onTimings);
      _started = false;
    }
    _controller.close();
    _phaseController.close();
  }
}

class _FramePhaseBucket {
  int buildScopeMicros = 0;
  int layoutMicros = 0;
  int paintMicros = 0;
}

enum _PhaseKind { buildScope, layout, paint }
