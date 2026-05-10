import 'dart:math' as math;

import 'package:flutter/material.dart';

int runExpensiveCalculation(int iterations) {
  int checksum = 0;
  for (int i = 1; i <= iterations; i++) {
    checksum = (checksum + countPrimeFactors(i * 17 + 3)) % 100000;
  }
  return checksum;
}

int countPrimeFactors(int value) {
  int n = value;
  int count = 0;
  int divisor = 2;

  while (divisor * divisor <= n) {
    while (n % divisor == 0) {
      n ~/= divisor;
      count += 1;
    }
    divisor += divisor == 2 ? 1 : 2;
  }

  if (n > 1) {
    count += 1;
  }

  return count;
}

class HeavyPainter extends CustomPainter {
  HeavyPainter({required this.seed});

  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    for (int index = 0; index < 80; index++) {
      final double progress = (index + 1) / 80;
      paint.color =
          Color.lerp(
            const Color(0xFFFD7E14),
            const Color(0xFF8B1E3F),
            progress,
          ) ??
          Colors.orange;
      final double radius = 6 + (index % 7) * 2.0;
      final double dx = (math.sin(index + seed / 10) * 0.5 + 0.5) * size.width;
      final double dy =
          (math.cos(index * 1.3 + seed / 7) * 0.5 + 0.5) * size.height;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant HeavyPainter oldDelegate) {
    return oldDelegate.seed != seed;
  }
}
