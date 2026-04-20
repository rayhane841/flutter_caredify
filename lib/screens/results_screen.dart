import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/ecg_reading.dart';
import '../widgets/status_badge.dart';
import '../widgets/risk_gauge.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final reading = app.lastReading;
        if (reading == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: const Text('Résultats'),
              backgroundColor: AppColors.surface,
              elevation: 0,
            ),
            body: SafeArea(
              top: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monitor_heart_outlined, size: 64, color: AppColors.textHint),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune mesure récente',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Lancez un enregistrement ECG\npour voir vos résultats',
                      style: TextStyle(fontSize: 14, color: AppColors.textHint),
                      textAlign: TextAlign.center,
                    ),
                  ], // ← Ferme children: []
                ), // ← Ferme Column
              ), // ← Ferme Center
            ), // ← Ferme SafeArea
          ); // ← ✅ Ferme return Scaffold (premier)
        }
        return _ResultDetail(reading: reading);
      }, // ← Ferme builder: (context, app, _)
    ); // ← ✅ Ferme return Consumer<AppProvider>
  } // ← Ferme Widget build
}

// ==================== _ResultDetail ====================

class _ResultDetail extends StatelessWidget {
  final EcgReading reading;
  const _ResultDetail({required this.reading});

  Color get _bgColor {
    switch (reading.status) {
      case HealthStatus.normal:
        return AppColors.normalLight;
      case HealthStatus.suspect:
        return AppColors.warningLight;
      case HealthStatus.critical:
        return AppColors.criticalLight;
    }
  }

  Color get _mainColor {
    switch (reading.status) {
      case HealthStatus.normal:
        return AppColors.normal;
      case HealthStatus.suspect:
        return AppColors.warning;
      case HealthStatus.critical:
        return AppColors.critical;
    }
  }

  String get _headline {
    switch (reading.status) {
      case HealthStatus.normal:
        return 'Rythme normal';
      case HealthStatus.suspect:
        return 'Anomalie détectée';
      case HealthStatus.critical:
        return 'Alerte critique';
    }
  }

  String get _description {
    switch (reading.status) {
      case HealthStatus.normal:
        return 'Votre rythme cardiaque est normal et régulier. Votre ECG ne montre pas d\'anomalie. Continuez à surveiller régulièrement.';
      case HealthStatus.suspect:
        return 'Une irrégularité cardiaque a été détectée. L\'IA a signalé ce résultat à votre cardiologue pour validation. Évitez l\'effort physique.';
      case HealthStatus.critical:
        return 'Une anomalie grave a été détectée. Votre cardiologue est alerté en urgence. Restez calme et allongé(e). Les secours peuvent être déclenchés.';
    }
  }

  IconData get _icon {
    switch (reading.status) {
      case HealthStatus.normal:
        return Icons.check_circle_rounded;
      case HealthStatus.suspect:
        return Icons.warning_amber_rounded;
      case HealthStatus.critical:
        return Icons.dangerous_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Résultats ECG'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _mainColor.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(_icon, size: 60, color: _mainColor),
                    const SizedBox(height: 12),
                    Text(
                      _headline,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _mainColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    StatusBadge(status: reading.status, large: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Metrics row
              Row(
                children: [
                  _MetricCard(
                    label: 'Fréquence cardiaque',
                    value: '${reading.heartRate}',
                    unit: 'bpm',
                    icon: Icons.favorite_rounded,
                    color: AppColors.critical,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    label: 'Score de risque',
                    value: '${reading.riskScore}',
                    unit: '/100',
                    icon: Icons.shield_rounded,
                    color: _mainColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _MetricCard(
                    label: 'Durée mesure',
                    value: '${reading.durationSeconds}',
                    unit: 'sec',
                    icon: Icons.timer_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  _MetricCard(
                    label: 'Qualité signal',
                    value: '94',
                    unit: '%',
                    icon: Icons.signal_cellular_4_bar_rounded,
                    color: AppColors.normal,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Risk gauge
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Score de risque cardiovasculaire',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    RiskGauge(score: reading.riskScore, size: 160),
                    const SizedBox(height: 16),
                    const Text(
                      'Calculé par l\'IA à partir de votre ECG,\nvotre historique et vos facteurs de risque',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // AI Analysis
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1A0A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.psychology_rounded, color: AppColors.ecgGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Analyse IA',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ecgGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...[
                      _AiLine(label: 'Rythme', value: 'Sinusal', ok: true),
                      _AiLine(label: 'Intervalle PR', value: '162 ms (N)', ok: true),
                      _AiLine(label: 'Complexe QRS', value: '88 ms (N)', ok: true),
                      _AiLine(label: 'Intervalle QT', value: '412 ms (N)', ok: reading.status == HealthStatus.normal),
                      _AiLine(label: 'Segment ST', value: reading.status == HealthStatus.normal ? 'Isoélectrique' : 'Sous-décalage ≥ 1mm', ok: reading.status == HealthStatus.normal),
                    ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _mainColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _mainColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            reading.status == HealthStatus.normal
                                ? Icons.verified_rounded
                                : Icons.pending_rounded,
                            color: _mainColor,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            reading.status == HealthStatus.normal
                                ? 'Validé par Dr. Lefebvre'
                                : 'En attente de validation cardiologue',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _mainColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Recommendations
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recommandations',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ..._recommendations.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: _mainColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  r,
                                  style: const TextStyle(fontSize: 14, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 100),
            ], // ← Ferme children: []
          ), // ← Ferme Column
        ), // ← Ferme SingleChildScrollView
      ), // ← Ferme SafeArea
    ); // ← ✅ Ferme return Scaffold (deuxième)
  } // ← Ferme Widget build de _ResultDetail

  List<String> get _recommendations {
    switch (reading.status) {
      case HealthStatus.normal:
        return [
          'Continuez votre surveillance régulière',
          'Maintenez votre traitement anticoagulant',
          'Évitez la caféine excessive',
          'Prochain RDV : voir avec Dr. Lefebvre',
        ];
      case HealthStatus.suspect:
        return [
          'Evitez tout effort physique',
          'Restez allongé(e) et au repos',
          'Gardez votre téléphone à portée',
          'Contactez Dr. Lefebvre dès que possible',
        ];
      case HealthStatus.critical:
        return [
          'Restez allongé(e) immédiatement',
          'Alertez une personne proche si possible',
          'Ne prenez aucun médicament supplémentaire',
          'Appuyez sur le bouton Urgence si nécessaire',
        ];
    }
  }
}

// ==================== _MetricCard ====================

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(
                    unit,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ==================== _AiLine ====================

class _AiLine extends StatelessWidget {
  final String label;
  final String value;
  final bool ok;

  const _AiLine({required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_rounded : Icons.warning_rounded,
            size: 16,
            color: ok ? AppColors.ecgGreen : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4CAF50)),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ok ? Colors.white : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}