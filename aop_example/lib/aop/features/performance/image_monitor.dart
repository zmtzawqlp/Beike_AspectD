import 'dart:async';

import '../../runtime/aop_public_api.dart';
import 'performance_event.dart';

/// 监控图片缓存命中/未命中与解码耗时。
class ImageMonitor {
  ImageMonitor({required AopPublicApi routeApi}) : _routeApi = routeApi;

  final AopPublicApi _routeApi;
  final StreamController<ImageEvent> _controller =
      StreamController<ImageEvent>.broadcast();

  Stream<ImageEvent> get events => _controller.stream;

  T onImageCachePutIfAbsent<T>({
    required Object? key,
    required bool Function() cacheMissGetter,
    required T Function() proceed,
  }) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final T result = proceed();
    stopwatch.stop();

    final bool cacheMiss = cacheMissGetter();
    final int durationMicros = stopwatch.elapsedMicroseconds;
    final bool isSlow = durationMicros >= ImageEvent.slowCacheLookupMicros;

    if (cacheMiss || isSlow) {
      final ImageEvent event = ImageEvent(
        type: cacheMiss ? ImageEventType.cacheMiss : ImageEventType.cacheHit,
        durationMicros: durationMicros,
        isSlow: isSlow,
        key: key,
        routeName: _routeApi.getTopPage()?.settings.name,
      );
      _controller.add(event);
    }

    return result;
  }

  Future<T> onInstantiateImageCodec<T>({
    required String apiName,
    required Object? source,
    required Future<T> Function() proceed,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    try {
      final T result = await proceed();
      stopwatch.stop();
      final int durationMicros = stopwatch.elapsedMicroseconds;
      final bool isSlow = durationMicros >= ImageEvent.slowDecodeMicros;
      if (isSlow) {
        final ImageEvent event = ImageEvent(
          type: ImageEventType.decode,
          durationMicros: durationMicros,
          isSlow: true,
          key: source,
          codecApi: apiName,
          routeName: _routeApi.getTopPage()?.settings.name,
        );
        _controller.add(event);
      }
      return result;
    } catch (error) {
      stopwatch.stop();
      final ImageEvent event = ImageEvent(
        type: ImageEventType.decode,
        durationMicros: stopwatch.elapsedMicroseconds,
        isSlow: true,
        key: source,
        codecApi: apiName,
        routeName: _routeApi.getTopPage()?.settings.name,
        error: error,
      );
      _controller.add(event);
      rethrow;
    }
  }

  void dispose() {
    _controller.close();
  }
}
