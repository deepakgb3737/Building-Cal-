import 'package:grid_ceiling_calculator/ui/app_colors.dart';
import 'package:grid_ceiling_calculator/ui/app_theme.dart';
import 'package:grid_ceiling_calculator/features/compass/logic/compass_controller.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});

  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  final _compass = CompassController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compass'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.softSurface),
        child: SafeArea(
          child: StreamBuilder<CompassEvent>(
            stream: FlutterCompass.events,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _StatusView(
                  title: 'Compass unavailable',
                  message:
                      'Enable sensors/location and try again on a supported device.',
                );
              }
              if (!snapshot.hasData || snapshot.data?.heading == null) {
                return const _StatusView(
                  title: 'Initializing...',
                  message: 'Move phone in an 8-shape for calibration.',
                );
              }

              final raw = snapshot.data!.heading!;
              final heading = _compass.smooth(raw);
              _compass.heading = heading;
              _compass.updateTurns(heading);
              final degree = heading.toStringAsFixed(0);
              final shortDir = _compass.cardinal(heading);
              final fullDir = _compass.fullCardinal(shortDir);

              return LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth < 360 || constraints.maxHeight < 700;
                  final minSide =
                      math.min(constraints.maxWidth, constraints.maxHeight);
                  final dialSize = minSide * (compact ? 0.72 : 0.76);
                  final degreeSize = compact ? 48.0 : 60.0;

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 12 : 16,
                      compact ? 8 : 10,
                      compact ? 12 : 16,
                      compact ? 12 : 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$degree°',
                          style: AppTypography.textW500Text
                              .copyWith(fontSize: degreeSize),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$fullDir • $shortDir',
                          style: AppTypography.text14W500Secondarymuted,
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: Center(
                            child: SizedBox(
                              width: dialSize,
                              height: dialSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.keyBorder,
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.black
                                              .withValues(alpha: 0.08),
                                          blurRadius: 14,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: AnimatedRotation(
                                      turns: _compass.turns,
                                      duration:
                                          const Duration(milliseconds: 140),
                                      curve: Curves.linear,
                                      child: CustomPaint(
                                        size: Size.square(dialSize),
                                        painter: _IosDialPainter(),
                                      ),
                                    ),
                                  ),
                                  CustomPaint(
                                    size: Size.square(dialSize * 0.32),
                                    painter: _NeedlePainter(),
                                  ),
                                  CustomPaint(
                                    size: Size.square(dialSize * 0.16),
                                    painter: _CenterCrossPainter(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Keep phone flat and away from metal objects',
                          textAlign: TextAlign.center,
                          style: AppTypography.text12Muted,
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IosDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final fill = Paint()
      ..shader = const RadialGradient(
        colors: [AppColors.white, AppColors.surfaceAlt],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fill);

    final ring = Paint()
      ..color = AppColors.compassBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    canvas.drawCircle(center, radius * 0.82, ring);
    canvas.drawCircle(
        center, radius * 0.64, ring..color = AppColors.drawingSurfaceBorder);

    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.2
      ..color = AppColors.compassMuted;

    for (int d = 0; d < 360; d += 5) {
      final angle = (d - 90) * math.pi / 180;
      final isMajor = d % 30 == 0;
      final isCardinal = d % 90 == 0;
      final start = isCardinal
          ? radius * 0.68
          : isMajor
              ? radius * 0.74
              : radius * 0.79;
      final end = radius * 0.88;
      tickPaint.color = isCardinal
          ? AppColors.muted
          : isMajor
              ? AppColors.faintText
              : AppColors.drawingBorder;

      final p1 = Offset(
        center.dx + math.cos(angle) * start,
        center.dy + math.sin(angle) * start,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * end,
        center.dy + math.sin(angle) * end,
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    _drawLabel(canvas, size, 'N', -90, radius, AppColors.errorBright);
    _drawLabel(canvas, size, 'E', 0, radius, AppColors.secondaryText);
    _drawLabel(canvas, size, 'S', 90, radius, AppColors.secondaryText);
    _drawLabel(canvas, size, 'W', 180, radius, AppColors.secondaryText);
  }

  void _drawLabel(
    Canvas canvas,
    Size size,
    String label,
    double degree,
    double radius,
    Color color,
  ) {
    final center = size.center(Offset.zero);
    final angle = degree * math.pi / 180;
    final pos = Offset(
      center.dx + math.cos(angle) * (radius * 0.55),
      center.dy + math.sin(angle) * (radius * 0.55),
    );
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: AppTypography.textW600
            .copyWith(color: color, fontSize: radius * 0.11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NeedlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final top = Path()
      ..moveTo(center.dx, size.height * 0.02)
      ..lineTo(center.dx - size.width * 0.09, center.dy)
      ..lineTo(center.dx + size.width * 0.09, center.dy)
      ..close();
    final bottom = Path()
      ..moveTo(center.dx, size.height * 0.98)
      ..lineTo(center.dx - size.width * 0.08, center.dy)
      ..lineTo(center.dx + size.width * 0.08, center.dy)
      ..close();

    canvas.drawPath(top, Paint()..color = AppColors.errorBright);
    canvas.drawPath(bottom, Paint()..color = AppColors.secondaryMuted);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final line = Paint()
      ..color = AppColors.secondaryText
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.4;
    canvas.drawCircle(
      center,
      size.width * 0.46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.strongBorder,
    );
    canvas.drawLine(
      Offset(center.dx - size.width * 0.2, center.dy),
      Offset(center.dx + size.width * 0.2, center.dy),
      line,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - size.height * 0.2),
      Offset(center.dx, center.dy + size.height * 0.2),
      line,
    );
    canvas.drawCircle(
        center, size.width * 0.035, Paint()..color = AppColors.secondaryText);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.text18W700Text,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.text14Secondarymuted,
            ),
          ],
        ),
      ),
    );
  }
}
