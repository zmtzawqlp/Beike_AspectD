import 'package:flutter/material.dart';
import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:aop_example/aop_example_routes.dart';

import 'performance_common.dart';
import 'performance_workload.dart';

@FFRoute(
  name: 'perf://phase',
  routeName: 'Layout/Paint 优化演示',
  exts: {'group': 'performance', 'order': '2'},
)
class PerformancePhasePage extends StatelessWidget {
  const PerformancePhasePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerformancePageScaffold(
      title: 'Layout / Paint 优化演示',
      subtitle: '对比简单布局与过度嵌套加大量绘制。',
      tips: '展开坏例子后滚动或反复切换，可在 Phase 面板看到分段耗时。',
      child: _PhaseOptimizationDemo(),
    );
  }
}

class _PhaseOptimizationDemo extends StatelessWidget {
  const _PhaseOptimizationDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PerformanceRouteEventPanel(
          panelType: PerformancePanelType.phase,
          routeName: Routes.perfPhase,
        ),
        SizedBox(height: 12),
        PerformanceExamplePair(
          goodTitle: '正确做法：轻量布局和可控绘制',
          goodDesc: '固定尺寸、有限节点数，让 layout/paint 负担保持稳定。',
          goodChild: _LightLayoutPaintDemo(),
          badTitle: '犯错示例：过度嵌套 + 大量绘制',
          badDesc:
              '构造很多 IntrinsicHeight / DecoratedBox / CustomPaint 节点，放大 layout 和 paint 成本。',
          badChild: _HeavyPhaseDemo(),
        ),
      ],
    );
  }
}

class _LightLayoutPaintDemo extends StatelessWidget {
  const _LightLayoutPaintDemo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Row(
        children: List<Widget>.generate(3, (int index) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index == 2 ? 0 : 10),
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 128, 128, 0.12 * (index + 2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '卡片 ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HeavyPhaseDemo extends StatefulWidget {
  const _HeavyPhaseDemo();

  @override
  State<_HeavyPhaseDemo> createState() => _HeavyPhaseDemoState();
}

class _HeavyPhaseDemoState extends State<_HeavyPhaseDemo> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Text(_expanded ? '收起重布局区' : '展开重布局区'),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          height: _expanded ? 320 : 140,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _expanded ? 14 : 5,
            itemBuilder: (BuildContext context, int index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IntrinsicHeight(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: const <Color>[
                          Color(0x2EFA8C16),
                          Color(0x1FEF5350),
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: List<Widget>.generate(4, (int inner) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '布局节点 ${index + 1} - ${inner + 1}',
                                  ),
                                );
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CustomPaint(
                              painter: HeavyPainter(
                                seed: index + (_expanded ? 100 : 0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
