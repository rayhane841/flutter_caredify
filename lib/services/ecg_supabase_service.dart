import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// EcgSupabaseService
///
/// Service AUTONOME qui enregistre automatiquement les données ECG dans la
/// table `ecg_readings` de Supabase toutes les 30 secondes.
///
/// • Ne modifie AUCUN fichier existant sauf app_provider.dart (intégration)
/// • Respecte la RLS : patient_id = auth.uid()
/// • Respecte le schéma : ecg_values FLOAT[], heart_rate INT, status TEXT
///   avec CHECK (status IN ('normal', 'warning', 'critical'))
/// • Gestion propre des erreurs et des fuites mémoire
///
/// USAGE (dans app_provider.dart) :
///   final _ecgSupabaseService = EcgSupabaseService();
///   _ecgSupabaseService.start(
///     getPatientId: () => _authService.currentUser?.id,
///     getEcgValues: () => List<double>.from(_realEcgData),
///     getHeartRate: () => _heartRate,
///   );
///   // Pour arrêter proprement :
///   _ecgSupabaseService.stop();
/// ─────────────────────────────────────────────────────────────────────────────
class EcgSupabaseService {
  // ── Singleton ───────────────────────────────────────────────────────────────
  static final EcgSupabaseService _instance = EcgSupabaseService._internal();

  factory EcgSupabaseService() => _instance;

  EcgSupabaseService._internal();

  // ── Constantes ──────────────────────────────────────────────────────────────

  /// Intervalle entre deux enregistrements automatiques
  static const Duration _saveInterval = Duration(seconds: 30);

  /// Nombre minimum de points ECG requis pour déclencher un enregistrement
  /// (évite de sauvegarder des buffers vides ou trop courts)
  static const int _minEcgPoints = 10;

  // ── État interne ────────────────────────────────────────────────────────────
  Timer? _timer;
  bool _isRunning = false;

  /// Mode mock actif : limite les inserts à [_mockInsertLimit] pour éviter de
  /// saturer la table `ecg_readings` pendant les tests.
  bool _isMockMode = false;

  /// Nombre d'inserts réussis depuis le dernier `start()` en mode mock.
  int _mockInsertCount = 0;

  /// Limite stricte d'inserts en mode mock (zéro impact sur le mode réel).
  static const int _mockInsertLimit = 5;

  /// Callbacks fournis par app_provider (late-binding → pas de dépendance circulaire)
  String? Function()? _getPatientId;
  List<double> Function()? _getEcgValues;
  int Function()? _getHeartRate;

  // ── Client Supabase ─────────────────────────────────────────────────────────
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── API publique ─────────────────────────────────────────────────────────────

  /// Démarre l'enregistrement automatique toutes les 30 secondes.
  ///
  /// [getPatientId] : callback qui retourne l'UUID du patient connecté (peut
  ///                  retourner null si personne n'est connecté → skip silencieux)
  /// [getEcgValues] : callback qui retourne la snapshot actuelle du buffer ECG
  /// [getHeartRate] : callback qui retourne la FC courante en bpm
  /// [isMockMode]   : si `true`, stoppe automatiquement après 5 inserts réussis
  ///                  pour ne pas saturer la table en phase de test.
  ///                  N'a aucun effet en mode réel (`false` par défaut).
  void start({
    required String? Function() getPatientId,
    required List<double> Function() getEcgValues,
    required int Function() getHeartRate,
    bool isMockMode = false,
  }) {
    if (_isRunning) {
      debugPrint('[ECG_SUPA] ⚠️ Service déjà actif, redémarrage ignoré.');
      return;
    }

    _getPatientId     = getPatientId;
    _getEcgValues     = getEcgValues;
    _getHeartRate     = getHeartRate;
    _isMockMode       = isMockMode;
    _mockInsertCount  = 0; // Réinitialise le compteur à chaque démarrage
    _isRunning        = true;

    debugPrint(
      '[ECG_SUPA] ✅ Démarrage — enregistrement toutes les 30 s'
      '${isMockMode ? " [MODE SIMULATION – limite $_mockInsertLimit inserts]" : ""}.',
    );

    // Premier enregistrement différé de 30 s (laisser le temps au buffer de
    // se remplir avant la première sauvegarde)
    _timer = Timer.periodic(_saveInterval, (_) => _saveSnapshot());
  }

  /// Arrête proprement le timer et libère les callbacks.
  void stop() {
    if (!_isRunning) return;
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _getPatientId = null;
    _getEcgValues = null;
    _getHeartRate = null;
    debugPrint('[ECG_SUPA] 🛑 Service arrêté.');
  }

