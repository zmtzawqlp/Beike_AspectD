// ignore_for_file: implementation_imports

import 'package:aop_example/main.dart';
import 'package:beike_aspectd/aspectd.dart';
import 'package:extended_image/extended_image.dart';
import 'package:extended_text/src/extended/rendering/paragraph.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;

import '../../runtime/aop_public_api.dart';
import '../common/aop_location_ext.dart';

class ClickPathBuilder {
  ClickPathBuilder({required AopPublicApi routeApi}) : _routeApi = routeApi;

  final AopPublicApi _routeApi;

  String? build(RenderObject renderObject) {
    final DebugCreator? debugCreator =
        renderObject.debugCreator as DebugCreator?;
    final Element? element = debugCreator?.element;
    if (element == null) {
      return null;
    }

    final List<String> infos = <String>[];
    _addShowInfo(element, infos);
    _addImageInfo(element, infos);
    if (infos.length > 1) {
      final String merged = infos.join(';');
      infos
        ..clear()
        ..add(merged);
    }

    _addAncestor(element, infos);
    element.visitAncestorElements((Element currentElement) {
      if (currentElement.widget is RouteInfoWidget) {
        final RouteInfoWidget routeInfoWidget =
            currentElement.widget as RouteInfoWidget;
        infos.add(
          '${routeInfoWidget.settings.name}(${routeInfoWidget.settings.routeName!})',
        );
        return false;
      }

      if (_routeApi.isCurrentRouteWidget(currentElement.widget)) {
        _addAncestor(currentElement, infos);
        final Route<dynamic>? currentRoute = _routeApi.getCurrentRoute();
        if (currentRoute is RawDialogRoute<dynamic>) {
          infos.add('弹框');
        }

        final RouteInfoWidget? routeInfoWidget = _routeApi
            .findTopPageRouteInfoWidget();
        if (routeInfoWidget != null) {
          infos.add(
            '${routeInfoWidget.settings.name}(${routeInfoWidget.settings.routeName!})',
          );
        } else {
          final PageRoute<dynamic>? pageRoute = _routeApi.getTopPage();
          if (pageRoute != null && pageRoute.settings.name != null) {
            infos.add(pageRoute.settings.name!);
          }
        }
        return false;
      }

      _addAncestor(currentElement, infos);
      return true;
    });

    return infos.reversed.join('/');
  }

  void _addAncestor(Element element, List<String> infos) {
    if (!_isLocalElement(element)) {
      return;
    }

    String result = element.widget.runtimeType.toString();
    int slot = 0;
    if (element.slot is IndexedSlot) {
      slot = (element.slot as IndexedSlot<dynamic>).index;
    }
    result += '[$slot]';
    infos.add(result);
  }

  void _addShowInfo(Element element, List<String> infos) {
    final dynamic renderObject = element.renderObject;
    if (renderObject is RenderParagraph ||
        renderObject is ExtendedRenderParagraph) {
      infos.add('${renderObject.text.toPlainText()}');
      return;
    }

    element.visitChildElements((Element childElement) {
      _addShowInfo(childElement, infos);
    });
  }

  void _addImageInfo(Element element, List<String> infos) {
    final dynamic widget = element.widget;
    if (widget is Image || widget is ExtendedImage) {
      dynamic imageProvider = widget.image;

      void checkImageProvider(dynamic provider) {
        if (provider is ExactAssetImage ||
            provider is AssetImage ||
            provider is ExtendedExactAssetImageProvider ||
            provider is ExtendedAssetImageProvider) {
          infos.add(
            '图片(${path.basename(provider.assetName.toString())}${provider.package != null ? ' 模块: ${provider.package}' : ''})',
          );
        }
      }

      if (imageProvider is ResizeImage ||
          imageProvider is ExtendedResizeImage) {
        imageProvider = imageProvider.imageProvider;
      }
      checkImageProvider(imageProvider);
      return;
    }

    if (widget is RawImage || widget is ExtendedRawImage) {
      infos.add('图片(${widget.debugImageLabel})');
    }
  }

  bool _isLocalElement(Element element) {
    final Widget widget = element.widget;
    if (widget is! AopHasCreationLocation) {
      return false;
    }

    final Object location = (widget as AopHasCreationLocation).aopLocation;
    if (location is! AopLocation) {
      return false;
    }
    return location.isProjectRoot();
  }
}
