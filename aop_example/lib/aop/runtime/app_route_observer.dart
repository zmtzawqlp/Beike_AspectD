import 'package:flutter/material.dart';

import '../features/route_tracking/route_feature.dart';

class AppRouteObserver extends NavigatorObserver {
  AppRouteObserver({required RouteFeature routeFeature})
    : _routeFeature = routeFeature;

  final RouteFeature _routeFeature;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeFeature.onRouteEntryHandleAdd(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeFeature.onRouteEntryHandlePop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeFeature.onRouteEntryHandlePop(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      _routeFeature.onRouteEntryHandlePop(oldRoute, null);
    }
    if (newRoute != null) {
      _routeFeature.onRouteEntryHandleAdd(newRoute, oldRoute);
    }
  }
}
