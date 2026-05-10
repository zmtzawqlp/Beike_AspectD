// ignore_for_file: non_constant_identifier_names, unintended_html_in_doc_comment

import 'package:beike_aspectd/aspectd.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../runtime/aop_runtime.dart';

const String _vmEntryPoint = 'vm:entry-point';

@Aspect()
@pragma(_vmEntryPoint)
/// 点击切面
class ClickAspect {
  @pragma(_vmEntryPoint)
  ClickAspect();

  @Call(
    'package:flutter/src/gestures/hit_test.dart',
    'HitTestTarget',
    '-handleEvent',
  )
  @pragma(_vmEntryPoint)
  /// [HitTestTarget]
  /// void handleEvent(PointerEvent event, HitTestEntry<HitTestTarget> entry);
  void HitTestTarget_handleEvent(PointCut pointCut) {
    pointCut.proceed();
    final Object? hitTestEntry = pointCut.target;
    final PointerEvent pointerEvent =
        pointCut.positionalParams![0] as PointerEvent;
    if (hitTestEntry is RenderObject) {
      AopRuntime.instance.onHitTestTargetHandleEvent(
        hitTestEntry,
        pointerEvent,
      );
    }
  }

  @Execute(
    'package:flutter/src/gestures/recognizer.dart',
    'GestureRecognizer',
    '-invokeCallback',
  )
  @pragma(_vmEntryPoint)
  /// [GestureRecognizer]
  ///   T? invokeCallback<T>(String name, RecognizerCallback<T> callback, { String Function()? debugReport }) {
  dynamic GestureRecognizer_invokeCallback(PointCut pointCut) {
    final dynamic eventName = pointCut.positionalParams![0];
    AopRuntime.instance.onGestureRecognizerInvokeCallback(eventName.toString());
    return pointCut.proceed();
  }

  @Execute(
    'package:flutter/src/widgets/framework.dart',
    'RenderObjectElement',
    '-mount',
  )
  /// [RenderObjectElement]
  ///   void mount(Element? parent, Object? newSlot) {
  @pragma(_vmEntryPoint)
  void RenderObjectElement_mount(PointCut pointCut) {
    pointCut.proceed();
    final Element? element = pointCut.target as Element?;
    // release 和 profile 模式创建这个属性
    if (element != null && (kReleaseMode || kProfileMode)) {
      element.renderObject?.debugCreator = DebugCreator(element);
    }
  }

  @Execute(
    'package:flutter/src/widgets/framework.dart',
    'RenderObjectElement',
    '-update',
  )
  @pragma(_vmEntryPoint)
  /// [RenderObjectElement]
  ///   void update(covariant RenderObjectWidget newWidget) {
  void RenderObjectElement_update(PointCut pointCut) {
    pointCut.proceed();
    final Element? element = pointCut.target as Element?;
    // release 和 profile 模式创建这个属性
    if (element != null && (kReleaseMode || kProfileMode)) {
      element.renderObject?.debugCreator = DebugCreator(element);
    }
  }
}
