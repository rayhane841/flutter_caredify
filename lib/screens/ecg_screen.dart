import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../painters/ecg_painter.dart';

class EcgScreen extends StatefulWidget {
  const EcgScreen({super.key});

  @override
  State<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final isMonitoring = app.isMonitoring;

        return Scaffold(
          backgroundColor: isMonitoring ? AppColors.ecgBackground : AppColors.background,
          appBar: AppBar(
            backgroundColor: isMonitoring ? AppColors.ecgBackground : AppColors.surface,
            title: Text(
              'ECG en direct',
              style: TextStyle(
                color: isMonitoring ? AppColors.ecgGreen : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            iconTheme: IconThemeData(
              color: isMonitoring ? AppColors.ecgGreen : AppColors.textPrimary,
            ),
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isMonitoring ? const Color(0xFF003300) : AppColors.border,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
              // ECG Waveform
              Expanded(
                flex: 3,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.ecgBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isMonitoring
                                ? AppColors.ecgGreen.withOpacity(0.3)
                                : const Color(0xFF003300),
                          ),
                        ),
                        child: CustomPaint(
                          painter: EcgPainter(
                            phase: _controller.value * 5,
                            isLive: isMonitoring,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Stats row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _StatTile(
                      label: 'Fréq. cardiaque',
                      value: '${app.heartRate}',
                      unit: 'bpm',
                      icon: Icons.favorite_rounded,
                      color: AppColors.critical,
                      active: isMonitoring,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'Qualité signal',
                      value: '94',
                      unit: '%',
                      icon: Icons.signal_cellular_4_bar_rounded,
                      color: AppColors.normal,
                      active: isMonitoring,
                    ),
                    const SizedBox(width: 10),
                    _StatTile(
                      label: 'Score risque',
                      value: '${app.riskScore}',
                      unit: '/100',
                      icon: Icons.shield_rounded,
                      color: AppColors.primary,
                      active: isMonitoring,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Leads info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isMonitoring
                        ? const Color(0xFF0A1A0A)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isMonitoring
                          ? const Color(0xFF003300)
                          : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _LeadInfo(label: 'Dérivation', value: 'DI', active: isMonitoring),
                      _LeadInfo(label: 'Intervalle PR', value: '162 ms', active: isMonitoring),
                      _LeadInfo(label: 'QRS', value: '88 ms', active: isMonitoring),
                      _LeadInfo(label: 'QT', value: '412 ms', active: isMonitoring),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // AI Analysis
              if (isMonitoring)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1A0A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.ecgGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.ecgGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.psychology_rounded,
                              color: AppColors.ecgGreen, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Analyse IA en cours...',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ecgGreen,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Rythme sinusal normal détecté',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Start/Stop button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (app.isMonitoring) {
                        app.stopMonitoring();
                      } else {
                        app.startMonitoring();
                      }
                    },
                    icon: Icon(
                      isMonitoring ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 24,
                    ),
                    label: Text(
                      isMonitoring ? 'Arrêter l\'enregistrement' : 'Démarrer l\'ECG',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMonitoring ? AppColors.critical : AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 100),
            ],
          ),
        ),
      );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool active;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0A1A0A) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? color.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                color: active ? const Color(0xFF4CAF50) : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: active ? const Color(0xFF4CAF50) : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool active;

  const _LeadInfo({required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: active ? AppColors.ecgGreen : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
