import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import '../models/ecg_reading.dart';
import '../widgets/status_badge.dart';
import '../widgets/risk_gauge.dart';
import '../widgets/sensor_indicator.dart';
import '../painters/ecg_painter.dart';
import '../services/auth_service.dart';
import 'history_screen.dart';
import 'ecg_screen.dart';
import 'map_screen.dart';
import 'messages_screen.dart'; // ← import Messages

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
      if (mounted && !_profileRefreshed) _refreshProfileIfNeeded();
      // ── Démarrage automatique du scan BLE dès l'ouverture du dashboard ──
      final app = Provider.of<AppProvider>(context, listen: false);
      if (app.bleStatus == 'idle') {
        app.startAutoScan();
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
        final bg = ThemeHelper.background(context);
        final surface = ThemeHelper.surface(context);
        final border = ThemeHelper.border(context);
        final textPri = ThemeHelper.textPrimary(context);
        final textSec = ThemeHelper.textSecondary(context);
        final primary = ThemeHelper.primary;

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: surface,
            foregroundColor: textPri,
            toolbarHeight: 70,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: primary,
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: textSec,
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
              Flexible(child: SensorIndicator(connected: app.sensorConnected)),
              const SizedBox(width: 8),
            ],
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: border),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Bannière disclaimer ─────────────────
                  _DisclaimerBanner(textPrimary: textPri, primary: primary),
                  const SizedBox(height: 12),

                  // ── Carte statut BLE Movesense (toujours visible) ────
                  _BleStatusCard(
                    bleStatus: app.bleStatus,
                    deviceName: app.connectedDeviceName,
                    onTapEcg: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EcgScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Bannière alerte IA active ───────────
                  if (app.aiAlertPending ||
                      app.emergencyState != EmergencyState.none)
                    _AiAlertBanner(
                      app: app,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MessagesScreen(),
                        ),
                      ),
                    ),

                  if (app.aiAlertPending ||
                      app.emergencyState != EmergencyState.none)
                    const SizedBox(height: 12),

                  // ── Cartes statut + risque ──────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatusCard(
                          status: app.healthStatus,
                          heartRate: app.heartRate,
                          textPrimary: textPri,
                          textSecondary: textSec,
                          surface: surface,
                          border: border,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _RiskCard(
                        riskScore: app.riskScore,
                        textSecondary: textSec,
                        surface: surface,
                        border: border,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── ECG preview ─────────────────────────
                  _EcgPreviewCard(
                    controller: _ecgController,
                    isMonitoring: app.isMonitoring,
                    bleStatus: app.bleStatus,
                    realEcgData: app.realEcgData.isEmpty ? null : app.realEcgData,
                    textPrimary: textPri,
                    border: border,
                  ),
                  const SizedBox(height: 16),

                  // ── Actions rapides ─────────────────────
                  Text(
                    'Actions rapides',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPri,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _QuickActions(primary: primary),
                  const SizedBox(height: 16),

                  // ── Historique ──────────────────────────
                  if (app.history.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dernières mesures',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textPri,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen()),
                          ),
                          child: Text('Voir tout',
                              style: TextStyle(color: primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...app.history.take(3).map(
                          (r) => _HistoryItem(
                            reading: r,
                            textPrimary: textPri,
                            textSecondary: textSec,
                            surface: surface,
                            border: border,
                          ),
                        ),
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

// ══════════════════════════════════════════════════════════
// Bannière alerte IA active
// ══════════════════════════════════════════════════════════
class _AiAlertBanner extends StatelessWidget {
  final AppProvider app;
  final VoidCallback onTap;

  const _AiAlertBanner({
    required this.app,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = app.emergencyState == EmergencyState.pending;
    final isConfirmed = app.emergencyState == EmergencyState.confirmed;

    final color = isConfirmed
        ? AppColors.critical
        : isPending
            ? const Color(0xFFF59E0B)
            : AppColors.critical;

    final message = isConfirmed
        ? '🚨 Urgence confirmée par votre cardiologue'
        : isPending
            ? '⚠️ Anomalie détectée — En attente du cardiologue'
            : '⚠️ Alerte IA active — Voir les messages';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Icon(
              isConfirmed ? Icons.emergency_rounded : Icons.warning_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Disclaimer Banner
// ══════════════════════════════════════════════════════════
class _DisclaimerBanner extends StatelessWidget {
  final Color textPrimary;
  final Color primary;
  const _DisclaimerBanner({required this.textPrimary, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ThemeHelper.getColor(
          context,
          const Color(0xFFE3EDFB),
          AppColors.darkSurfaceVariant,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Prototype académique — Mode simulé',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Status Card
// ══════════════════════════════════════════════════════════
class _StatusCard extends StatelessWidget {
  final HealthStatus status;
  final int heartRate;
  final Color textPrimary, textSecondary, surface, border;

  const _StatusCard({
    required this.status,
    required this.heartRate,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.monitor_heart_rounded, size: 18, color: textSecondary),
              const SizedBox(width: 6),
              Text(
                'Fréquence',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary,
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
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4),
                child: Text(
                  'bpm',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
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

// ══════════════════════════════════════════════════════════
// Risk Card
// ══════════════════════════════════════════════════════════
class _RiskCard extends StatelessWidget {
  final int riskScore;
  final Color textSecondary, surface, border;

  const _RiskCard({
    required this.riskScore,
    required this.textSecondary,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            'Score de risque',
            style: TextStyle(
              fontSize: 12,
              color: textSecondary,
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

// ══════════════════════════════════════════════════════════
// ECG Preview Card
// ══════════════════════════════════════════════════════════
class _EcgPreviewCard extends StatelessWidget {
  final AnimationController controller;
  final bool isMonitoring;
  final String bleStatus;
  final List<double>? realEcgData;
  final Color textPrimary, border;

  const _EcgPreviewCard({
    required this.controller,
    required this.isMonitoring,
    required this.textPrimary,
    required this.border,
    this.bleStatus = 'idle',
    this.realEcgData,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = bleStatus == 'connected';
    final ecgBg = isConnected
        ? AppColors.ecgBackground
        : ThemeHelper.background(context);
    final ecgText = isConnected ? AppColors.ecgGreen : textPrimary;

    // Sous-titre dynamique selon l'état BLE
    String subtitle;
    switch (bleStatus) {
      case 'scanning':
        subtitle = 'Recherche du bracelet...';
        break;
      case 'connecting':
        subtitle = 'Connexion en cours...';
        break;
      case 'connected':
        subtitle = 'ECG en direct';
        break;
      case 'disconnected':
        subtitle = 'Bracelet déconnecté';
        break;
      default:
        subtitle = 'En attente du bracelet';
    }

    return Container(
      decoration: BoxDecoration(
        color: ecgBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.show_chart_rounded, size: 18, color: ecgText),
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ecgText,
                  ),
                ),
                if (isConnected) ...[const SizedBox(width: 8), _LiveDot()],
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
                  isLive: isConnected,
                  realEcgData: realEcgData,
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

// ══════════════════════════════════════════════════════════
// Carte de statut BLE Movesense (Dashboard)
// ══════════════════════════════════════════════════════════
class _BleStatusCard extends StatelessWidget {
  final String bleStatus;
  final String deviceName;
  final VoidCallback onTapEcg;

  const _BleStatusCard({
    required this.bleStatus,
    required this.deviceName,
    required this.onTapEcg,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;
    String title;
    String subtitle;

    switch (bleStatus) {
      case 'scanning':
        color = const Color(0xFFF59E0B);
        icon = Icons.bluetooth_searching_rounded;
        title = 'Recherche du bracelet en cours...';
        subtitle = 'Mettez le bracelet Movesense sur votre poitrine';
        break;
      case 'connecting':
        color = const Color(0xFFF59E0B);
        icon = Icons.bluetooth_connected_rounded;
        title = 'Connexion au bracelet Movesense...';
        subtitle = 'Établissement de la connexion BLE';
        break;
      case 'connected':
        color = AppColors.ecgGreen;
        icon = Icons.bluetooth_connected_rounded;
        title = 'Bracelet connecté : $deviceName';
        subtitle = 'ECG en direct • Appuyez pour afficher';
        break;
      case 'disconnected':
        color = AppColors.critical;
        icon = Icons.bluetooth_disabled_rounded;
        title = 'Vous êtes déconnecté du bracelet';
        subtitle = 'Remettez le bracelet pour reprendre automatiquement';
        break;
      default: // 'idle'
        color = const Color(0xFF64748B);
        icon = Icons.bluetooth_rounded;
        title = 'Scan BLE en démarrage...';
        subtitle = 'Recherche automatique en cours';
    }

    return GestureDetector(
      onTap: bleStatus == 'connected' ? onTapEcg : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(0.75),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (bleStatus == 'connected')
              Icon(Icons.arrow_forward_ios_rounded,
                  color: color, size: 14),
            if (bleStatus == 'scanning' || bleStatus == 'connecting')
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Quick Actions — Messages remplace Urgence
// ══════════════════════════════════════════════════════════
class _QuickActions extends StatelessWidget {
  final Color primary;
  const _QuickActions({required this.primary});


  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.show_chart_rounded,
        label: 'Nouvel ECG',
        color: primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EcgScreen()),
        ),
      ),
      // ✅ Messages remplace Urgence
      _QuickAction(
        icon: Icons.message_rounded,
        label: 'Messages',
        color: const Color(0xFF0EA5E9),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MessagesScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.map_rounded,
        label: 'Carte',
        color: const Color(0xFF2E7D32),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MapScreen()),
        ),
      ),
      _QuickAction(
        icon: Icons.history_rounded,
        label: 'Historique',
        color: const Color(0xFF6A1B9A),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
        ),
      ),
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

// ══════════════════════════════════════════════════════════
// History Item
// ══════════════════════════════════════════════════════════
class _HistoryItem extends StatelessWidget {
  final EcgReading reading;
  final Color textPrimary, textSecondary, surface, border;

  const _HistoryItem({
    required this.reading,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = reading.status == HealthStatus.normal
        ? ThemeHelper.normal(context)
        : reading.status == HealthStatus.suspect
            ? ThemeHelper.warning(context)
            : ThemeHelper.critical(context);
    final statusBg = reading.status == HealthStatus.normal
        ? AppColors.normalLight
        : reading.status == HealthStatus.suspect
            ? AppColors.warningLight
            : AppColors.criticalLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(Icons.monitor_heart_rounded, size: 22, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${reading.heartRate} bpm',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                Text(
                  _formatDate(reading.timestamp),
                  style: TextStyle(fontSize: 12, color: textSecondary),
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
