import 'dart:math' as math;

import 'package:flutter/material.dart';

void _drawText(Canvas canvas, String text, Offset offset, Color color,
    {double size = 11, TextAlign align = TextAlign.left, FontWeight? weight}) {
  final tp = TextPainter(
    text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout();
  var dx = offset.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  if (align == TextAlign.right) dx -= tp.width;
  tp.paint(canvas, Offset(dx, offset.dy));
}

/// Simple line chart with an area fill.
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.values, required this.labels, this.height = 170});
  final List<double> values;
  final List<String> labels;
  final double height;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _LinePainter(values, labels, scheme.primary, scheme.onSurfaceVariant,
            scheme.outlineVariant),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values, this.labels, this.color, this.textColor, this.gridColor);
  final List<double> values;
  final List<String> labels;
  final Color color, textColor, gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 36.0, right = 10.0, top = 10.0, bottom = 24.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    var minV = values.reduce(math.min);
    var maxV = values.reduce(math.max);
    if (maxV - minV < 10) {
      minV -= 5;
      maxV += 5;
    }
    minV = (minV / 5).floor() * 5.0;
    maxV = (maxV / 5).ceil() * 5.0;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = top + h * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), grid);
      final v = maxV - (maxV - minV) * i / 2;
      _drawText(canvas, '${v.toStringAsFixed(0)}%', Offset(0, y - 7), textColor);
    }
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = values.length == 1 ? w / 2 : w * i / (values.length - 1);
      final dy = top + h * (1 - (values[i] - minV) / (maxV - minV));
      pts.add(Offset(left + dx, dy));
    }
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(pts.last.dx, top + h)
      ..lineTo(pts.first.dx, top + h)
      ..close();
    canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round);
    for (var i = 0; i < pts.length; i++) {
      canvas.drawCircle(pts[i], 5, Paint()..color = Colors.white);
      canvas.drawCircle(pts[i], 3.5, Paint()..color = color);
      if (i < labels.length) {
        _drawText(canvas, labels[i], Offset(pts[i].dx, size.height - 16), textColor,
            align: TextAlign.center);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}

/// Vertical bar chart with value labels.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 170,
    this.maxValue,
    this.suffix = '',
    this.colors,
  });
  final List<double> values;
  final List<String> labels;
  final double height;
  final double? maxValue;
  final String suffix;
  final List<Color>? colors;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarPainter(values, labels, scheme.primary, scheme.onSurface,
            scheme.onSurfaceVariant, scheme.outlineVariant, maxValue, suffix, colors),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.values, this.labels, this.color, this.valueColor, this.textColor,
      this.gridColor, this.maxValue, this.suffix, this.colors);
  final List<double> values;
  final List<String> labels;
  final Color color, valueColor, textColor, gridColor;
  final double? maxValue;
  final String suffix;
  final List<Color>? colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const top = 18.0, bottom = 22.0;
    final h = size.height - top - bottom;
    final maxV = maxValue ?? (values.reduce(math.max) * 1.1);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    canvas.drawLine(Offset(0, top + h), Offset(size.width, top + h),
        Paint()..color = gridColor);
    final slot = size.width / values.length;
    final barW = math.min(44.0, slot * 0.55);
    for (var i = 0; i < values.length; i++) {
      final bh = h * (values[i] / safeMax).clamp(0.0, 1.0).toDouble();
      final x = slot * i + (slot - barW) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, top + h - bh, barW, bh),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      );
      final c = (colors != null && i < colors!.length) ? colors![i] : color;
      canvas.drawRRect(rect, Paint()..color = c);
      _drawText(canvas, '${values[i].toStringAsFixed(0)}$suffix',
          Offset(x + barW / 2, top + h - bh - 15), valueColor,
          align: TextAlign.center, weight: FontWeight.w700);
      if (i < labels.length) {
        _drawText(canvas, labels[i], Offset(x + barW / 2, size.height - 16), textColor,
            align: TextAlign.center);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}

/// Ring / donut gauge, used for percentages.
class Ring extends StatelessWidget {
  const Ring({
    super.key,
    required this.fraction,
    required this.centerText,
    this.subText,
    this.size = 120,
    this.stroke = 12,
    this.color,
    this.trackColor,
    this.secondaryColor,
  });
  final double fraction;
  final String centerText;
  final String? subText;
  final double size, stroke;
  final Color? color, trackColor, secondaryColor;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          fraction.clamp(0.0, 1.0).toDouble(),
          color ?? scheme.primary,
          trackColor ?? secondaryColor ?? scheme.surfaceContainerHighest,
          stroke,
          centerText,
          subText,
          scheme.onSurface,
          scheme.onSurfaceVariant,
          size,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color, this.track, this.stroke, this.center,
      this.sub, this.textColor, this.subColor, this.diameter);
  final double fraction, stroke, diameter;
  final Color color, track, textColor, subColor;
  final String center;
  final String? sub;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: (size.shortestSide - stroke) / 2);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
    final big = diameter * 0.22;
    _drawText(canvas, center,
        Offset(size.width / 2, size.height / 2 - big * (sub == null ? 0.6 : 0.95)), textColor,
        size: big, align: TextAlign.center, weight: FontWeight.w800);
    if (sub != null) {
      _drawText(canvas, sub!, Offset(size.width / 2, size.height / 2 + big * 0.35), subColor,
          size: math.max(10, diameter * 0.09), align: TextAlign.center);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => true;
}
