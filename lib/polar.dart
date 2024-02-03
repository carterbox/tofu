import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

class PolarLineChart extends StatelessWidget {
  final double radius;

  final List<double> offsets;

  final Color? color;

  final double startRadianOffset;

  const PolarLineChart({
    required this.radius,
    required this.offsets,
    this.color,
    this.startRadianOffset = 0.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomPaint(
        painter: Squiggle(
          radius,
          offsets,
          color ?? Colors.black,
          startRadianOffset,
        ),
      ),
    );
  }

  factory PolarLineChart.fromCircle(double radius, {Color? color}) {
    return PolarLineChart(
      radius: radius,
      offsets: List<double>.generate(24 * 4, (index) => 0.0),
      color: color,
    );
  }
}

class Squiggle extends CustomPainter {
  final double radius;

  final List<double> offsets;

  final Color color;

  final double startRadianOffset;

  const Squiggle(this.radius, this.offsets, this.color, this.startRadianOffset);

  @override
  paint(Canvas canvas, Size size) {
    final List<List<double>> points = polarToCartesian(
      radius: radius,
      offsets: offsets,
      angleStart: startRadianOffset,
    );
    final path = Path();
    // Makeing a continous loop, so start drawing from last point
    path.moveTo(points[points.length - 1][0], points[points.length - 1][1]);
    for (int i = 0; i < points.length; ++i) {
      path.lineTo(points[i][0], points[i][1]);
    }
    path.close();
    final linePainter = Paint();
    linePainter.style = PaintingStyle.stroke;
    linePainter.strokeWidth = 8.0;
    linePainter.strokeJoin = StrokeJoin.round;
    linePainter.color = color;
    canvas.drawPath(
      path,
      linePainter,
    );
  }

  @override
  bool shouldRepaint(Squiggle oldDelegate) {
    return radius == oldDelegate.radius &&
        listEquals(offsets, oldDelegate.offsets);
  }

  @override
  bool shouldRebuildSemantics(Squiggle oldDelegate) => false;
}

/// Return cartesian coordinates from the polar coordinates provided as a base
/// radius and offsets from that radius
List<List<double>> polarToCartesian({
  required double radius,
  required List<double> offsets,
  required double angleStart,
}) {
  List<List<double>> points = [];
  final angularStep = 2.0 * math.pi / offsets.length;
  for (int i = 0; i < offsets.length; ++i) {
    final double angle = angularStep * i + angleStart;
    points.add([
      (radius + offsets[i]) * math.cos(angle),
      (radius + offsets[i]) * math.sin(angle),
    ]);
  }
  return points;
}