  /// Indique si le service est en cours d'exécution.
  bool get isRunning => _isRunning;

  // ── Logique d'enregistrement ─────────────────────────────────────────────────

  Future<void> _saveSnapshot() async {
    try {
      // 1. Récupérer le patient connecté
      final patientId = _getPatientId?.call();
      if (patientId == null || patientId.isEmpty) {
        debugPrint('[ECG_SUPA] ⏭️ Pas de patient connecté — skip.');
        return;
      }

      // 2. Récupérer les données ECG actuelles
      final ecgValues = _getEcgValues?.call() ?? [];
      if (ecgValues.length < _minEcgPoints) {
        debugPrint(
          '[ECG_SUPA] ⏭️ Buffer ECG trop court '
          '(${ecgValues.length}/$_minEcgPoints pts) — skip.',
        );
        return;
      }

      // 3. Récupérer la FC
      final heartRate = _getHeartRate?.call() ?? 0;

      // 4. Calculer le statut clinique
      final status = _computeStatus(heartRate, ecgValues);

      // 5. Prendre un snapshot (évite les mutations concurrentes du buffer)
      final snapshot = List<double>.from(ecgValues);

      debugPrint(
        '[ECG_SUPA] 💾 Sauvegarde — '
        'patient=$patientId | pts=${snapshot.length} | HR=$heartRate | status=$status',
      );

      // 6. Insert dans Supabase
      await _supabase.from('ecg_readings').insert({
        'patient_id': patientId,
        'ecg_values': snapshot,
        'heart_rate': heartRate > 0 ? heartRate : null,
        'status': status,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        // created_at est géré par DEFAULT NOW() côté Supabase
      });

      debugPrint('[ECG_SUPA] ✅ ECG enregistré avec succès.');

      // ── Limite mock : stopper après _mockInsertLimit inserts réussis ────────
      if (_isMockMode) {
        _mockInsertCount++;
        debugPrint(
          '[ECG_SUPA] 📊 Simulation — insert $_mockInsertCount/$_mockInsertLimit.',
        );
        if (_mockInsertCount >= _mockInsertLimit) {
          debugPrint(
            '[ECG_SUPA] 🛑 Limite mock atteinte ($_mockInsertLimit/$_mockInsertLimit)'
            ' — arrêt automatique.',
          );
          stop();
        }
      }
    } on PostgrestException catch (e) {
      // Erreurs Supabase / RLS / contrainte
      debugPrint('[ECG_SUPA] ❌ PostgrestException: ${e.message} (code=${e.code})');
      if (e.code == '42501') {
        debugPrint('[ECG_SUPA]    → Erreur RLS : vérifier que patient_id = auth.uid()');
      }
    } catch (e, stack) {
      debugPrint('[ECG_SUPA] ❌ Erreur inattendue: $e');
      debugPrint('[ECG_SUPA]    Stack: $stack');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  /// Calcule le statut clinique selon la FC et les valeurs ECG.
  ///
  /// Règles (ajustables selon protocole médical CAREDIFY) :
  ///   • HR < 40 ou > 150 bpm         → 'critical'
  ///   • HR 40-59 ou 100-150 bpm       → 'warning'
  ///   • HR 60-99 bpm (normal)         → 'normal'
  ///   • Amplitude ECG anormalement élevée (> 5.0 mV) → au minimum 'warning'
  ///
  /// Note : le status CHECK de Supabase n'accepte que
  ///   ('normal', 'warning', 'critical') → ne jamais retourner autre chose.
  String _computeStatus(int heartRate, List<double> ecgValues) {
    // Analyse de l'amplitude ECG (détection artéfacts / anomalies grossières)
    final maxAmplitude = ecgValues.fold<double>(
      0.0,
      (prev, v) => v.abs() > prev ? v.abs() : prev,
    );

    // Priorité : FC critique
    if (heartRate > 0 && (heartRate < 40 || heartRate > 150)) {
      return 'critical';
    }

    // Amplitude anormalement élevée → au moins warning
    if (maxAmplitude > 5.0) {
      return heartRate > 0 && (heartRate < 50 || heartRate > 130)
          ? 'critical'
          : 'warning';
    }

    // FC en zone de vigilance
    if (heartRate > 0 && (heartRate < 60 || heartRate > 100)) {
      return 'warning';
    }

    // Sinon : normal
    return 'normal';
  }
}
