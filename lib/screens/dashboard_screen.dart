import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/ecg_reading.dart';
import '../widgets/status_badge.dart';
import '../widgets/risk_gauge.dart';
import '../widgets/sensor_indicator.dart';
import '../painters/ecg_painter.dart';
import '../services/auth_service.dart';
import 'history_screen.dart'; // ✅ Historique
import 'ecg_screen.dart'; // ✅ AJOUT : Nouvel ECG
import 'emergency_screen.dart'; // ✅ AJOUT : Urgence
import '../screens/map_screen.dart'; // ✅ AJOUT : Carte

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ecgController;
  final _authService = AuthService();
  bool _profileRefreshed = false;

  @override
  void initState() {
    super.initState();
    _ecgController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_profileRefreshed) {
        _refreshProfileIfNeeded();
      }
    });
  }

  @override
  void dispose() {
    _ecgController.dispose();
    super.dispose();
  }

  Future<void> _refreshProfileIfNeeded() async {
    if (_profileRefreshed) return;

    final app = Provider.of<AppProvider>(context, listen: false);
    final userId = _authService.currentUser?.id;

    if (userId != null) {
      final needsRefresh = app.profile.name == 'Chargement...' ||
          app.profile.name == 'Utilisateur' ||
          app.profile.name.isEmpty ||
          app.profile.patientId == '---';

      if (needsRefresh && mounted) {
        try {
          await Future.delayed(const Duration(milliseconds: 100));
          final userData = await _authService.getPatientData(userId);
          if (userData != null && mounted) {
            app.updateProfileFromMap(userData);
            _profileRefreshed = true;
            if (mounted) setState(() {});
          }
        } catch (e) {
          print('❌ [DASHBOARD] Error refreshing profile: $e');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surface,
            toolbarHeight: 70,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child:
                      const Icon(Icons.favorite, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'CAREDIFY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Flexible(
                        child: Text(
                          app.profile.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              Flexible(
                child: SensorIndicator(connected: app.sensorConnected),
              ),
              const SizedBox(width: 8),
            ],
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.border),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DisclaimerBanner(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatusCard(
                          status: app.healthStatus,
                          heartRate: app.heartRate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RiskCard(riskScore: app.riskScore),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EcgPreviewCard(
                    controller: _ecgController,
                    isMonitoring: app.isMonitoring,
                    onStartStop: () {
                      if (app.isMonitoring) {
                        app.stopMonitoring();
                      } else {
                        app.startMonitoring();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Actions rapides',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  _QuickActions(), // ✅✅✅ QuickActions avec navigation ✅✅✅
                  const SizedBox(height: 16),
                  if (app.history.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Dernières mesures',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HistoryScreen()),
                            );
                          },
                          child: const Text('Voir tout'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...app.history.take(3).map((r) => _HistoryItem(reading: r)),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== WIDGETS AUXILIAIRES ====================

class _DisclaimerBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3EDFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Prototype académique — Mode simulé',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final HealthStatus status;
  final int heartRate;

  const _StatusCard({required this.status, required this.heartRate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              const Text(
                'Fréquence',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$heartRate',
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  'bpm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StatusBadge(status: status),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final int riskScore;
  const _RiskCard({required this.riskScore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Score de risque',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          RiskGauge(score: riskScore, size: 120),
        ],
      ),
    );
  }
}

class _EcgPreviewCard extends StatelessWidget {
  final AnimationController controller;
  final bool isMonitoring;
  final VoidCallback onStartStop;

  const _EcgPreviewCard({
    required this.controller,
    required this.isMonitoring,
    required this.onStartStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isMonitoring ? AppColors.ecgBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.show_chart_rounded,
                      size: 18,
                      color: isMonitoring
                          ? AppColors.ecgGreen
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ECG en direct',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isMonitoring
                            ? AppColors.ecgGreen
                            : AppColors.textPrimary,
                      ),
                    ),
                    if (isMonitoring) ...[
                      const SizedBox(width: 8),
                      _LiveDot(),
                    ],
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: onStartStop,
                  icon: Icon(
                    isMonitoring
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(isMonitoring ? 'Arrêter' : 'Démarrer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isMonitoring ? AppColors.critical : AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: controller,
            builder: (context, _) => SizedBox(
              height: 100,
              child: CustomPaint(
                painter: EcgPainter(
                  phase: controller.value * 4,
                  isLive: isMonitoring,
                ),
                size: const Size(double.infinity, 100),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AppColors.ecgGreen.withOpacity(_c.value),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ==================== ✅✅✅ _QuickActions AVEC NAVIGATION COMPLÈTE ✅✅✅ ====================

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      // ✅ NOUVEL ECG - Navigation vers EcgScreen
      _QuickAction(
          icon: Icons.show_chart_rounded,
          label: 'Nouvel ECG',
          color: AppColors.primary,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EcgScreen()),
            );
          }),
      // ✅ URGENCE - Navigation vers EmergencyScreen
      _QuickAction(
          icon: Icons.emergency_rounded,
          label: 'Urgence',
          color: AppColors.emergency,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyScreen()),
            );
          }),
      // ✅ CARTE - Navigation vers MapScreen
      _QuickAction(
          icon: Icons.map_rounded,
          label: 'Carte',
          color: const Color(0xFF2E7D32),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MapScreen()),
            );
          }),
      // ✅ HISTORIQUE - Navigation vers HistoryScreen
      _QuickAction(
          icon: Icons.history_rounded,
          label: 'Historique',
          color: const Color(0xFF6A1B9A),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            );
          }),
    ];

    return Row(
      children: actions.map((a) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: a.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: a.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: a.color.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Icon(a.icon, color: a.color, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: a.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ==================== _QuickAction ====================

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });
}

// ==================== _HistoryItem ====================

class _HistoryItem extends StatelessWidget {
  final EcgReading reading;
  const _HistoryItem({required this.reading});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: reading.status == HealthStatus.normal
                  ? AppColors.normalLight
                  : reading.status == HealthStatus.suspect
                      ? AppColors.warningLight
                      : AppColors.criticalLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.monitor_heart_rounded,
              size: 22,
              color: reading.status == HealthStatus.normal
                  ? AppColors.normal
                  : reading.status == HealthStatus.suspect
                      ? AppColors.warning
                      : AppColors.critical,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reading.heartRate} bpm',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(
                  _formatDate(reading.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(status: reading.status),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays}j';
  }
}
