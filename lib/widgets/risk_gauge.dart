import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RiskGauge extends StatelessWidget {
  final int score;
  final double size;

  const RiskGauge({super.key, required this.score, this.size = 160});

  Color get _color {
    if (score < 35) return AppColors.normal;
    if (score < 65) return AppColors.warning;
    return AppColors.critical;
  }

  String get _label {
    if (score < 35) return 'Faible';
    if (score < 65) return 'Modéré';
    return 'Élevé';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _GaugePainter(score: score, color: _color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$score',
                style: TextStyle(
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w800,
                  color: _color,
                  letterSpacing: -1,
                ),
              ),
              Text(
                '/100',
                style: TextStyle(
                  fontSize: size * 0.1,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _label,
                  style: TextStyle(
                    fontSize: size * 0.09,
                    fontWeight: FontWeight.w600,
                    color: _color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const startAngle = 2.35;
    const sweepAngle = 4.71;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Gradient fill arc
    final fillPaint = Paint()
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: score < 35
            ? [const Color(0xFF66BB6A), AppColors.normal]
            : score < 65
                ? [const Color(0xFFFFB74D), AppColors.warning]
                : [const Color(0xFFEF9A9A), AppColors.critical],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final fillSweep = sweepAngle * (score / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fillSweep,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.score != score || old.color != color;
}
