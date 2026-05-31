import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_provider.dart';
import '../utils/theme_helper.dart';

// ✅ Modification 1 — ajout de initialCardiologistNote
class EmergencyScreen extends StatefulWidget {
  final bool showBackButton;
  final String? initialCardiologistNote;

  const EmergencyScreen({
    super.key,
    this.showBackButton = false,
    this.initialCardiologistNote,
  });

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

  bool _sending = false;
  bool _smsSent = false;

  RealtimeChannel? _ecgChannel;
  String? _cardiologistNote;

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

    // ✅ Modification 2 — si note passée depuis dashboard
    if (widget.initialCardiologistNote != null) {
      _cardiologistNote = widget.initialCardiologistNote;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final app = Provider.of<AppProvider>(context, listen: false);
        if (app.emergencyState != EmergencyState.confirmed) {
          app.confirmEmergency();
        }
      });
    }

    _subscribeToEcgConfirmation();
  }

  @override
  void dispose() {
    _ecgChannel?.unsubscribe();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _subscribeToEcgConfirmation() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _ecgChannel = _supabase
        .channel('ecg_confirm_emergency_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'ecg_readings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'patient_id',
            value: userId,
          ),
          callback: (payload) {
            final confirmedAt = payload.newRecord['confirmed_at'];
            final note = payload.newRecord['cardiologist_note'] as String?;
            if (confirmedAt != null && mounted) {
              setState(() => _cardiologistNote = note);
              final app = Provider.of<AppProvider>(context, listen: false);
              app.confirmEmergency();
            }
          },
        )
        .subscribe();
  }

  Future<void> _triggerSmsOnly(AppProvider app) async {
    if (_sending) return;
    setState(() => _sending = true);
    HapticFeedback.heavyImpact();

    try {
      final userId = _supabase.auth.currentUser!.id;

      final patientData = await _supabase
          .from('patients')
          .select('first_name, last_name, family_phone')
          .eq('id', userId)
          .single();

      final patientName =
          '${patientData['first_name']} ${patientData['last_name']}';
      final familyPhone = patientData['family_phone'] as String?;

      debugPrint('🔹 [URGENCE] Patient: $patientName');
      debugPrint('🔹 [URGENCE] family_phone: $familyPhone');

      final ecgData = await _supabase
          .from('ecg_readings')
          .select('heart_rate, status')
          .eq('patient_id', userId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final heartRate = ecgData?['heart_rate'] as int?;
      final hrText = heartRate != null ? '$heartRate bpm' : 'inconnue';

      if (familyPhone != null && familyPhone.isNotEmpty) {
        try {
          final smsResponse = await http.post(
            Uri.parse('https://caredify-api.onrender.com/send-sms'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': familyPhone,
              'message':
                  'URGENT : $patientName a déclenché une alerte cardiaque. '
                      'Fréquence cardiaque : $hrText. '
                      'Veuillez le/la contacter immédiatement ou appeler le 15.',
            }),
          );
          if (smsResponse.statusCode == 200) {
            debugPrint('✅ [SMS] Envoyé à $familyPhone');
            setState(() => _smsSent = true);
          } else {
            debugPrint('⚠️ [SMS] Erreur HTTP: ${smsResponse.body}');
            _showSnack('Erreur envoi SMS. Vérifiez votre connexion.');
          }
        } catch (e) {
          debugPrint('⚠️ [SMS] Exception: $e');
          _showSnack('Erreur envoi SMS: $e');
        }
      } else {
        _showSnack('Aucun numéro famille défini. Vérifiez votre profil.');
      }
    } catch (e) {
      debugPrint('❌ [URGENCE] Erreur: $e');
      _showSnack('Erreur: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _cancelEmergency(AppProvider app) {
    setState(() {
      _smsSent = false;
      _cardiologistNote = null;
    });
    app.cancelEmergency();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
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
      final isSafe = app.emergencyState == EmergencyState.safe;
      final isNone = app.emergencyState == EmergencyState.none;

      Color bgColor;
      if (isConfirmed)
        bgColor = const Color(0xFF8B0000);
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
                  icon: Icon(Icons.arrow_back,
                      color: isConfirmed || isSafe
                          ? Colors.white
                          : ThemeHelper.textPrimary(context)),
                  onPressed: _goBack,
                )
              : null,
          title: Text(
            isSafe
                ? 'Vous êtes en sécurité'
                : isConfirmed
                    ? 'Urgence confirmée'
                    : 'Urgence',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isConfirmed || isSafe
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
    if (app.emergencyState == EmergencyState.confirmed) {
      return _ConfirmedState(
        countdown: app.emergencyCountdownFormatted,
        cardiologistNote: _cardiologistNote,
        onCancel: () => _cancelEmergency(app),
        pulseAnim: _pulseAnim,
      );
    }

    if (app.emergencyState == EmergencyState.safe) {
      return _SafeState(onBack: _goBack);
    }

    return _NormalState(
      onTrigger: () => _triggerSmsOnly(app),
      sending: _sending,
      smsSent: _smsSent,
      onReset: () => setState(() => _smsSent = false),
    );
  }
}

// ══════════════════════════════════════════════════════
// État normal
// ══════════════════════════════════════════════════════
class _NormalState extends StatelessWidget {
  final VoidCallback onTrigger;
  final VoidCallback onReset;
  final bool sending;
  final bool smsSent;

  const _NormalState({
    required this.onTrigger,
    required this.onReset,
    required this.sending,
    required this.smsSent,
  });

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
                onTap: sending || smsSent ? null : onTrigger,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: smsSent
                        ? const Color(0xFF10B981)
                        : sending
                            ? ThemeHelper.emergency(context).withOpacity(0.6)
                            : ThemeHelper.emergency(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: (smsSent
                                  ? const Color(0xFF10B981)
                                  : ThemeHelper.emergency(context))
                              .withOpacity(0.35),
                          blurRadius: 40,
                          spreadRadius: 10)
                    ],
                  ),
                  child: sending
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : smsSent
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 60),
                                SizedBox(height: 12),
                                Text('SMS ENVOYÉ',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 1)),
                                SizedBox(height: 4),
                                Text('Famille alertée',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500)),
                              ],
                            )
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
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: smsSent
                    ? const Color(0xFF10B981).withOpacity(0.1)
                    : const Color(0xFF0EA5E9).withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: smsSent
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFF0EA5E9).withOpacity(0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    smsSent ? Icons.check_circle_rounded : Icons.sms_rounded,
                    color: smsSent
                        ? const Color(0xFF10B981)
                        : const Color(0xFF0EA5E9),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      smsSent
                          ? 'SMS envoyé à votre famille ✓'
                          : 'SMS automatique envoyé à votre famille',
                      style: TextStyle(
                          fontSize: 11,
                          color: smsSent
                              ? const Color(0xFF10B981)
                              : const Color(0xFF0EA5E9),
                          fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            if (smsSent) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.refresh_rounded,
                      size: 16, color: Color(0xFF0EA5E9)),
                  label: const Text('Renvoyer un SMS',
                      style: TextStyle(color: Color(0xFF0EA5E9), fontSize: 13)),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _InfoCard(
              icon: Icons.sms_rounded,
              title: 'SMS famille automatique',
              description:
                  'Un SMS est envoyé instantanément au numéro famille défini dans votre profil',
              color: const Color(0xFF0EA5E9),
              surface: surface,
              border: border,
              textPrimary: textPri,
              textSecondary: textSec,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.monitor_heart_rounded,
              title: 'Surveillance ECG continue',
              description:
                  'Votre cardiologue reçoit une alerte automatique si votre ECG devient critique',
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
              color: warning,
              surface: surface,
              border: border,
              textPrimary: textPri,
              textSecondary: textSec,
            ),
            const SizedBox(height: 32),
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
                )),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════
