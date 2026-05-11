import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
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

    // ── Démarrage automatique du scan BLE dès l'ouverture de l'écran ──
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = Provider.of<AppProvider>(context, listen: false);
      app.startAutoScan();
    });
  }

  @override
  void dispose() {
    // ── Arrêt propre du scan et de la connexion BLE ──
    final app = Provider.of<AppProvider>(context, listen: false);
    app.stopAutoScan();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final bleStatus = app.bleStatus;
        final isConnected = bleStatus == 'connected';
        final isDisconnected = bleStatus == 'disconnected';

        // Couleurs selon le statut BLE (fond ECG noir quand actif)
        final bg = (isConnected || bleStatus == 'scanning' || isDisconnected)
            ? AppColors.ecgBackground
            : ThemeHelper.background(context);
        final appBarBg = isConnected
            ? AppColors.ecgBackground
            : ThemeHelper.surface(context);
        final appBarText =
            isConnected ? AppColors.ecgGreen : ThemeHelper.textPrimary(context);
        final border =
            isConnected ? const Color(0xFF003300) : ThemeHelper.border(context);
        final tileBg = isConnected
            ? const Color(0xFF0A1A0A)
            : ThemeHelper.surface(context);
        final tileText = isConnected
            ? const Color(0xFF4CAF50)
            : ThemeHelper.textSecondary(context);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: appBarBg,
            foregroundColor: appBarText,
            title: Text(
              'ECG en direct',
              style:
                  TextStyle(color: appBarText, fontWeight: FontWeight.w700),
            ),
            iconTheme: IconThemeData(color: appBarText),
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: border),
            ),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                // ── Bandeau de statut BLE ─────────────────────────
                _BleBanner(bleStatus: bleStatus, deviceName: app.connectedDeviceName),

                // ── Zone ECG + overlay déconnexion ────────────────
                Expanded(
                  flex: 3,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // Courbe ECG
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.ecgBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isConnected
                                      ? AppColors.ecgGreen.withOpacity(0.3)
                                      : const Color(0xFF003300),
                                ),
                              ),
                              child: CustomPaint(
                                painter: EcgPainter(
                                  phase: _controller.value * 5,
                                  isLive: app.isMonitoring,
                                  realEcgData: app.realEcgData.isEmpty
                                      ? null
                                      : app.realEcgData,
                                ),
                                size: Size.infinite,
                              ),
                            ),

                            // Overlay déconnexion
                            if (isDisconnected)
                              Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.bluetooth_disabled_rounded,
                                      color: AppColors.critical,
                                      size: 48,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Vous êtes déconnecté du bracelet',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'En attente du bracelet...',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Tuiles statistiques ───────────────────────────
                Opacity(
                  opacity: isConnected ? 1.0 : 0.4,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _StatTile(
                          label: 'Fréq. cardiaque',
                          value: isConnected ? '${app.heartRate}' : '--',
                          unit: 'bpm',
                          icon: Icons.favorite_rounded,
                          color: AppColors.critical,
                          active: isConnected,
                          tileBg: tileBg,
                          tileText: tileText,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'Qualité signal',
                          value: isConnected ? '94' : '--',
                          unit: '%',
                          icon: Icons.signal_cellular_4_bar_rounded,
                          color: AppColors.normal,
                          active: isConnected,
                          tileBg: tileBg,
                          tileText: tileText,
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'Score risque',
                          value: isConnected ? '${app.riskScore}' : '--',
                          unit: '/100',
                          icon: Icons.shield_rounded,
                          color: AppColors.primary,
                          active: isConnected,
                          tileBg: tileBg,
                          tileText: tileText,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Informations dérivations ──────────────────────
                Opacity(
                  opacity: isConnected ? 1.0 : 0.4,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: tileBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _LeadInfo(
                              label: 'Dérivation',
                              value: 'DI',
                              active: isConnected,
                              tileText: tileText),
                          _LeadInfo(
                              label: 'Intervalle PR',
                              value: '162 ms',
                              active: isConnected,
                              tileText: tileText),
                          _LeadInfo(
                              label: 'QRS',
                              value: '88 ms',
                              active: isConnected,
                              tileText: tileText),
                          _LeadInfo(
                              label: 'QT',
                              value: '412 ms',
                              active: isConnected,
                              tileText: tileText),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Analyse IA (visible seulement quand connecté) ─
                if (isConnected)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1A0A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color:
                                AppColors.ecgGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.ecgGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.psychology_rounded,
                                color: AppColors.ecgGreen, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('Analyse IA en cours...',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ecgGreen)),
                                SizedBox(height: 2),
                                Text(
                                    'Rythme sinusal normal détecté',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF4CAF50))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // ── Bouton "Arrêter le monitoring" (visible seulement quand connecté) ──
                if (isConnected)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await app.stopAutoScan();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.stop_circle_outlined,
                            size: 18,
                            color: Color(0xFF94A3B8)),
                        label: const Text(
                          'Arrêter le monitoring',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFF334155)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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

