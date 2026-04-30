import 'package:flutter/material.dart';

import '../core/themes/color_palette.dart';

class ExploreLesothoLogo extends StatelessWidget {
  const ExploreLesothoLogo({
    super.key,
    this.size = 96,
    this.showShadow = true,
  });

  final double size;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: size * 0.22,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        painter: _ExploreLesothoLogoPainter(),
      ),
    );
  }
}

class _ExploreLesothoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final greenPaint = Paint()
      ..color = ColorPalette.primaryGreen
      ..style = PaintingStyle.fill;
    final darkPaint = Paint()
      ..color = ColorPalette.darkGreen
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = radius * 0.08;
    final whitePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.62, greenPaint);

    final mountainPath = Path()
      ..moveTo(radius * 0.58, radius * 1.24)
      ..lineTo(radius * 0.9, radius * 0.88)
      ..lineTo(radius * 1.08, radius * 1.08)
      ..lineTo(radius * 1.28, radius * 0.76)
      ..lineTo(radius * 1.56, radius * 1.24)
      ..close();
    canvas.drawPath(mountainPath, whitePaint);

    final compassPath = Path()
      ..moveTo(radius * 1.48, radius * 0.52)
      ..lineTo(radius * 1.08, radius * 1.42)
      ..lineTo(radius * 0.52, radius * 1.48)
      ..lineTo(radius * 0.92, radius * 0.58)
      ..close();
    canvas.drawPath(compassPath, whitePaint);

    final innerCompass = Path()
      ..moveTo(radius * 1.28, radius * 0.82)
      ..lineTo(radius * 1.03, radius * 1.25)
      ..lineTo(radius * 0.76, radius * 1.32)
      ..lineTo(radius * 1.0, radius * 0.9)
      ..close();
    canvas.drawPath(innerCompass, greenPaint);
    canvas.drawCircle(center, radius * 0.09, whitePaint);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 0.74),
      -0.9,
      1.7,
      false,
      darkPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
