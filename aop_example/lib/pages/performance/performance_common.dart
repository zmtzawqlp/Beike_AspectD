import 'dart:async';

import 'package:aop_example/aop/aop.dart';
import 'package:flutter/material.dart';

class PerformanceInfoBanner extends StatelessWidget {
  const PerformanceInfoBanner({
    super.key,
    required this.title,
    required this.content,
    this.footnote,
  });

  final String title;
  final String content;
  final Widget? footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E0EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(height: 1.45, color: Color(0xFF425066)),
          ),
          if (footnote != null) ...<Widget>[
            const SizedBox(height: 10),
            footnote!,
          ],
        ],
      ),
    );
  }
}

class PerformanceDemoSection extends StatelessWidget {
  const PerformanceDemoSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tips,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String tips;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(height: 1.4, color: Color(0xFF4D596A)),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F1E8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tips,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B5530)),
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class PerformanceExamplePair extends StatelessWidget {
  const PerformanceExamplePair({
    super.key,
    required this.goodTitle,
    required this.goodDesc,
    required this.goodChild,
    required this.badTitle,
    required this.badDesc,
    required this.badChild,
  });

  final String goodTitle;
  final String goodDesc;
  final Widget goodChild;
  final String badTitle;
  final String badDesc;
  final Widget badChild;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        PerformanceExampleCard(
          title: goodTitle,
          description: goodDesc,
          accentColor: const Color(0xFF1B8F5A),
          icon: Icons.check_circle_outline,
          child: goodChild,
        ),
        const SizedBox(height: 12),
        PerformanceExampleCard(
          title: badTitle,
          description: badDesc,
          accentColor: const Color(0xFFBF3E36),
          icon: Icons.warning_amber_rounded,
          child: badChild,
        ),
      ],
    );
  }
}

class PerformanceExampleCard extends StatelessWidget {
  const PerformanceExampleCard({
    super.key,
    required this.title,
    required this.description,
    required this.accentColor,
    required this.icon,
    required this.child,
  });

