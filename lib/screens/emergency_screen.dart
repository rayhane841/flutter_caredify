import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_provider.dart';
import '../utils/theme_helper.dart';

class EmergencyScreen extends StatefulWidget {
  final bool showBackButton;
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

  final SupabaseClient _supabase = Supabase.instance.client;
  String? _alertId;
  RealtimeChannel? _channel;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this)
      ..repeat(reverse: true);
    _fadeController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this)
      ..forward();
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    if (_channel != null) _supabase.removeChannel(_channel!);
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Déclencher l'alerte ──────────────────────────────────────────
  Future<void> _triggerAlert(AppProvider app) async {
    if (_sending) return;
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();

    try {
      final userId = _supabase.auth.currentUser!.id;

      // 1. Récupérer cardiologue du patient
      final patientData = await _supabase
          .from('patients')
          .select('cardiologist, first_name, last_name')
          .eq('id', userId)
          .single();

      final cardiologistName = patientData['cardiologist'] as String? ?? '';
      final patientName =
          '${patientData['first_name']} ${patientData['last_name']}';

      // 2. Trouver l'UUID du cardiologue
      final profileData = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'carediologue')
          .ilike('full_name', '%$cardiologistName%')
          .maybeSingle();

      if (profileData == null) {
        _showSnack('Cardiologue non trouvé. Vérifiez votre profil.');
        setState(() => _sending = false);
        return;
      }

      final cardiologistId = profileData['id'] as String;

      // 3. Dernier ECG disponible
      final ecgData = await _supabase
          .from('ecg_readings')
          .select('heart_rate, status')
          .eq('patient_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final heartRate = ecgData?['heart_rate'] as int?;
      final ecgStatus = ecgData?['status'] as String?;
      final aiScore = _scoreFromStatus(ecgStatus);

      // 4. INSERT dans emergency_alerts
      final result = await _supabase
          .from('emergency_alerts')
          .insert({
            'patient_id': userId,
            'cardiologist_id': cardiologistId,
            'status': 'pending',
            'patient_name': patientName,
            'heart_rate': heartRate,
            'ai_score': aiScore,
            'ai_severity': ecgStatus ?? 'warning',
          })
          .select('id')
          .single();

      _alertId = result['id'] as String;

      // 5. Écouter la réponse du cardiologue
      _subscribeToAlert(_alertId!);

      // 6. Mettre à jour l'état
      app.triggerEmergency();
    } catch (e) {
      debugPrint('❌ Erreur déclenchement alerte: $e');
      _showSnack('Erreur lors de l\'envoi de l\'alerte.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── Realtime — écouter la réponse du cardiologue ─────────────────
  void _subscribeToAlert(String alertId) {
    _channel = _supabase
        .channel('emergency:$alertId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'emergency_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: alertId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final newStatus = payload.newRecord['status'] as String?;
            final app = Provider.of<AppProvider>(context, listen: false);

            if (newStatus == 'confirmed') {
              app.confirmEmergency();
            } else if (newStatus == 'cancelled') {
              // ✅ Cardiologue a annulé → page verte
              app.setEmergencySafe();
            }
          },
        )
        .subscribe();
  }

  // ── Annuler l'alerte (côté patient) ─────────────────────────────
  Future<void> _cancelAlert(AppProvider app) async {
    if (_alertId != null) {
      await _supabase.from('emergency_alerts').update({
        'status': 'cancelled',
        'responded_at': DateTime.now().toIso8601String(),
      }).eq('id', _alertId!);
    }
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
    _alertId = null;
    app.cancelEmergency();
  }

  int _scoreFromStatus(String? status) {
    if (status == 'critical') return 75 + (DateTime.now().millisecond % 25);
    if (status == 'warning') return 50 + (DateTime.now().millisecond % 24);
    return 85;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _goBack() {
    final app = Provider.of<AppProvider>(context, listen: false);
    if (app.emergencyState == EmergencyState.safe ||
        app.emergencyState == EmergencyState.none) {
      app.cancelEmergency();
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(builder: (context, app, _) {
      final isConfirmed = app.emergencyState == EmergencyState.confirmed;
      final isPending = app.emergencyState == EmergencyState.pending;
      final isSafe = app.emergencyState == EmergencyState.safe;
      final isNone = app.emergencyState == EmergencyState.none;

      Color bgColor;
      if (isConfirmed)
        bgColor = const Color(0xFF8B0000);
      else if (isPending)
        bgColor = ThemeHelper.emergency(context);
      else if (isSafe)
        bgColor = const Color(0xFF065F46);
      else
        bgColor = ThemeHelper.background(context);

      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          leading: (widget.showBackButton || isSafe || isNone)
              ? IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: (isPending || isConfirmed || isSafe)
                        ? Colors.white
                        : ThemeHelper.textPrimary(context),
                  ),
                  onPressed: _goBack,
                )
              : null,
          title: Text(
            isSafe ? 'Vous êtes en sécurité' : 'Urgence',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: (isPending || isConfirmed || isSafe)
                  ? Colors.white
                  : ThemeHelper.textPrimary(context),
            ),
          ),
        ),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _buildBody(context, app),
        ),
      );
    });
  }

  Widget _buildBody(BuildContext context, AppProvider app) {
    switch (app.emergencyState) {
      case EmergencyState.none:
        return _NormalState(
          onTrigger: () => _triggerAlert(app),
          sending: _sending,
        );
      case EmergencyState.pending:
        return _PendingState(
          onCancel: () => _cancelAlert(app),
          pulseAnim: _pulseAnim,
          fadeAnim: _fadeAnim,
        );
      case EmergencyState.confirmed:
        return _ConfirmedState(
          countdown: app.emergencyCountdownFormatted,
          onCancel: () => _cancelAlert(app),
          pulseAnim: _pulseAnim,
        );
      case EmergencyState.safe:
        return _SafeState(onBack: _goBack);
    }
  }
}

