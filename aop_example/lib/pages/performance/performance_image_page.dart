import 'package:flutter/material.dart';
import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:aop_example/aop_example_routes.dart';

import 'performance_common.dart';

@FFRoute(
  name: 'perf://image',
  routeName: 'Image 优化演示',
  exts: {'group': 'performance', 'order': '3'},
)
class PerformanceImagePage extends StatelessWidget {
  const PerformanceImagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PerformancePageScaffold(
      title: 'Image 优化演示',
      subtitle: '对比复用缓存图片与主动制造 cache miss / decode。',
      tips: '坏例子会反复切换尺寸并先 evict 缓存，更容易在 Image 面板看到 miss / decode。',
      child: _ImageOptimizationDemo(),
    );
  }
}

class _ImageOptimizationDemo extends StatelessWidget {
  const _ImageOptimizationDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PerformanceRouteEventPanel(
          panelType: PerformancePanelType.image,
          routeName: Routes.perfImage,
        ),
        SizedBox(height: 12),
        PerformanceExamplePair(
          goodTitle: '正确做法：稳定 key，复用缓存图',
          goodDesc: '使用固定 asset 和固定尺寸，重复展示时基本走缓存命中。',
          goodChild: _CachedImageDemo(),
          badTitle: '犯错示例：频繁换尺寸并主动清缓存',
          badDesc: '每次点击都先 evict 再切换 cacheWidth，让同一资源重复 decode。',
          badChild: _CacheMissImageDemo(),
        ),
      ],
    );
  }
}

class _CachedImageDemo extends StatefulWidget {
  const _CachedImageDemo();

  @override
  State<_CachedImageDemo> createState() => _CachedImageDemoState();
}

class _CachedImageDemoState extends State<_CachedImageDemo> {
  bool _showLarge = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton(
          onPressed: () => setState(() => _showLarge = !_showLarge),
          child: Text(_showLarge ? '切回小图' : '切到大图'),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          height: _showLarge ? 160 : 110,
          alignment: Alignment.center,
          child: Image.asset(
            'assets/images/40.png',
            width: _showLarge ? 180 : 120,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

class _CacheMissImageDemo extends StatefulWidget {
  const _CacheMissImageDemo();

  @override
  State<_CacheMissImageDemo> createState() => _CacheMissImageDemoState();
}

class _CacheMissImageDemoState extends State<_CacheMissImageDemo> {
  static const List<int> _cacheWidths = <int>[64, 128, 192, 256, 320];

  int _index = 0;
  int _evictCount = 0;

  Future<void> _nextVariant() async {
    const AssetImage baseImage = AssetImage('assets/images/40.png');
    await baseImage.evict();
    if (!mounted) {
      return;
    }
    setState(() {
      _evictCount += 1;
      _index = (_index + 1) % _cacheWidths.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int cacheWidth = _cacheWidths[_index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FilledButton.tonal(
          onPressed: _nextVariant,
          child: Text('制造 cache miss（已执行 $_evictCount 次）'),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 180,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Image(
            image: ResizeImage(
              const AssetImage('assets/images/40.png'),
              width: cacheWidth,
            ),
            width: 220,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
        Text('当前 cacheWidth: $cacheWidth'),
      ],
    );
  }
}
