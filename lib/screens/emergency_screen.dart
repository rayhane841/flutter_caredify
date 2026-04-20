import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class EmergencyScreen extends StatefulWidget {
  // ✅ AJOUT : Paramètre pour afficher/masquer le bouton retour
  final bool showBackButton;

  // ✅ Valeur par défaut = false (pas de bouton retour depuis NavBar)
  const EmergencyScreen({super.key, this.showBackButton = false});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..forward();

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ✅✅✅ MÉTHODE DE RETOUR : Via AppProvider pour IndexedStack ✅✅✅
  void _goBackToDashboard() {
    // Annuler l'urgence si active
    final app = Provider.of<AppProvider>(context, listen: false);
    if (app.emergencyState != EmergencyState.none) {
      app.cancelEmergency();
    }
    // ✅ Navigation via Provider (pour IndexedStack)
    app.navigateToDashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        return Scaffold(
          backgroundColor: app.emergencyState == EmergencyState.confirmed
              ? const Color(0xFF8B0000)
              : app.emergencyState == EmergencyState.pending
                  ? AppColors.emergency
                  : AppColors.background,
          // ✅✅✅ AppBar avec bouton retour CONDITIONNEL (bleu) ✅✅✅
          appBar: AppBar(
            backgroundColor: app.emergencyState == EmergencyState.confirmed
                ? const Color(0xFF8B0000)
                : app.emergencyState == EmergencyState.pending
                    ? AppColors.emergency
                    : AppColors.background,
            elevation: 0,
            // ✅✅✅ CONDITION : Afficher le bouton retour seulement si showBackButton = true ✅✅✅
            leading: widget.showBackButton
                ? Container(
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2), // ✅ Fond bleu clair
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.blue), // ✅ Icône bleue
                      onPressed: _goBackToDashboard,
                      tooltip: 'Retour au Dashboard',
                    ),
                  )
                : null, // ← Pas de bouton retour si false
            title: const Text(
              'Urgence',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            centerTitle: false,
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _buildBody(context, app),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AppProvider app) {
    switch (app.emergencyState) {
      case EmergencyState.none:
        return _NormalState(
          onTrigger: () {
            HapticFeedback.heavyImpact();
            app.triggerEmergency();
          },
          onBack: _goBackToDashboard,
        );
      case EmergencyState.pending:
        return _PendingState(
          onCancel: () => app.cancelEmergency(),
          onBack: _goBackToDashboard,
          pulseAnim: _pulseAnim,
          fadeAnim: _fadeAnim,
        );
      case EmergencyState.confirmed:
        return _ConfirmedState(
          countdown: app.emergencyCountdownFormatted,
          onCancel: () => app.cancelEmergency(),
          onBack: _goBackToDashboard,
          pulseAnim: _pulseAnim,
        );
    }
  }
}

// ==================== _NormalState ====================

class _NormalState extends StatelessWidget {
  final VoidCallback onTrigger;
  final VoidCallback onBack;
  const _NormalState({required this.onTrigger, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Text(
              'Urgence',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'En cas de malaise ou symptômes graves',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: onTrigger,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: AppColors.emergency,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emergency.withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.emergency_rounded,
                          color: Colors.white, size: 60),
                      SizedBox(height: 12),
                      Text(
                        'URGENCE',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Appuyer ici',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            _InfoCard(
              icon: Icons.medical_services_rounded,
              title: 'Processus d\'alerte',
              description:
                  'L\'IA détecte l\'anomalie → Votre cardiologue valide → Le SAMU est alerté',
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.location_on_rounded,
              title: 'GPS activé',
              description:
                  'Votre position est transmise automatiquement aux secours',
              color: AppColors.normal,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.person_rounded,
              title: 'Contact d\'urgence',
              description: 'Dr. Marie Lefebvre\n+33 6 12 34 56 78',
              color: AppColors.warning,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.criticalLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.critical.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.critical, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Prototype académique — Mode simulé\nAucun service d\'urgence réel contacté',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.critical,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== _InfoCard ====================

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== _PendingState ====================

class _PendingState extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onBack;
  final Animation<double> pulseAnim;
  final Animation<double> fadeAnim;

  const _PendingState({
    required this.onCancel,
    required this.onBack,
    required this.pulseAnim,
    required this.fadeAnim,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnim,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: pulseAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Alerte envoyée',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Votre cardiologue a été notifié.\nEn attente de validation médicale...',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.local_hospital_rounded,
                        color: Colors.white, size: 32),
                    SizedBox(height: 10),
                    Text(
                      'Restez calme et allongé(e)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ne bougez pas. Les secours sont alertés.\nVotre position GPS est transmise.',
                      style: TextStyle(
                          fontSize: 14, color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // ✅ Bouton retour BLEU explicite (utilise onBack)
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(foregroundColor: Colors.blue),
                child: const Text('← Retour au Dashboard',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onCancel,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text('Fausse alerte — Annuler',
                    style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== _ConfirmedState ====================

class _ConfirmedState extends StatelessWidget {
  final String countdown;
  final VoidCallback onCancel;
  final VoidCallback onBack;
  final Animation<double> pulseAnim;

  const _ConfirmedState({
    required this.countdown,
    required this.onCancel,
    required this.onBack,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, color: Colors.white, size: 24),
                SizedBox(width: 8),
                Text(
                  'URGENCE CONFIRMÉE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Validée par votre cardiologue',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            ScaleTransition(
              scale: pulseAnim,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4), width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'SAMU arrive dans',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      countdown,
                      style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Text(
                      'min : sec',
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: Colors.white, size: 30),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Position GPS confirmée',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '48.8566° N, 2.3522° E\nTransmise aux secours',
                          style: TextStyle(
                              fontSize: 12, color: Colors.white70, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: const Column(
                children: [
                  Text(
                    '💙 Vous êtes pris(e) en charge',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Le SAMU est en route. Restez allongé(e) et calme. Votre cardiologue surveille votre ECG en temps réel. Si possible, déverrouillez votre porte d\'entrée.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.phone_rounded, size: 20),
                    label: const Text('Appeler le 15'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.emergency,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.message_rounded, size: 20),
                    label: const Text('Contact proches'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ✅ Bouton retour BLEU explicite (utilise onBack)
            TextButton(
              onPressed: onBack,
              style: TextButton.styleFrom(foregroundColor: Colors.blue),
              child: const Text('← Retour au Dashboard',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(foregroundColor: Colors.white54),
              child: const Text('Fausse alerte — Annuler',
                  style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
