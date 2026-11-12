import 'dart:math' as math;
import 'package:flutter/material.dart';

const ink = Color(0xFF183E38);
const green = Color(0xFF257A64);

class TeethPainter extends CustomPainter {
  final bool mascot;
  final bool night;
  final int active;
  final List<bool> done;
  final double? brush;
  const TeethPainter(
      {this.mascot = false,
      this.night = false,
      this.active = -1,
      this.done = const [false, false, false, false],
      this.brush});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final scale = math.min(size.width / 340, size.height / 230);
    canvas.scale(scale);
    final paint = Paint();
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(-167, -113, 334, 226),
            const Radius.circular(38)),
        paint
          ..color = night ? const Color(0xFFDDDDF3) : const Color(0xFFFFF3CF));
    if (night) {
      canvas.drawCircle(
          const Offset(125, -83), 16, paint..color = const Color(0xFFFFF5C8));
      canvas.drawCircle(
          const Offset(133, -89), 14, paint..color = const Color(0xFFDDDDF3));
      for (final star in [
        const Offset(-130, -82),
        const Offset(-105, 65),
        const Offset(128, 69)
      ]) {
        canvas.drawLine(
            star - const Offset(5, 0),
            star + const Offset(5, 0),
            paint
              ..color = Colors.white
              ..strokeWidth = 2);
        canvas.drawLine(
            star - const Offset(0, 5), star + const Offset(0, 5), paint);
      }
    } else {
      canvas.drawCircle(
          const Offset(125, -83), 13, paint..color = const Color(0xFFF4C35A));
      for (int i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final direction = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(const Offset(125, -83) + direction * 18,
            const Offset(125, -83) + direction * 23, paint..strokeWidth = 2.5);
      }
    }
    if (mascot) {
      canvas.drawOval(
          Rect.fromCenter(center: const Offset(0, 88), width: 150, height: 15),
          paint..color = const Color(0xFFD2E3CD));
      final tooth = Path()
        ..moveTo(0, -67)
        ..cubicTo(-90, -102, -90, -15, -62, 25)
        ..cubicTo(-55, 43, -55, 93, -32, 87)
        ..cubicTo(-16, 85, -22, 33, 0, 33)
        ..cubicTo(22, 33, 16, 85, 32, 87)
        ..cubicTo(55, 93, 55, 43, 62, 25)
        ..cubicTo(90, -15, 90, -102, 0, -67)
        ..close();
      canvas.drawPath(
          tooth, paint..color = night ? const Color(0xFFF3F1FF) : Colors.white);
      canvas.drawPath(
          tooth,
          paint
            ..color = const Color(0xFFA9C9B8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      paint.style = PaintingStyle.fill;
      for (final x in [-24.0, 24.0]) {
        canvas.drawCircle(Offset(x, -13), 7, paint..color = ink);
        canvas.drawCircle(Offset(x - 2, -15), 2.3, paint..color = Colors.white);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(x * 1.5, 1), width: 19, height: 9),
            paint..color = const Color(0xFFF4B7AE));
      }
      canvas.drawArc(
          const Rect.fromLTWH(-12, -8, 24, 22),
          0,
          math.pi,
          false,
          paint
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      paint.style = PaintingStyle.fill;
      for (final p in [
        const Offset(-115, -55),
        const Offset(112, 24),
        const Offset(100, -78)
      ]) {
        canvas.drawCircle(p, 5, paint..color = const Color(0xFFE1B24B));
      }
      if (brush != null) {
        final x = math.sin(brush! * math.pi * 2) * 12;
        final y = math.cos(brush! * math.pi * 2) * 7;
        canvas.save();
        canvas.translate(x, y + 10);
        canvas.rotate(-0.2);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                const Rect.fromLTWH(-12, 0, 122, 12), const Radius.circular(6)),
            paint..color = green);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(-23, -13, 38, 20),
                const Radius.circular(5)),
            paint..color = const Color(0xFF9EDDD0));
        for (int i = 0; i < 6; i++) {
          canvas.drawLine(
              Offset(-18 + i * 5, -12),
              Offset(-18 + i * 5, 0),
              paint
                ..color = Colors.white
                ..strokeWidth = 2);
        }
        canvas.restore();
      }
    } else {
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-157, -95, 314, 180),
              const Radius.circular(70)),
          paint..color = const Color(0xFFF4BDBE));
      canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(-143, -77, 286, 144),
              const Radius.circular(55)),
          paint..color = const Color(0xFFB86F83));
      for (int row = 0; row < 2; row++) {
        for (int col = 0; col < 8; col++) {
          final section = row * 2 + (col < 4 ? 1 : 0);
          final x = -133.0 + col * 34;
          final curve = ((col - 3.5).abs() / 3.5) * 16;
          final y = row == 0 ? -74 + curve : 9 - curve;
          final rect = RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, 30, 58), const Radius.circular(10));
          canvas.drawRRect(
              rect,
              paint
                ..color = done[section]
                    ? const Color(0xFFA9DEBA)
                    : section == active
                        ? const Color(0xFFF9DA83)
                        : night
                            ? const Color(0xFFF3F1FF)
                            : const Color(0xFFFFFEF4));
          canvas.drawRRect(
              rect,
              paint
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4
                ..color = const Color(0xFFC99A8B));
          paint.style = PaintingStyle.fill;
          // Tiny faces make every tooth a cheerful character.
          for (final eyeX in [x + 10, x + 20]) {
            canvas.drawCircle(Offset(eyeX, y + 24), 2.2, paint..color = ink);
            canvas.drawCircle(
                Offset(eyeX - 0.5, y + 23.4), 0.7, paint..color = Colors.white);
          }
          canvas.drawOval(Rect.fromLTWH(x + 3, y + 29, 7, 4),
              paint..color = const Color(0xFFF4AAB8));
          canvas.drawOval(Rect.fromLTWH(x + 21, y + 29, 7, 4),
              paint..color = const Color(0xFFF4AAB8));
          canvas.drawArc(
              Rect.fromLTWH(x + 11, y + 29, 8, 6),
              0,
              math.pi,
              false,
              paint
                ..color = ink
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.4);
          paint.style = PaintingStyle.fill;
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x + 5, y + 5, 13, 4), const Radius.circular(2)),
              paint..color = Colors.white.withValues(alpha: 0.8));
        }
      }
      canvas.drawCircle(const Offset(-20, -101), 4, paint..color = ink);
      canvas.drawCircle(const Offset(20, -101), 4, paint..color = ink);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TeethPainter oldDelegate) => true;
}
