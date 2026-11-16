import 'package:flutter/material.dart';
import 'transport_theme.dart';

/// A responsive vector illustration drawn in Flutter, not a screenshot of UI.
class CampusIllustration extends StatelessWidget {
  const CampusIllustration({super.key});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'University campus and BRACU transport bus illustration',
    image: true,
    child: AspectRatio(
      aspectRatio: 1.65,
      child: CustomPaint(painter: _CampusPainter()),
    ),
  );
}

class _CampusPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 620, size.height / 375);
    void rect(
      double x,
      double y,
      double w,
      double h,
      Color color, [
      double radius = 0,
    ]) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, w, h),
        Radius.circular(radius),
      ),
      Paint()..color = color,
    );
    void line(Offset a, Offset b, Color color, [double width = 2]) =>
        canvas.drawLine(
          a,
          b,
          Paint()
            ..color = color
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round,
        );
    void text(
      String value,
      double x,
      double y,
      double font,
      Color color, {
      FontWeight weight = FontWeight.w600,
    }) {
      final p = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: font,
            color: color,
            fontWeight: weight,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, Offset(x, y));
    }

    canvas.drawOval(
      const Rect.fromLTWH(40, 28, 550, 310),
      Paint()..color = const Color(0xffe9eff9),
    );
    canvas.drawCircle(
      const Offset(481, 67),
      28,
      Paint()..color = const Color(0xfff5e6b9),
    );
    // Campus buildings and bridge.
    rect(276, 70, 84, 210, const Color(0xffccd8e8), 7);
    rect(366, 47, 108, 233, const Color(0xffd8e2ef), 7);
    rect(480, 100, 70, 180, const Color(0xffc5d3e5), 6);
    rect(384, 29, 72, 19, TransportColors.navy, 4);
    text('BRACU', 390, 32, 13, Colors.white);
    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 3; col++) {
        rect(
          289 + col * 22,
          88 + row * 23,
          12,
          13,
          row == 2 ? const Color(0xff9bb5d7) : const Color(0xffa9bdd6),
          2,
        );
      }
      for (int col = 0; col < 4; col++) {
        rect(378 + col * 22, 68 + row * 25, 13, 16, const Color(0xffb2c4db), 2);
      }
    }
    for (int row = 0; row < 6; row++) {
      for (int col = 0; col < 2; col++) {
        rect(
          491 + col * 25,
          117 + row * 23,
          14,
          13,
          const Color(0xff9eb5d1),
          2,
        );
      }
    }
    rect(346, 190, 145, 15, Colors.white, 2);
    rect(411, 242, 29, 38, TransportColors.navy, 3);
    // Road, low greenery and bus stop.
    rect(28, 283, 558, 47, const Color(0xffdbe4ef), 18);
    line(const Offset(47, 307), const Offset(566, 307), Colors.white, 3);
    rect(69, 238, 5, 47, const Color(0xff93adac), 2);
    canvas.drawCircle(
      const Offset(71, 230),
      25,
      Paint()..color = const Color(0xffbad2cc),
    );
    rect(545, 231, 5, 54, const Color(0xff93adac), 2);
    canvas.drawCircle(
      const Offset(548, 222),
      25,
      Paint()..color = const Color(0xffb2cdc5),
    );
    rect(107, 202, 4, 83, TransportColors.navy, 2);
    rect(89, 182, 40, 32, TransportColors.blue, 7);
    text('BUS', 96, 191, 10, Colors.white);
    // White university bus, navy livery, windows and wheels.
    canvas.drawOval(
      const Rect.fromLTWH(132, 293, 295, 22),
      Paint()..color = TransportColors.navy.withValues(alpha: .12),
    );
    rect(129, 182, 291, 115, Colors.white, 20);
    rect(139, 196, 260, 47, TransportColors.navy, 7);
    rect(148, 201, 45, 32, const Color(0xff7998bb), 4);
    rect(199, 201, 45, 32, const Color(0xff7998bb), 4);
    rect(250, 201, 45, 32, const Color(0xff7998bb), 4);
    rect(301, 201, 45, 32, const Color(0xff7998bb), 4);
    rect(354, 201, 37, 64, const Color(0xff7695b8), 4);
    line(
      const Offset(372, 204),
      const Offset(372, 263),
      Colors.white.withValues(alpha: .5),
      1,
    );
    rect(129, 250, 220, 27, TransportColors.blue);
    rect(139, 278, 205, 5, TransportColors.gold, 2);
    text('BRACU TRANSPORT', 148, 255, 12, Colors.white);
    rect(399, 258, 13, 10, TransportColors.gold, 3);
    rect(131, 259, 6, 9, const Color(0xffd79d9d), 2);
    for (final x in [186.0, 363.0]) {
      canvas.drawCircle(
        Offset(x, 293),
        20,
        Paint()..color = TransportColors.navy,
      );
      canvas.drawCircle(
        Offset(x, 293),
        10,
        Paint()..color = const Color(0xffd8e3ef),
      );
      canvas.drawCircle(
        Offset(x, 293),
        4,
        Paint()..color = const Color(0xff91a6c0),
      );
    }
    // A light route annotation: code-native illustration details.
    rect(43, 61, 149, 46, Colors.white, 12);
    canvas.drawCircle(
      const Offset(63, 84),
      7,
      Paint()..color = TransportColors.blue,
    );
    text('CAMPUS CONNECTED', 79, 78, 9, TransportColors.navy);
    line(
      const Offset(192, 84),
      const Offset(224, 84),
      const Color(0xffa9bad0),
      1,
    );
    line(
      const Offset(224, 84),
      const Offset(224, 174),
      const Color(0xffa9bad0),
      1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
