/// Grafik batang 7 hari (CustomPainter, tanpa dependensi eksternal).
library;

import 'package:flutter/material.dart';

class WeekBarChart extends StatelessWidget {
  /// 7 nilai (Senin → Minggu).
  final List<int> counts;

  /// Indeks hari ini (0–6) untuk penyorotan.
  final int todayIndex;

  const WeekBarChart({super.key, required this.counts, required this.todayIndex});

  static const List<String> labels = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarPainter(
          counts: counts,
          todayIndex: todayIndex,
          barColor: cs.primary.withAlpha(110),
          todayColor: cs.primary,
          labelColor: cs.onSurfaceVariant,
          valueColor: cs.onSurface,
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<int> counts;
  final int todayIndex;
  final Color barColor;
  final Color todayColor;
  final Color labelColor;
  final Color valueColor;

  _BarPainter({
    required this.counts,
    required this.todayIndex,
    required this.barColor,
    required this.todayColor,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    final n = counts.length;
    final maxVal = counts.reduce((a, b) => a > b ? a : b);
    const topPad = 18.0;
    const labelH = 16.0;
    const gap = 8.0;
    final areaH = size.height - topPad - labelH;
    final barW = (size.width - gap * (n - 1)) / n;

    for (var i = 0; i < n; i++) {
      final x = i * (barW + gap);
      final value = counts[i];
      final h = maxVal <= 0 ? 0.0 : (value / maxVal) * areaH;
      final rect = Rect.fromLTWH(
        x,
        topPad + areaH - h,
        barW,
        h < 2 ? (value > 0 ? 2 : 0) : h,
      );
      if (rect.height > 0) {
        final paint = Paint()
          ..color = i == todayIndex ? todayColor : barColor
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
          paint,
        );
      }
      // Label hari.
      _text(
        canvas,
        WeekBarChart.labels[i % WeekBarChart.labels.length],
        Offset(x + barW / 2, topPad + areaH + 2),
        labelColor,
        10,
      );
      // Nilai di atas batang.
      if (value > 0) {
        _text(
          canvas,
          value.toString(),
          Offset(x + barW / 2, rect.top - 14),
          valueColor,
          10,
          bold: true,
        );
      }
    }
  }

  void _text(
    Canvas canvas,
    String s,
    Offset centerBottom,
    Color color,
    double fontSize, {
    bool bold = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = centerBottom.dx - tp.width / 2;
    canvas.translate(dx, centerBottom.dy);
    tp.paint(canvas, Offset.zero);
    canvas.translate(-dx, -centerBottom.dy);
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.counts != counts ||
      old.todayIndex != todayIndex ||
      old.barColor != barColor ||
      old.todayColor != todayColor;
}
