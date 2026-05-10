import 'package:flutter/material.dart';
import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';

import 'performance/performance_common.dart';

@FFRoute(
  name: 'perf://interaction',
  routeName: '点击弹框链路演示',
  exts: {'group': 'interaction', 'order': '0'},
)
class PerformanceInteractionPage extends StatelessWidget {
  const PerformanceInteractionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerformancePageScaffold(
      title: '点击 / 弹框链路演示',
      subtitle: '保留已有点击链路示例，方便联动看路由和交互日志。',
      tips: '这里不强调性能，只用于验证 AOP 链路仍然正常。',
      showClickTrace: true,
      child: _InteractionDemo(),
    );
  }
}

class _InteractionDemo extends StatelessWidget {
  const _InteractionDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('测试弹框'),
                content: const Text('这是一个测试弹框'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            );
          },
          child: const Text('打开弹框'),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'GestureDetector 点击',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}
