import 'dart:async';

import '../features/performance/performance_event.dart';

/// 对外暴露的性能监控 API。
abstract class AopPerformanceApi {
  /// Widget build 异常事件流（慢 build 或帧内多次重建）。
  Stream<BuildEvent> get buildEvents;

  /// 帧耗时异常事件流（超过 60Hz 或 120Hz 帧预算）。
  Stream<FrameEvent> get frameEvents;

  /// 帧内 build/layout/paint 分段异常事件流。
  Stream<FramePhaseEvent> get framePhaseEvents;

  /// 图片缓存与解码异常事件流。
  Stream<ImageEvent> get imageEvents;
}
