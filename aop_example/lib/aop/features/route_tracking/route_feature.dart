import 'package:aop_example/main.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../runtime/aop_public_api.dart';

class RouteFeature implements AopPublicApi {
  final List<Route<dynamic>> _routes = <Route<dynamic>>[];

  void onRouteEntryHandleAdd(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    if (route != null) {
      _routes.add(route);
    }
  }

  void onRouteEntryHandlePop(
    Route<dynamic>? route,
    Route<dynamic>? previousRoute,
  ) {
    if (route != null) {
      _routes.remove(route);
    }
  }

  @override
  bool isCurrentRouteWidget(Widget widget) {
    final Route<dynamic>? topRoute = _routes.lastWhereOrNull(
      (Route<dynamic> route) => route is! PageRoute,
    );
    if (topRoute == null) {
      return false;
    }

    final BuildContext? context = topRoute is ModalRoute<dynamic>
        ? topRoute.subtreeContext
        : null;
    if (context == null) {
      return false;
    }

    bool found = false;

    void visit(BuildContext currentContext) {
      if (found) {
        return;
      }
      if (currentContext.widget == widget) {
        found = true;
        return;
      }
      currentContext.visitChildElements(visit);
    }

    visit(context);
    return found;
  }

  @override
  Route<dynamic>? getCurrentRoute() {
    if (_routes.isEmpty) {
      return null;
    }
    return _routes.last;
  }

  @override
  PageRoute<dynamic>? getTopPage() {
    if (_routes.isEmpty) {
      return null;
    }

    return _routes.lastWhereOrNull(
          (Route<dynamic> route) => route is PageRoute<dynamic>,
        )
        as PageRoute<dynamic>?;
  }

  @override
  RouteInfoWidget? findTopPageRouteInfoWidget() {
    final BuildContext? context = getTopPage()?.subtreeContext;
    RouteInfoWidget? routeInfoWidget;
    if (context != null) {
      void visitChildElements(BuildContext currentContext) {
        if (currentContext.widget is RouteInfoWidget) {
          routeInfoWidget = currentContext.widget as RouteInfoWidget;
          return;
        }
        currentContext.visitChildElements(visitChildElements);
      }

      visitChildElements(context);
    }
    return routeInfoWidget;
  }
}
