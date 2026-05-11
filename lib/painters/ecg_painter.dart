import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Dessine la courbe ECG sur un Canvas Flutter.
///
/// - [realEcgData] non-null et ≥ 2 points → affiche les vraies données BLE
/// - [realEcgData] null ou vide + [isLive] true → ligne plate (en attente de signal)
/// - [realEcgData] null + [isLive] false → animation mathématique simulée (démo)
class EcgPainter extends CustomPainter {
  /// Phase de l'animation (0..5), utilisée uniquement en mode simulation
  final double phase;

  /// true = monitoring en direct (via BLE ou en attente), false = historique simulé
  final bool isLive;

  /// Données réelles du bracelet BLE. null → simulation ou attente.
  final List<double>? realEcgData;

  EcgPainter({
    required this.phase,
    this.isLive = true,
    this.realEcgData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // ── Grille de fond ──────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFF003300)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (int i = 0; i <= 8; i++) {
      final x = w * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // ── Choix du mode de rendu ──────────────────────────────────
    final bool hasRealData = realEcgData != null && realEcgData!.length >= 2;

    if (hasRealData) {
      // ── Mode 1 : données réelles BLE ────────────────────────
      _drawRealEcgData(canvas, size, w, h);
    } else if (isLive) {
      // ── Mode 2 : en attente de signal (ligne plate atténuée) ─
      _drawFlatLine(canvas, w, midY);
    } else {
      // ── Mode 3 : simulation mathématique (démo) ──────────────
      _drawSimulatedEcg(canvas, size, w, h, midY);
    }
  }

  // ── Mode 1 : vraies données BLE ──────────────────────────────

  void _drawRealEcgData(Canvas canvas, Size size, double w, double h) {
    final data = realEcgData!;

    // Normalisation : min/max → 80% de la hauteur du canvas
    final minVal = data.reduce(min);
    final maxVal = data.reduce(max);
    final range = (maxVal - minVal).abs();
    final effectiveRange = range < 0.001 ? 1.0 : range;

    // Nombre de points qui rentrent dans la largeur du canvas
    final int maxPoints = (w / 2).floor().clamp(2, data.length);
    final List<double> visibleData = data.length > maxPoints
        ? data.sublist(data.length - maxPoints)
        : data;

    final ecgPaint = Paint()
      ..color = AppColors.ecgGreen
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final stepX = w / (visibleData.length - 1).clamp(1, visibleData.length);

    for (int i = 0; i < visibleData.length; i++) {
      final x = i * stepX;
      // Normaliser entre 10% et 90% de la hauteur (80% utilisés)
      final normalized = (visibleData[i] - minVal) / effectiveRange;
      final y = h * (0.9 - normalized * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, ecgPaint);

    // Effet glow
    final glowPaint = Paint()
      ..color = AppColors.ecgGreen.withOpacity(0.25)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  // ── Mode 2 : ligne plate (en attente de signal BLE) ──────────

  void _drawFlatLine(Canvas canvas, double w, double midY) {
    final flatPaint = Paint()
      ..color = AppColors.ecgGreen.withOpacity(0.3)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(0, midY), Offset(w, midY), flatPaint);
  }

  // ── Mode 3 : simulation mathématique (fallback démo) ─────────

  void _drawSimulatedEcg(
      Canvas canvas, Size size, double w, double h, double midY) {
    final ecgPaint = Paint()
      ..color = isLive ? AppColors.ecgGreen : const Color(0xFF4CAF50)
      ..strokeWidth = isLive ? 2.5 : 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    const steps = 300;
    bool first = true;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = w * t;
      final phaseOffset = (t * 4 + phase) % 1.0;
      final y = midY - _ecgWaveform(phaseOffset) * (h * 0.42);

      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, ecgPaint);

    if (isLive) {
      final glowPaint = Paint()
        ..color = AppColors.ecgGreen.withOpacity(0.25)
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, glowPaint);
    }
  }

  // ── Forme d'onde ECG simulée (onde P, QRS, T) ────────────────

  double _ecgWaveform(double t) {
    final p = t % 1.0;

    // Onde P (dépolarisation auriculaire)
    if (p < 0.1) {
      return 0.15 * sin(pi * p / 0.1);
    }
    // Segment PR (plat)
    else if (p < 0.18) {
      return 0;
    }
    // Onde Q (petite négative)
    else if (p < 0.22) {
      return -0.1 * sin(pi * (p - 0.18) / 0.04);
    }
    // Onde R (pic principal QRS)
    else if (p < 0.28) {
      return sin(pi * (p - 0.22) / 0.06);
    }
    // Onde S (petite négative)
    else if (p < 0.33) {
      return -0.2 * sin(pi * (p - 0.28) / 0.05);
    }
    // Segment ST (plat)
    else if (p < 0.42) {
      return 0;
    }
    // Onde T (large positive)
    else if (p < 0.60) {
      return 0.35 * sin(pi * (p - 0.42) / 0.18);
    }
    // Diastole (plat)
    else {
      return 0;
    }
  }

  @override
  bool shouldRepaint(EcgPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.isLive != isLive ||
      oldDelegate.realEcgData != realEcgData;
}