// Page rouge SAMU
// ══════════════════════════════════════════════════════
class _ConfirmedState extends StatelessWidget {
  final String countdown;
  final String? cardiologistNote;
  final VoidCallback onCancel;
  final Animation<double> pulseAnim;

  const _ConfirmedState({
    required this.countdown,
    required this.cardiologistNote,
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
          const SizedBox(height: 24),

          // ✅ Note médicale
          if (cardiologistNote != null && cardiologistNote!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Text('📋 ', style: TextStyle(fontSize: 16)),
                    Text('Note médicale',
                        style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    cardiologistNote!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // ✅ Compteur SAMU
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
          const SizedBox(height: 24),

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
                  'Le SAMU est en route. Restez allongé(e) et calme. '
                  'Votre cardiologue surveille votre ECG. '
                  'Si possible, déverrouillez votre porte d\'entrée.',
                  style: TextStyle(
                      fontSize: 14, color: Colors.white70, height: 1.6),
                  textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: 24),

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
// État sain
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
                const Text('Vous êtes sain(e) !',
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16)),
                  child: const Text(
                    'Votre cardiologue a examiné votre situation et confirme '
                    'qu\'il n\'y a pas d\'urgence médicale.\n\n'
                    'Continuez à vous reposer et surveillez vos symptômes.',
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
                style:
                    TextStyle(fontSize: 12, color: textSecondary, height: 1.4)),
          ],
        )),
      ]),
    );
  }
}