  final String title;
  final String description;
  final Color accentColor;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withAlpha(46)),
        color: accentColor.withAlpha(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF49566B),
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFF49566B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class PerformancePageScaffold extends StatelessWidget {
  const PerformancePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tips,
    required this.child,
    this.showClickTrace = false,
  });

  final String title;
  final String subtitle;
  final String tips;
  final Widget child;
  final bool showClickTrace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          PerformanceInfoBanner(
            title: title,
            content: subtitle,
            footnote: showClickTrace
                ? ValueListenableBuilder<String>(
                    valueListenable: AopRuntime.instance.clickInfo,
                    builder: (_, String value, __) {
                      return Text(
                        value,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A778B),
                        ),
                      );
                    },
                  )
                : null,
          ),
          const SizedBox(height: 16),
          PerformanceDemoSection(
            title: '示例对比',
            subtitle: subtitle,
            tips: tips,
            child: child,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

enum PerformancePanelType { build, frame, phase, image }

class PerformanceRouteEventPanel extends StatefulWidget {
  const PerformanceRouteEventPanel({
    super.key,
    required this.panelType,
    required this.routeName,
    this.maxEvents = 50,
  });

  final PerformancePanelType panelType;
  final String routeName;
  final int maxEvents;

  @override
  State<PerformanceRouteEventPanel> createState() =>
      _PerformanceRouteEventPanelState();
}

class _PerformanceRouteEventPanelState extends State<PerformanceRouteEventPanel> {
  bool _showIssueOnly = true;

  final List<BuildEvent> _buildEvents = <BuildEvent>[];
  final List<FrameEvent> _frameEvents = <FrameEvent>[];
  final List<FramePhaseEvent> _phaseEvents = <FramePhaseEvent>[];
  final List<ImageEvent> _imageEvents = <ImageEvent>[];

  StreamSubscription<BuildEvent>? _buildSub;
  StreamSubscription<FrameEvent>? _frameSub;
  StreamSubscription<FramePhaseEvent>? _phaseSub;
  StreamSubscription<ImageEvent>? _imageSub;

  @override
  void initState() {
    super.initState();
    switch (widget.panelType) {
      case PerformancePanelType.build:
        _buildSub = AopRuntime.instance.buildEvents.listen((BuildEvent e) {
          if (!_isCurrentRoute(e.routeName) || !mounted) {
            return;
          }
          setState(() {
            _buildEvents.insert(0, e);
            if (_buildEvents.length > widget.maxEvents) {
              _buildEvents.removeLast();
            }
          });
        });
        break;
      case PerformancePanelType.frame:
        _frameSub = AopRuntime.instance.frameEvents.listen((FrameEvent e) {
          if (!_isCurrentRoute(e.routeName) || !mounted) {
            return;
          }
          setState(() {
            _frameEvents.insert(0, e);
            if (_frameEvents.length > widget.maxEvents) {
              _frameEvents.removeLast();
            }
          });
        });
        break;
      case PerformancePanelType.phase:
        _phaseSub = AopRuntime.instance.framePhaseEvents.listen((
          FramePhaseEvent e,
        ) {
          if (!_isCurrentRoute(e.routeName) || !mounted) {
            return;
          }
          setState(() {
            _phaseEvents.insert(0, e);
            if (_phaseEvents.length > widget.maxEvents) {
              _phaseEvents.removeLast();
            }
          });
        });
        break;
      case PerformancePanelType.image:
        _imageSub = AopRuntime.instance.imageEvents.listen((ImageEvent e) {
          if (!_isCurrentRoute(e.routeName) || !mounted) {
            return;
          }
          setState(() {
            _imageEvents.insert(0, e);
            if (_imageEvents.length > widget.maxEvents) {
              _imageEvents.removeLast();
            }
          });
        });
        break;
    }
  }

  @override
  void dispose() {
    _buildSub?.cancel();
    _frameSub?.cancel();
    _phaseSub?.cancel();
    _imageSub?.cancel();
    super.dispose();
  }

  bool _isCurrentRoute(String? eventRouteName) {
    return eventRouteName == widget.routeName;
  }

  @override
  Widget build(BuildContext context) {
    final _PanelData panelData = _getPanelData();
    final List<_PanelItem> filteredEvents = _showIssueOnly
        ? panelData.events.where((_PanelItem e) => e.isIssue).toList()
        : panelData.events;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${panelData.title} 监控',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _showIssueOnly = !_showIssueOnly),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _showIssueOnly
                        ? Colors.deepPurpleAccent
                        : Colors.white12,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    _showIssueOnly ? '仅异常' : '全部',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (panelData.events.isNotEmpty)
                GestureDetector(
                  onTap: _clearCurrent,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.deepPurpleAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '当前页面: ${widget.routeName} | 事件数: ${filteredEvents.length}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 10),
          if (filteredEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '暂无事件',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filteredEvents.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Colors.white12, height: 1),
                itemBuilder: (_, int index) {
                  final _PanelItem item = filteredEvents[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 4,
                          margin: const EdgeInsets.only(top: 6, right: 8),
                          decoration: BoxDecoration(
                            color: item.isIssue
                                ? const Color(0xFFFF6B6B)
                                : const Color(0xFFFFB347),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: item.isIssue
                                  ? const Color(0xFFFF6B6B)
                                  : const Color(0xFFFFB347),
                              fontSize: 11.5,
                              height: 1.4,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _clearCurrent() {
    setState(() {
      switch (widget.panelType) {
        case PerformancePanelType.build:
          _buildEvents.clear();
          break;
        case PerformancePanelType.frame:
          _frameEvents.clear();
          break;
        case PerformancePanelType.phase:
          _phaseEvents.clear();
          break;
        case PerformancePanelType.image:
          _imageEvents.clear();
          break;
      }
    });
  }

  _PanelData _getPanelData() {
    switch (widget.panelType) {
      case PerformancePanelType.build:
        return _PanelData(
          title: 'Build',
          events: _buildEvents
              .map(
                (BuildEvent e) => _PanelItem(
                  label: e.toString(),
                  isIssue: e.isSlowBuild || e.isExcessiveRebuild,
                ),
              )
              .toList(),
        );
      case PerformancePanelType.frame:
        return _PanelData(
          title: 'Frame',
          events: _frameEvents
              .map(
                (FrameEvent e) => _PanelItem(
                  label: e.toString(),
                  isIssue: e.isOver60HzBudget || e.isOver120HzBudget,
                ),
              )
              .toList(),
        );
      case PerformancePanelType.phase:
        return _PanelData(
          title: 'Phase',
          events: _phaseEvents
              .map(
                (FramePhaseEvent e) => _PanelItem(
                  label: e.toString(),
                  isIssue: e.isOver60HzBudget || e.isOver120HzBudget,
                ),
              )
              .toList(),
        );
      case PerformancePanelType.image:
        return _PanelData(
          title: 'Image',
          events: _imageEvents
              .map(
                (ImageEvent e) => _PanelItem(
                  label: e.toString(),
                  isIssue: e.isSlow ||
                      e.type == ImageEventType.cacheMiss ||
                      e.error != null,
                ),
              )
              .toList(),
        );
    }
  }
}

class _PanelData {
  const _PanelData({required this.title, required this.events});

  final String title;
  final List<_PanelItem> events;
}

class _PanelItem {
  const _PanelItem({required this.label, required this.isIssue});

  final String label;
  final bool isIssue;
}
