import 'package:flutter/material.dart';

/// Dental floss dispenser with a tooth emblem and a visible floss strand.
class FlossIcon extends StatelessWidget {
  final double size;
  const FlossIcon({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: CustomPaint(painter: _FlossPainter()));
}

class _FlossPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size size) {
    c.save();
    c.scale(size.width / 48, size.height / 48);
    final p = Paint()..color = const Color(0xFF6D58B5);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(6, 17, 34, 28), const Radius.circular(9)),
        p);
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(8, 11, 30, 11), const Radius.circular(5)),
        p..color = const Color(0xFFA995E6));
    final strand = Path()
      ..moveTo(26, 13)
      ..cubicTo(39, 13, 43, 3, 34, 3)
      ..cubicTo(24, 3, 15, 7, 7, 3);
    c.drawPath(
        strand,
        p
          ..color = const Color(0xFF287F76)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round);
    final tooth = Path()
      ..moveTo(23, 27)
      ..cubicTo(11, 21, 15, 36, 18, 39)
      ..quadraticBezierTo(21, 42, 22, 34)
      ..quadraticBezierTo(23, 32, 24, 34)
      ..quadraticBezierTo(25, 42, 28, 39)
      ..cubicTo(31, 36, 35, 21, 23, 27)
      ..close();
    c.drawPath(
        tooth,
        p
          ..style = PaintingStyle.fill
          ..color = Colors.white);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
