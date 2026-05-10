import 'package:flutter/material.dart';
import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:aop_example/aop_example_routes.dart';

import 'performance_common.dart';
import 'performance_workload.dart';

@FFRoute(
  name: 'perf://build',
  routeName: 'Build 优化演示',
  exts: {'group': 'performance', 'order': '0'},
)
class PerformanceBuildPage extends StatelessWidget {
  const PerformanceBuildPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerformancePageScaffold(
      title: 'Build 优化演示',
      subtitle: '对比 build 内做重计算与预计算后只渲染结果。',
      tips: '坏例子会触发 Build 面板；连续点击更容易看到慢 build 事件。',
      child: _BuildOptimizationDemo(),
    );
  }
}

class _BuildOptimizationDemo extends StatelessWidget {
  const _BuildOptimizationDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PerformanceRouteEventPanel(
          panelType: PerformancePanelType.build,
          routeName: Routes.perfBuild,
        ),
        SizedBox(height: 12),
        PerformanceExamplePair(
          goodTitle: '正确做法：提前计算，build 只负责渲染',
          goodDesc: '初始化时把摘要算好，点击只切换索引，避免每次重建都重新做大循环。',
          goodChild: _PrecomputedSummaryDemo(),
          badTitle: '犯错示例：在 build 里做重计算',
          badDesc: '每次 setState 后都在 build 执行质因数统计，容易直接打出慢 build。',
          badChild: _SlowBuildDemoTile(),
        ),
      ],
    );
  }
}

class _PrecomputedSummaryDemo extends StatefulWidget {
  const _PrecomputedSummaryDemo();

  @override
  State<_PrecomputedSummaryDemo> createState() =>
      _PrecomputedSummaryDemoState();
}

class _PrecomputedSummaryDemoState extends State<_PrecomputedSummaryDemo> {
  late final List<int> _cachedScores;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _cachedScores = List<int>.generate(6, (int index) {
      return runExpensiveCalculation(9000 + index * 300);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(_cachedScores.length, (int index) {
            return ChoiceChip(
              label: Text('方案 ${index + 1}'),
              selected: index == _selectedIndex,
              onSelected: (_) => setState(() => _selectedIndex = index),
            );
          }),
        ),
        const SizedBox(height: 10),
        Text(
          '预计算摘要值：${_cachedScores[_selectedIndex]}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SlowBuildDemoTile extends StatefulWidget {
  const _SlowBuildDemoTile();

  @override
  State<_SlowBuildDemoTile> createState() => _SlowBuildDemoTileState();
}

class _SlowBuildDemoTileState extends State<_SlowBuildDemoTile> {
  static const int _workIterations = 35000;

  int _tapCount = 0;
  bool _injectSlowBuild = false;
  int _lastChecksum = 0;

  @override
  Widget build(BuildContext context) {
    if (_injectSlowBuild) {
      _lastChecksum = runExpensiveCalculation(_workIterations);
      _injectSlowBuild = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton(
          onPressed: () {
            setState(() {
              _tapCount += 1;
              _injectSlowBuild = true;
            });
          },
          child: Text('触发慢 build 第 $_tapCount 次'),
        ),
        const SizedBox(height: 8),
        Text('最近一次 checksum: $_lastChecksum'),
      ],
    );
  }
}
