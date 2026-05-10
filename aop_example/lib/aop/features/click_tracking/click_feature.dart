import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../runtime/aop_public_api.dart';
import 'click_path_builder.dart';

class ClickFeature {
  ClickFeature({required AopPublicApi routeApi})
    : _pathBuilder = ClickPathBuilder(routeApi: routeApi);

  final ClickPathBuilder _pathBuilder;
  final ClickStateTracker _stateTracker = ClickStateTracker();

  final ValueNotifier<String> clickInfo = ValueNotifier<String>('');

  void onHitTestTargetHandleEvent(
    HitTestTarget target,
    PointerEvent pointerEvent,
  ) {
    _stateTracker.recordHitTest(target, pointerEvent);
  }

  void onGestureRecognizerInvokeCallback(String eventName) {
    if (eventName != 'onTap') {
      return;
    }

    final HitTestInfo? hitTestInfo = _stateTracker.currentHitInfo;
    if (hitTestInfo == null) {
      return;
    }

    if (hitTestInfo.attached) {
      _emitClickInfo(hitTestInfo.renderObject);
      return;
    }

    final HitTestResult result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      hitTestInfo.pointerEvent.position,
      PlatformDispatcher.instance.implicitView!.viewId,
    );

    for (final HitTestEntry<HitTestTarget> entry in result.path) {
      final HitTestTarget target = entry.target;
      if (target is RenderObject && target.attached) {
        _emitClickInfo(target);
        break;
      }
    }
  }

  void _emitClickInfo(RenderObject renderObject) {
    final String? info = _pathBuilder.build(renderObject);
    if (info == null || info.isEmpty) {
      return;
    }

    clickInfo.value = info;
    debugPrint('Flutter点击路径: $info');
  }
}

class ClickStateTracker {
  int _currentPointer = -1;
  int _previousPointer = -1;
  final Map<int, HitTestInfo> _hitTestTargetMap = <int, HitTestInfo>{};

  void recordHitTest(HitTestTarget target, PointerEvent pointerEvent) {
    _currentPointer = pointerEvent.pointer;
    if (target is RenderObject) {
      if (_currentPointer > _previousPointer) {
        _hitTestTargetMap.clear();
      }
      _hitTestTargetMap.putIfAbsent(
        _currentPointer,
        () => HitTestInfo(target, pointerEvent),
      );
    }
    _previousPointer = _currentPointer;
  }

  HitTestInfo? get currentHitInfo => _hitTestTargetMap[_currentPointer];
}

class HitTestInfo {
  HitTestInfo(this.renderObject, this.pointerEvent);

  final RenderObject renderObject;
  final PointerEvent pointerEvent;

  bool get attached => renderObject.attached;
}