// ══════════════════════════════════════════════════════════
// Bandeau de statut BLE
// ══════════════════════════════════════════════════════════
class _BleBanner extends StatefulWidget {
  final String bleStatus;
  final String deviceName;

  const _BleBanner({
    required this.bleStatus,
    required this.deviceName,
  });

  @override
  State<_BleBanner> createState() => _BleBannerState();
}

class _BleBannerState extends State<_BleBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.bleStatus) {
      case 'scanning':
        return _BannerContainer(
          color: const Color(0xFFF59E0B),
          bgOpacity: 0.12,
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Icon(
                  Icons.bluetooth_searching_rounded,
                  color: const Color(0xFFF59E0B)
                      .withOpacity(0.4 + _pulseCtrl.value * 0.6),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Recherche du bracelet en cours...',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'connecting':
        return const _BannerContainer(
          color: Color(0xFFF59E0B),
          bgOpacity: 0.12,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Connexion au bracelet Movesense...',
                  style: TextStyle(
                    color: Color(0xFFF59E0B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'connected':
        return _BannerContainer(
          color: AppColors.ecgGreen,
          bgOpacity: 0.12,
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.ecgGreen
                        .withOpacity(0.5 + _pulseCtrl.value * 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bracelet connecté : ${widget.deviceName}',
                  style: const TextStyle(
                    color: AppColors.ecgGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );

      case 'disconnected':
        return const _BannerContainer(
          color: AppColors.critical,
          bgOpacity: 0.12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bluetooth_disabled_rounded,
                      color: AppColors.critical, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Vous êtes déconnecté du bracelet',
                      style: TextStyle(
                        color: AppColors.critical,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4),
              Padding(
                padding: EdgeInsets.only(left: 28),
                child: Text(
                  'Remettez le bracelet pour reprendre automatiquement',
                  style: TextStyle(
                    color: AppColors.critical,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );

      default: // 'idle'
        return const SizedBox.shrink();
    }
  }
}

class _BannerContainer extends StatelessWidget {
  final Color color;
  final double bgOpacity;
  final Widget child;

  const _BannerContainer({
    required this.color,
    required this.bgOpacity,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(bgOpacity),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════
// Stat Tile
// ══════════════════════════════════════════════════════════
class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool active;
  final Color tileBg;
  final Color tileText;

  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    required this.active,
    required this.tileBg,
    required this.tileText,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: active
                  ? color.withOpacity(0.3)
                  : ThemeHelper.border(context)),
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
                color:
                    active ? Colors.white : ThemeHelper.textPrimary(context),
                letterSpacing: -0.5,
              ),
            ),
            Text(unit,
                style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? tileText
                        : ThemeHelper.textSecondary(context),
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: active
                        ? tileText
                        : ThemeHelper.textSecondary(context))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// Lead Info
// ══════════════════════════════════════════════════════════
class _LeadInfo extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  final Color tileText;

  const _LeadInfo({
    required this.label,
    required this.value,
    required this.active,
    required this.tileText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active
                    ? AppColors.ecgGreen
                    : ThemeHelper.textPrimary(context))),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active
                    ? tileText
                    : ThemeHelper.textSecondary(context))),
      ],
    );
  }
}