// ══════════════════════════════════════════════════════
// État normal
// ══════════════════════════════════════════════════════
class _NormalState extends StatelessWidget {
  final VoidCallback onTrigger;
  final bool sending;
  const _NormalState({required this.onTrigger, required this.sending});

  @override
  Widget build(BuildContext context) {
    final textPri = ThemeHelper.textPrimary(context);
    final textSec = ThemeHelper.textSecondary(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final primary = ThemeHelper.primary;
    final critical = ThemeHelper.critical(context);
    final warning = ThemeHelper.warning(context);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text('Urgence',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: textPri)),
            const SizedBox(height: 6),
            Text('En cas de malaise ou symptômes graves',
                style: TextStyle(fontSize: 15, color: textSec)),
            const SizedBox(height: 40),
            Center(
              child: GestureDetector(
                onTap: sending ? null : onTrigger,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: sending
                        ? ThemeHelper.emergency(context).withOpacity(0.6)
                        : ThemeHelper.emergency(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: ThemeHelper.emergency(context).withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: sending
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.emergency_rounded,
                                color: Colors.white, size: 60),
                            SizedBox(height: 12),
                            Text('URGENCE',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2)),
                            SizedBox(height: 4),
                            Text('Appuyer ici',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500)),
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
                  'L\'IA analyse votre ECG → Votre cardiologue valide → Le SAMU est alerté',
              color: primary,
              surface: surface,
              border: border,
              textPrimary: textPri,
              textSecondary: textSec,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.location_on_rounded,
              title: 'GPS activé',
              description: 'Votre position est transmise automatiquement',
              color: ThemeHelper.normal(context),
              surface: surface,
              border: border,
              textPrimary: textPri,
              textSecondary: textSec,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.person_rounded,
              title: 'Contact d\'urgence',
              description: 'Votre cardiologue sera alerté immédiatement',
              color: warning,
              surface: surface,
              border: border,
              textPrimary: textPri,
              textSecondary: textSec,
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: critical.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: critical.withOpacity(0.2))),
              child: Row(children: [
                Icon(Icons.info_outline, color: critical, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Prototype académique — Mode simulé\nAucun service d\'urgence réel contacté',
                    style: TextStyle(
                        fontSize: 12,
                        color: critical,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// État en attente
// ══════════════════════════════════════════════════════
class _PendingState extends StatelessWidget {
  final VoidCallback onCancel;
  final Animation<double> pulseAnim, fadeAnim;
  const _PendingState({
    required this.onCancel,
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
            children: [
              const SizedBox(height: 20),
              ScaleTransition(
                scale: pulseAnim,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 3)),
                  child: const Icon(Icons.favorite_rounded,
                      color: Colors.white, size: 64),
                ),
              ),
              const SizedBox(height: 36),
              const Text('Restez calme',
                  style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30)),
                child: const Text('🩺 Le cardiologue examine votre cas',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 36),
              const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 3),
              const SizedBox(height: 10),
              const Text('En attente de réponse...',
                  style: TextStyle(fontSize: 14, color: Colors.white60)),
              const SizedBox(height: 36),
              _buildInstruction(Icons.airline_seat_flat_rounded,
                  'Allongez-vous ou asseyez-vous confortablement'),
              const SizedBox(height: 12),
              _buildInstruction(
                  Icons.air_rounded, 'Respirez lentement et profondément'),
              const SizedBox(height: 12),
              _buildInstruction(Icons.location_on_rounded,
                  'Votre position GPS est transmise au cardiologue'),
              const SizedBox(height: 12),
              _buildInstruction(Icons.door_front_door_rounded,
                  'Si possible, déverrouillez votre porte d\'entrée'),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2))),
                child: const Column(children: [
                  Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                  SizedBox(height: 10),
                  Text('Vous êtes entre de bonnes mains',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                      textAlign: TextAlign.center),
                  SizedBox(height: 8),
                  Text(
                      'Votre cardiologue analyse votre ECG en temps réel et prendra les mesures nécessaires.',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white70, height: 1.6),
                      textAlign: TextAlign.center),
                ]),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Annuler l\'alerte ?'),
                    content: const Text('Êtes-vous sûr de vouloir annuler ?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Non')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onCancel();
                        },
                        child: const Text('Oui, annuler',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                ),
                child: const Text('Fausse alerte — Annuler',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ),
              const SizedBox(height: 20),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                child: const Text(
                    '⚠️ Prototype académique — Mode simulé\nAucun service d\'urgence réel n\'est contacté',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white54, height: 1.5),
                    textAlign: TextAlign.center),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstruction(IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.15))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    height: 1.4))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════
