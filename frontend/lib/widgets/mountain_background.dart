import 'package:flutter/material.dart';

class MountainBackground extends StatelessWidget {
  final Widget child;
  final Color? overlayColor;
  final double overlayOpacity;

  const MountainBackground({
    super.key,
    required this.child,
    this.overlayColor,
    this.overlayOpacity = 0.3,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/images/dashboard_background.jpg',
            fit: BoxFit.cover,
            color: Colors.black.withOpacity(0.20),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (context, error, stackTrace) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF6BA3D1),
                          const Color(0xFF87CEEB),
                          const Color(0xFFB0E0E6),
                          const Color(0xFFFFF8DC),
                          const Color(0xFFFFF0E6),
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 320,
                    child: CustomPaint(
                      painter: MountainPainter(),
                      size: Size(double.infinity, 320),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          color: (overlayColor ?? Colors.black).withOpacity(overlayOpacity),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            scaffoldBackgroundColor: Colors.transparent,
          ),
          child: child,
        ),
      ],
    );
  }
}

class MountainPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Mountain 1 (far back - light)
    final paint1 = Paint()
      ..color = const Color(0xFF5F8AA6).withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, height * 0.6)
      ..lineTo(width * 0.2, height * 0.2)
      ..lineTo(width * 0.4, height * 0.6)
      ..close();

    canvas.drawPath(path1, paint1);

    // Mountain 2 (middle)
    final paint2 = Paint()
      ..color = const Color(0xFF4A6F8A).withOpacity(0.75)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(width * 0.3, height * 0.5)
      ..lineTo(width * 0.5, height * 0.05)
      ..lineTo(width * 0.7, height * 0.5)
      ..close();

    canvas.drawPath(path2, paint2);

    // Mountain 3 (right - foreground)
    final paint3 = Paint()
      ..color = const Color(0xFF2D4A5F)
      ..style = PaintingStyle.fill;

    final path3 = Path()
      ..moveTo(width * 0.6, height * 0.55)
      ..lineTo(width * 0.85, height * 0.15)
      ..lineTo(width, height * 0.55)
      ..close();

    canvas.drawPath(path3, paint3);

    // Left mountain
    final paint4 = Paint()
      ..color = const Color(0xFF3F5F7F)
      ..style = PaintingStyle.fill;

    final path4 = Path()
      ..moveTo(-width * 0.1, height * 0.5)
      ..lineTo(width * 0.15, height * 0.1)
      ..lineTo(width * 0.3, height * 0.5)
      ..close();

    canvas.drawPath(path4, paint4);

    // Snow caps - enhanced
    final snowPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    // Snow on middle mountain (larger)
    final snowPath = Path()
      ..moveTo(width * 0.5, height * 0.05)
      ..lineTo(width * 0.44, height * 0.28)
      ..lineTo(width * 0.56, height * 0.28)
      ..close();

    canvas.drawPath(snowPath, snowPaint);

    // Snow on right mountain (larger)
    final snowPath2 = Path()
      ..moveTo(width * 0.85, height * 0.15)
      ..lineTo(width * 0.78, height * 0.38)
      ..lineTo(width * 0.92, height * 0.38)
      ..close();

    canvas.drawPath(snowPath2, snowPaint);

    // Add some cloud-like elements for more depth
    final cloudPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // Cloud 1
    final cloudPath1 = Path()
      ..addOval(Rect.fromCircle(center: Offset(width * 0.15, height * 0.15), radius: 30));
    canvas.drawPath(cloudPath1, cloudPaint);

    // Cloud 2
    final cloudPath2 = Path()
      ..addOval(Rect.fromCircle(center: Offset(width * 0.8, height * 0.1), radius: 25));
    canvas.drawPath(cloudPath2, cloudPaint);
  }

  @override
  bool shouldRepaint(MountainPainter oldDelegate) => false;
}
