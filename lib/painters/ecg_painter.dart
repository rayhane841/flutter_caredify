import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class EcgPainter extends CustomPainter {//cette classe est responsable de dessiner la courbe ECG animée sur un canvas Flutter 
  final double phase;//phase de l'animation pour faire bouger la courbe ecg de gauche a droite en contenu 
  final bool isLive;//indique si le monitoring est en direct ou si c'est une lecture historique pour ajuster les couleurs et les styles de dessin

  EcgPainter({required this.phase, this.isLive = true});//contructeur de la classe ecgPainter qui prend en parametre la phase et une boolean pour indiquer si c'est en direction ou pas (par defaut c'est en direction)

  @override//la methode paint est la ou on dessine la courbe ecg sur le canvas en utilisant les proprietes de phase et islive (en direct ou historique)
  void paint(Canvas canvas, Size size) {
    final w = size.width;//largeur du canvas pour ajuster le dessin de la courbe ecg en fonction de la taille diponible 
    final h = size.height;//haueur du canvas pour ajuster le dessin de la courbe ecg en fonction de taille 
    final midY = h / 2;//positiion va=erticale centrale du  canvas pour centrer la courbe ecg verticalement 

    // Grid lines
    final gridPaint = Paint()//pour dessiner les lignes de la grille de fond du canvas pour aider a visualiser les mesuresde la courbe ecg
      ..color = const Color(0xFF003300)//une couleur vert fonce pour les lignes de la grille 
      ..strokeWidth = 0.5//une epaisseur fine pour les lignes de la grille 
      ..style = PaintingStyle.stroke;//on dessine les lignes de la grille en  utilisant le style stroke pour ne pas remplir 

    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
    for (int i = 0; i <= 8; i++) {
      final x = w * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }

    // ECG waveform
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

    // glow effect for live monitiring 
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

  double _ecgWaveform(double t) {//une fonction pour generer les valeurs de la courbe ecg en fonction de la phase t qui varie de 0 a 1
  
    final p = t % 1.0;

    // P wave (atrial depolarization)
    if (p < 0.1) {
      return 0.15 * sin(pi * p / 0.1);
    }
    // PR segment (flat)
    else if (p < 0.18) {
      return 0;
    }
    // Q wave (small negative)
    else if (p < 0.22) {
      return -0.1 * sin(pi * (p - 0.18) / 0.04);
    }
    // R wave (tall positive spike - main QRS)
    else if (p < 0.28) {
      return sin(pi * (p - 0.22) / 0.06);
    }
    // S wave (small negative)
    else if (p < 0.33) {
      return -0.2 * sin(pi * (p - 0.28) / 0.05);
    }
    // ST segment (flat)
    else if (p < 0.42) {
      return 0;
    }
    // T wave (broad positive)
    else if (p < 0.60) {
      return 0.35 * sin(pi * (p - 0.42) / 0.18);
    }
    // Diastole (flat)
    else {
      return 0;
    }
  }

  @override
  bool shouldRepaint(EcgPainter oldDelegate) =>//cette methodes indique a flutter si il doit redessiner le canvas lorsque les proprietes de l'ecgPainters 
      oldDelegate.phase != phase || oldDelegate.isLive != isLive;
}
//Dessine la courbe ECG animée (onde P, QRS, T) pixel par pixel sur un Canvas Flutter
