import 'package:aop_example/main.dart';
import 'package:flutter/material.dart';

/// Public route context API shared across AOP features.
abstract class AopPublicApi {
  /// Whether [widget] belongs to the current overlay/dialog route subtree.
  bool isCurrentRouteWidget(Widget widget);

  /// Returns the current top route.
  Route<dynamic>? getCurrentRoute();

  /// Returns the current top page route.
  PageRoute<dynamic>? getTopPage();

  /// Finds the top page [RouteInfoWidget] if present.
  RouteInfoWidget? findTopPageRouteInfoWidget();
}
