import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's mark: a progress arc that never quite closes.
///
/// Drawn rather than shipped as an asset so it takes any size and colour the
/// caller asks for, and so it stays the same shape as the launcher icon in
/// android/app/src/main/res/drawable/ic_launcher_foreground.xml — the gap and
/// the stroke ratio below are the numbers from that vector.
class AppMark extends StatelessWidget {
  final double size;
  final Color color;

  const AppMark({super.key, this.size = 22, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _RingPainter(color)),
      );
}

class _RingPainter extends CustomPainter {
  final Color color;
  _RingPainter(this.color);

  /// The opening, centred at the top. Wide enough to read as deliberate at
  /// 22px rather than looking like a rendering seam.
  static const double _gapDegrees = 80;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.155;
    // Inset by half the stroke so the painted edge lands inside the box
    // instead of being clipped by it.
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - stroke) / 2,
    );
    canvas.drawArc(
      rect,
      (-90 + _gapDegrees / 2) * math.pi / 180,
      (360 - _gapDegrees) * math.pi / 180,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.color != color;
}
