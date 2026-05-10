// ignore_for_file: non_constant_identifier_names

import 'dart:ui' as ui;

import 'package:beike_aspectd/aspectd.dart';
import 'package:flutter/widgets.dart';

import '../runtime/aop_runtime.dart';

const String _vmEntryPoint = 'vm:entry-point';

@Aspect()
@pragma(_vmEntryPoint)
/// Widget 重建性能切面
///
/// 拦截 [StatefulElement.performRebuild]，收集 build 耗时与帧内重建次数。
class PerformanceAspect {
  @pragma(_vmEntryPoint)
  PerformanceAspect();

  @Execute(
    'package:flutter/src/widgets/framework.dart',
    'StatefulElement',
    '-performRebuild',
  )
  @pragma(_vmEntryPoint)
  /// [StatefulElement]
  ///   void performRebuild() {
  void StatefulElement_performRebuild(PointCut pointCut) {
    final Element? element = pointCut.target as Element?;
    if (element != null) {
      AopRuntime.instance.onPerformRebuild(element, () => pointCut.proceed());
    } else {
      pointCut.proceed();
    }
  }

  @Execute(
    'package:flutter/src/widgets/framework.dart',
    'BuildOwner',
    '-buildScope',
  )
  @pragma(_vmEntryPoint)
  /// [BuildOwner]
  ///   void buildScope(Element context, [VoidCallback? callback]) {
  void BuildOwner_buildScope(PointCut pointCut) {
    AopRuntime.instance.onBuildOwnerBuildScope(() => pointCut.proceed());
  }

  @Execute(
    'package:flutter/src/rendering/object.dart',
    'PipelineOwner',
    '-flushLayout',
  )
  @pragma(_vmEntryPoint)
  /// [PipelineOwner]
  ///   void flushLayout() {
  void PipelineOwner_flushLayout(PointCut pointCut) {
    AopRuntime.instance.onPipelineOwnerFlushLayout(() => pointCut.proceed());
  }

  @Execute(
    'package:flutter/src/rendering/object.dart',
    'PipelineOwner',
    '-flushPaint',
  )
  @pragma(_vmEntryPoint)
  /// [PipelineOwner]
  ///   void flushPaint() {
  void PipelineOwner_flushPaint(PointCut pointCut) {
    AopRuntime.instance.onPipelineOwnerFlushPaint(() => pointCut.proceed());
  }

  @Execute(
    'package:flutter/src/painting/image_cache.dart',
    'ImageCache',
    '-putIfAbsent',
  )
  @pragma(_vmEntryPoint)
  /// [ImageCache]
  ///   ImageStreamCompleter? putIfAbsent(Object key, ImageStreamCompleter Function() loader, {ImageErrorListener? onError}) {
  dynamic ImageCache_putIfAbsent(PointCut pointCut) {
    final List<dynamic>? params = pointCut.positionalParams;
    final Object? key = params != null && params.isNotEmpty ? params[0] : null;
    bool cacheMiss = false;

    if (params != null && params.length >= 2) {
      final Object? loader = params[1];
      if (loader is ImageStreamCompleter Function()) {
        final ImageStreamCompleter Function() typedLoader = loader;
        params[1] = () {
          cacheMiss = true;
          return typedLoader();
        };
      }
    }

    return AopRuntime.instance.onImageCachePutIfAbsent(
      key: key,
      cacheMissGetter: () => cacheMiss,
      proceed: () => pointCut.proceed(),
    );
  }

  @Execute(
    'package:flutter/src/painting/binding.dart',
    'PaintingBinding',
    '-instantiateImageCodec',
  )
  @pragma(_vmEntryPoint)
  /// [PaintingBinding]
  ///   Future<ui.Codec> instantiateImageCodec(Uint8List list, {int? cacheWidth, int? cacheHeight, bool allowUpscaling = false}) {
  Future<ui.Codec> PaintingBinding_instantiateImageCodec(PointCut pointCut) {
    final Object? source =
        pointCut.positionalParams != null &&
            pointCut.positionalParams!.isNotEmpty
        ? pointCut.positionalParams![0]
        : null;
    return AopRuntime.instance.onInstantiateImageCodec<ui.Codec>(
      apiName: 'instantiateImageCodec',
      source: source,
      proceed: () => pointCut.proceed() as Future<ui.Codec>,
    );
  }

  @Execute(
    'package:flutter/src/painting/binding.dart',
    'PaintingBinding',
    '-instantiateImageCodecWithSize',
  )
  @pragma(_vmEntryPoint)
  /// [PaintingBinding]
  ///   Future<ui.Codec> instantiateImageCodecWithSize(ImmutableBuffer buffer, {TargetImageSizeCallback? getTargetSize}) {
  Future<ui.Codec> PaintingBinding_instantiateImageCodecWithSize(
    PointCut pointCut,
  ) {
    final Object? source =
        pointCut.positionalParams != null &&
            pointCut.positionalParams!.isNotEmpty
        ? pointCut.positionalParams![0]
        : null;
    return AopRuntime.instance.onInstantiateImageCodec<ui.Codec>(
      apiName: 'instantiateImageCodecWithSize',
      source: source,
      proceed: () => pointCut.proceed() as Future<ui.Codec>,
    );
  }

  @Execute(
    'package:flutter/src/painting/binding.dart',
    'PaintingBinding',
    '-instantiateImageCodecFromBuffer',
  )
  @pragma(_vmEntryPoint)
  /// [PaintingBinding]
  ///   Future<ui.Codec> instantiateImageCodecFromBuffer(ImmutableBuffer buffer, {int? cacheWidth, int? cacheHeight, bool allowUpscaling = false}) {
  Future<ui.Codec> PaintingBinding_instantiateImageCodecFromBuffer(
    PointCut pointCut,
  ) {
    final Object? source =
        pointCut.positionalParams != null &&
            pointCut.positionalParams!.isNotEmpty
        ? pointCut.positionalParams![0]
        : null;
    return AopRuntime.instance.onInstantiateImageCodec<ui.Codec>(
      apiName: 'instantiateImageCodecFromBuffer',
      source: source,
      proceed: () => pointCut.proceed() as Future<ui.Codec>,
    );
  }
}
