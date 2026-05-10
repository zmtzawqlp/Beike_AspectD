import 'package:aop_example/aop/aop.dart';
import 'package:aop_example/aop_example_route.dart';
import 'package:aop_example/aop_example_routes.dart';

import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo1',
      navigatorObservers: [AopRuntime.instance.routeObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: Routes.fluttercandiesAopTestPage,
      onGenerateRoute: (RouteSettings settings) {
        return onGenerateRoute(
          settings: settings,
          getRouteSettings: getRouteSettings,
          notFoundPageBuilder: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('not find page')),
          ),
          routeSettingsWrapper: (FFRouteSettings ffRouteSettings) {
            return ffRouteSettings.copyWith(
              builder: () {
                return RouteInfoWidget(
                  settings: ffRouteSettings,
                  child: ffRouteSettings.builder(),
                );
              },
            );
          },
        );
      },
    );
  }
}

/// 存储页面信息的 widget
class RouteInfoWidget extends StatelessWidget {
  const RouteInfoWidget({
    super.key,
    required this.settings,
    required this.child,
    this.uniqueId,
  });

  /// 页面的信息
  final FFRouteSettings settings;

  /// 页面内容
  final Widget child;

  /// 混合模式下的唯一页面 id
  final String? uniqueId;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
