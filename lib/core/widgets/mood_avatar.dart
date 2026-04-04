import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sleep_dorm_app/app/theme/night_mood_theme.dart';
import 'package:sleep_dorm_app/core/models/app_models.dart';

class MoodAvatar extends StatelessWidget {
  const MoodAvatar({
    super.key,
    required this.mood,
    required this.size,
    this.fillColor,
  });

  final NightMood mood;
  final double size;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final NightMoodPalette palette = NightMoodPalette.fromMood(mood);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: MoodAvatarPainter(
          mood: mood,
          fillColor: fillColor ?? palette.welcomeFaceColor,
        ),
      ),
    );
  }
}

class MoodAvatarPainter extends CustomPainter {
  MoodAvatarPainter({required this.mood, required this.fillColor});

  final NightMood mood;
  final Color fillColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final Paint facePaint = Paint()..color = fillColor;
    final Paint strokePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.017
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, facePaint);

    switch (mood) {
      case NightMood.happy:
        _drawHappy(canvas, size, strokePaint);
      case NightMood.sad:
        _drawSad(canvas, size, strokePaint);
      case NightMood.calm:
        _drawCalm(canvas, size, strokePaint);
    }
  }

  void _drawHappy(Canvas canvas, Size size, Paint strokePaint) {
    final Offset leftEye = Offset(size.width * 0.34, size.height * 0.38);
    final Offset rightEye = Offset(size.width * 0.66, size.height * 0.38);
    final Paint eyePaint = Paint()..color = Colors.black;

    canvas.drawCircle(leftEye, size.width * 0.028, eyePaint);
    canvas.drawCircle(rightEye, size.width * 0.028, eyePaint);

    final Path nosePath = Path()
      ..moveTo(size.width * 0.50, size.height * 0.40)
      ..lineTo(size.width * 0.50, size.height * 0.53)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.60,
        size.width * 0.56,
        size.height * 0.60,
      );
    canvas.drawPath(nosePath, strokePaint);

    final Rect mouthRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.69),
      width: size.width * 0.38,
      height: size.height * 0.18,
    );
    canvas.drawArc(
      mouthRect,
      math.pi * 0.12,
      math.pi * 0.76,
      false,
      strokePaint,
    );
  }

  void _drawSad(Canvas canvas, Size size, Paint strokePaint) {
    final Path leftEye = Path()
      ..moveTo(size.width * 0.29, size.height * 0.42)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.45,
        size.width * 0.39,
        size.height * 0.43,
      );
    final Path rightEye = Path()
      ..moveTo(size.width * 0.61, size.height * 0.43)
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.45,
        size.width * 0.71,
        size.height * 0.42,
      );
    canvas.drawPath(leftEye, strokePaint);
    canvas.drawPath(rightEye, strokePaint);

    final Path nosePath = Path()
      ..moveTo(size.width * 0.50, size.height * 0.34)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.50,
        size.width * 0.55,
        size.height * 0.58,
      );
    canvas.drawPath(nosePath, strokePaint);

    final Rect mouthRect = Rect.fromCenter(
      center: Offset(size.width * 0.50, size.height * 0.72),
      width: size.width * 0.22,
      height: size.height * 0.08,
    );
    canvas.drawArc(
      mouthRect,
      math.pi * 1.10,
      math.pi * 0.86,
      false,
      strokePaint,
    );
  }

  void _drawCalm(Canvas canvas, Size size, Paint strokePaint) {
    final Path leftEye = Path()
      ..moveTo(size.width * 0.27, size.height * 0.40)
      ..quadraticBezierTo(
        size.width * 0.34,
        size.height * 0.44,
        size.width * 0.41,
        size.height * 0.40,
      );
    final Path rightEye = Path()
      ..moveTo(size.width * 0.59, size.height * 0.40)
      ..quadraticBezierTo(
        size.width * 0.66,
        size.height * 0.44,
        size.width * 0.73,
        size.height * 0.40,
      );
    canvas.drawPath(leftEye, strokePaint);
    canvas.drawPath(rightEye, strokePaint);

    final Path nosePath = Path()
      ..moveTo(size.width * 0.52, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.48,
        size.height * 0.48,
        size.width * 0.56,
        size.height * 0.58,
      );
    canvas.drawPath(nosePath, strokePaint);

    final Path mouthPath = Path()
      ..moveTo(size.width * 0.41, size.height * 0.68)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.72,
        size.width * 0.60,
        size.height * 0.66,
      );
    canvas.drawPath(mouthPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant MoodAvatarPainter oldDelegate) {
    return oldDelegate.mood != mood || oldDelegate.fillColor != fillColor;
  }
}
