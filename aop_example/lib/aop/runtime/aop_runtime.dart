import 'package:aop_example/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../features/click_tracking/click_feature.dart';
import '../features/performance/build_monitor.dart';
import '../features/performance/frame_monitor.dart';
import '../features/performance/image_monitor.dart';
import '../features/performance/performance_event.dart';
import '../features/route_tracking/route_feature.dart';
import 'aop_performance_api.dart';
import 'aop_public_api.dart';
import 'app_route_observer.dart';

/// Shared AOP runtime singleton that composes individual feature modules.
class AopRuntime implements AopPublicApi, AopPerformanceApi {
  AopRuntime._() {
    _frameMonitor.start();
  }

  static final AopRuntime instance = AopRuntime._();

  final RouteFeature _routeFeature = RouteFeature();
  late final ClickFeature _clickFeature = ClickFeature(routeApi: _routeFeature);
  late final BuildMonitor _buildMonitor = BuildMonitor(routeApi: _routeFeature);
  late final FrameMonitor _frameMonitor = FrameMonitor(
    routeApi: _routeFeature,
    widgetDrainer: _buildMonitor.drainFrameContributors,
  );
  late final ImageMonitor _imageMonitor = ImageMonitor(routeApi: _routeFeature);
  late final AppRouteObserver routeObserver = AppRouteObserver(
    routeFeature: _routeFeature,
  );

  ValueNotifier<String> get clickInfo => _clickFeature.clickInfo;

  @override
  Stream<BuildEvent> get buildEvents => _buildMonitor.events;

  @override
  Stream<FrameEvent> get frameEvents => _frameMonitor.events;

  @override
  Stream<FramePhaseEvent> get framePhaseEvents => _frameMonitor.phaseEvents;

  @override
  Stream<ImageEvent> get imageEvents => _imageMonitor.events;

  void onPerformRebuild(Element element, VoidCallback proceed) {
    _buildMonitor.onPerformRebuild(element, proceed);
  }

  void onBuildOwnerBuildScope(VoidCallback proceed) {
    _frameMonitor.onBuildScope(proceed);
  }

  void onPipelineOwnerFlushLayout(VoidCallback proceed) {
    _frameMonitor.onFlushLayout(proceed);
  }

  void onPipelineOwnerFlushPaint(VoidCallback proceed) {
    _frameMonitor.onFlushPaint(proceed);
  }

  T onImageCachePutIfAbsent<T>({
    required Object? key,
    required bool Function() cacheMissGetter,
    required T Function() proceed,
  }) {
    return _imageMonitor.onImageCachePutIfAbsent(
      key: key,
      cacheMissGetter: cacheMissGetter,
      proceed: proceed,
    );
  }

  Future<T> onInstantiateImageCodec<T>({
    required String apiName,
    required Object? source,
    required Future<T> Function() proceed,
  }) {
    return _imageMonitor.onInstantiateImageCodec(
      apiName: apiName,
      source: source,
      proceed: proceed,
    );
  }

  void onHitTestTargetHandleEvent(
    HitTestTarget target,
    PointerEvent pointerEvent,
  ) {
    _clickFeature.onHitTestTargetHandleEvent(target, pointerEvent);
  }

  void onGestureRecognizerInvokeCallback(String eventName) {
    _clickFeature.onGestureRecognizerInvokeCallback(eventName);
  }

  void onRouteEntryHandleAdd(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    _routeFeature.onRouteEntryHandleAdd(route, previousRoute);
  }

  void onRouteEntryHandlePop(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    _routeFeature.onRouteEntryHandlePop(route, previousRoute);
  }

  @override
  bool isCurrentRouteWidget(Widget widget) {
    return _routeFeature.isCurrentRouteWidget(widget);
  }

  @override
  Route<dynamic>? getCurrentRoute() {
    return _routeFeature.getCurrentRoute();
  }

  @override
  PageRoute<dynamic>? getTopPage() {
    return _routeFeature.getTopPage();
  }

  @override
  RouteInfoWidget? findTopPageRouteInfoWidget() {
    return _routeFeature.findTopPageRouteInfoWidget();
  }

  void dispose() {
    _buildMonitor.dispose();
    _frameMonitor.dispose();
    _imageMonitor.dispose();
  }
}
