import 'package:flutter/material.dart';
import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:aop_example/aop_example_routes.dart';

import 'performance_common.dart';
import 'performance_workload.dart';

@FFRoute(
  name: 'perf://frame',
  routeName: 'Frame 优化演示',
  exts: {'group': 'performance', 'order': '1'},
)
class PerformanceFramePage extends StatelessWidget {
  const PerformanceFramePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerformancePageScaffold(
      title: 'Frame 优化演示',
      subtitle: '对比轻量动画与每帧做 CPU 重活导致掉帧。',
      tips: '坏例子运行约 3 秒，观察 Frame 面板中的 over60 / over120。',
      child: _FrameOptimizationDemo(),
    );
  }
}

class _FrameOptimizationDemo extends StatelessWidget {
  const _FrameOptimizationDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PerformanceRouteEventPanel(
          panelType: PerformancePanelType.frame,
          routeName: Routes.perfFrame,
        ),
        SizedBox(height: 12),
        PerformanceExamplePair(
          goodTitle: '正确做法：轻量动画只更新必要内容',
          goodDesc: '通过 AnimatedBuilder 复用 child，不在每帧做额外 CPU 计算。',
          goodChild: _NormalAnimationDemoTile(),
          badTitle: '犯错示例：每帧都做重运算',
          badDesc: '动画监听里持续 setState，并在 build 中做大循环，容易造成持续掉帧。',
          badChild: _JankyAnimationDemoTile(),
        ),
      ],
    );
  }
}

class _NormalAnimationDemoTile extends StatefulWidget {
  const _NormalAnimationDemoTile();

  @override
  State<_NormalAnimationDemoTile> createState() =>
      _NormalAnimationDemoTileState();
}

class _NormalAnimationDemoTileState extends State<_NormalAnimationDemoTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: const Text('平滑动画示例，通常不会出现 Frame 异常'),
      builder: (BuildContext context, Widget? child) {
        return Opacity(
          opacity: 0.35 + _controller.value * 0.65,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8 + _controller.value * 16,
            ),
            child: child,
          ),
        );
      },
    );
  }
}

class _JankyAnimationDemoTile extends StatefulWidget {
  const _JankyAnimationDemoTile();

  @override
  State<_JankyAnimationDemoTile> createState() =>
      _JankyAnimationDemoTileState();
}

class _JankyAnimationDemoTileState extends State<_JankyAnimationDemoTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  bool _running = false;
  int _samples = 0;
  int _checksum = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 2800),
          )
          ..addListener(() {
            if (!_running || !mounted) {
              return;
            }
            setState(() {
              _samples += 1;
            });
          })
          ..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() {
                _running = false;
              });
            }
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_running) {
      _checksum = runExpensiveCalculation(32000);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: _running
              ? null
              : () {
                  setState(() {
                    _samples = 0;
                    _checksum = 0;
                    _running = true;
                  });
                  _controller.forward(from: 0);
                },
          child: Text(_running ? '掉帧演示中...' : '启动掉帧动画'),
        ),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: _running ? _controller.value : 0),
        const SizedBox(height: 8),
        Text('重绘帧数: $_samples，最近 checksum: $_checksum'),
      ],
    );
  }
}