// État confirmé
// ══════════════════════════════════════════════════════
class _ConfirmedState extends StatelessWidget {
  final String countdown;
  final VoidCallback onCancel;
  final Animation<double> pulseAnim;
  const _ConfirmedState({
    required this.countdown,
    required this.onCancel,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(children: [
          const SizedBox(height: 8),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('URGENCE CONFIRMÉE',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 6),
          const Text('Validée par votre cardiologue',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
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
                      color: Colors.white.withOpacity(0.4), width: 3)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('SAMU arrive dans',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(countdown,
                      style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const Text('min : sec',
                      style: TextStyle(fontSize: 12, color: Colors.white54)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.2))),
            child: const Column(children: [
              Text('Vous êtes pris(e) en charge',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              SizedBox(height: 8),
              Text(
                  'Le SAMU est en route. Restez allongé(e) et calme. Votre cardiologue surveille votre ECG. Si possible, déverrouillez votre porte d\'entrée.',
                  style: TextStyle(
                      fontSize: 14, color: Colors.white70, height: 1.6),
                  textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.phone_rounded, size: 20),
              label: const Text('Appeler le 15'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF8B0000),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCancel,
            child: const Text('Fausse alerte — Annuler',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// ✅ État sain — page VERTE (cardiologue a annulé)
// ══════════════════════════════════════════════════════
class _SafeState extends StatelessWidget {
  final VoidCallback onBack;
  const _SafeState({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                MediaQuery.of(context).padding.top -
                MediaQuery.of(context).padding.bottom -
                kToolbarHeight,
          ),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 3)),
                  child: const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 80),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Vous êtes sain(e) !',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Text(
                    'Votre cardiologue a examiné votre situation et confirme qu\'il n\'y a pas d\'urgence médicale.\n\nContinuez à vous reposer et surveillez vos symptômes.',
                    style: TextStyle(
                        fontSize: 15, color: Colors.white, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onBack,
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Retour'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF065F46),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// _InfoCard
// ══════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title, description;
  final Color color, surface, border, textPrimary, textSecondary;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 22)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary)),
              const SizedBox(height: 3),
              Text(description,
                  style: TextStyle(
                      fontSize: 12, color: textSecondary, height: 1.4)),
            ],
          ),
        ),
      ]),
    );
  }
}
