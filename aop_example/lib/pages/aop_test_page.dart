import 'package:ff_annotation_route_library/ff_annotation_route_library.dart';
import 'package:flutter/material.dart';

import '../aop_example_route.dart';
import '../aop_example_routes.dart';

@FFRoute(name: 'fluttercandies://aopTestPage', routeName: '插桩测试页面')
class AopTestPage extends StatelessWidget {
  const AopTestPage({super.key});

  static const String _selfRouteName = Routes.fluttercandiesAopTestPage;
  static const List<String> _groupOrder = <String>[
    'performance',
    'interaction',
  ];

  List<_TopLevelMenuItem> _buildMenuItems() {
    final List<_TopLevelMenuItem> items = routeNames
        .where((String name) => name != _selfRouteName)
        .map((String name) {
          final FFRouteSettings settings = getRouteSettings(name: name);
          final Map<String, dynamic>? exts = settings.exts;
          final String group = (exts?['group'] as String?) ?? 'other';
          final int order = int.tryParse('${exts?['order'] ?? 999}') ?? 999;
          return _TopLevelMenuItem(
            name: name,
            group: group,
            title: settings.routeName ?? name,
            order: order,
          );
        })
        .toList(growable: false);

    items.sort((_TopLevelMenuItem a, _TopLevelMenuItem b) {
      final int groupCompare =
          _groupSortIndex(a.group).compareTo(_groupSortIndex(b.group));
      if (groupCompare != 0) {
        return groupCompare;
      }
      final int orderCompare = a.order.compareTo(b.order);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.title.compareTo(b.title);
    });

    return items;
  }

  int _groupSortIndex(String group) {
    final int index = _groupOrder.indexOf(group);
    return index < 0 ? _groupOrder.length : index;
  }

  String _groupDisplayName(String group) {
    switch (group) {
      case 'performance':
        return '性能';
      case 'interaction':
        return '点击';
      case 'home':
        return '首页';
      default:
        return '其他';
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<_TopLevelMenuItem> menuItems = _buildMenuItems();
    final Map<String, List<_TopLevelMenuItem>> groupedItems =
        <String, List<_TopLevelMenuItem>>{};
    for (final _TopLevelMenuItem item in menuItems) {
      groupedItems.putIfAbsent(item.group, () => <_TopLevelMenuItem>[]).add(item);
    }

    final List<String> orderedGroups = <String>[
      ..._groupOrder,
      ...groupedItems.keys.where((String group) => !_groupOrder.contains(group)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('AOP 首页菜单')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ..._buildGroupSections(context, groupedItems, orderedGroups),
        ],
      ),
    );
  }

  List<Widget> _buildGroupSections(
    BuildContext context,
    Map<String, List<_TopLevelMenuItem>> groupedItems,
    List<String> orderedGroups,
  ) {
    final List<Widget> sections = <Widget>[];
    for (final String group in orderedGroups) {
      final List<_TopLevelMenuItem>? items = groupedItems[group];
      if (items == null || items.isEmpty) {
        continue;
      }
      if (sections.isNotEmpty) {
        sections.add(const SizedBox(height: 16));
      }
      sections.add(
        _MenuSection(
          title: _groupDisplayName(group),
          child: Column(
            children: List<Widget>.generate(items.length, (int index) {
              final _TopLevelMenuItem item = items[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 12),
                child: _MenuCard(
                  title: item.title,
                  subtitle: item.name,
                  onTap: () => Navigator.of(context).pushNamed(item.name),
                ),
              );
            }),
          ),
        ),
      );
    }
    return sections;
  }
}

class _TopLevelMenuItem {
  const _TopLevelMenuItem({
    required this.name,
    required this.group,
    required this.title,
    required this.order,
  });

  final String name;
  final String group;
  final String title;
  final int order;
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(height: 1.45, color: Color(0xFF425066)),
          ),
        ],
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x11000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Color(0xFF4D596A)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
