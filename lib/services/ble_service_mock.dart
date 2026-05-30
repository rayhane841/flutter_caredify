// Academic prototype – not for clinical use
// ─────────────────────────────────────────────────────────────────────────────
// BleServiceMock – Simulateur de bracelet Movesense pour tests en l'absence
//                  du matériel physique.
//
// • Génère un flux ECG 1-lead réaliste : forme d'onde P-QRS-T + bruit physiologique
// • Format des paquets : identique au vrai BleService (interchangeable)
//   [flags(1B), heartRate(1B), ecgSample0, ecgSample1, ecgSample2, ecgSample3]
// • Valeurs ECG 12-bit centrées sur 2048 → compatibles avec la normalisation
//   (v - 2048) / 2048.0 du pipeline existant
// • Fréquence d'émission : 4 Hz (250 ms) ← correspond au bracelet réel
// • Cycling automatique normal → warning → critical pour valider tout le pipeline
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'ble_service.dart'; // Réutilise BleConnectionUpdate

/// Modes de simulation : le mock cycle automatiquement toutes les 60 s
/// pour permettre de tester les 3 statuts cliniques.
enum MockScenario {
  normal,   // HR 60-90 bpm, ECG propre
  warning,  // HR 100-130 bpm, légère tachycardie
  critical, // HR 145-160 bpm, ECG perturbé
}

// ─────────────────────────────────────────────────────────────────────────────
// BleServiceMock
// ─────────────────────────────────────────────────────────────────────────────
class BleServiceMock {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final BleServiceMock _instance = BleServiceMock._internal();
  factory BleServiceMock() => _instance;
  BleServiceMock._internal();

  // ── État ─────────────────────────────────────────────────────────────────────
  bool _isConnected = false;
  bool _isStreaming = false;
  MockScenario _currentScenario = MockScenario.normal;
  int _packetCount = 0;

  // ── Paramètres de génération ECG ─────────────────────────────────────────────
  static const int    _ecgCenter    = 2048;   // Centre 12-bit
  static const int    _ecgAmplitude = 600;    // Amplitude principale (en ADC units)
  static const int    _noiseLevel   = 18;     // Bruit physiologique (ADC units)
  static const double _emitHz       = 4.0;    // Fréquence d'émission des paquets
  static const int    _samplesPerPacket = 4;  // Échantillons par paquet BLE

  // ── Fréquences cardiaques simulées par scénario ───────────────────────────────
  static const Map<MockScenario, ({int hrMin, int hrMax})> _hrRanges = {
    MockScenario.normal:   (hrMin: 60,  hrMax: 90),
    MockScenario.warning:  (hrMin: 100, hrMax: 130),
    MockScenario.critical: (hrMin: 145, hrMax: 160),
  };

  // ── Durée de chaque scénario avant rotation ───────────────────────────────────
  static const Duration _scenarioDuration = Duration(seconds: 60);

  // ── Générateurs ───────────────────────────────────────────────────────────────
  final Random _rng = Random();
  double _ecgPhase = 0.0;     // Phase continue du signal ECG [0 → 1 par cycle)
  int    _heartRate = 72;     // HR courant (mis à jour progressivement)
  double _hrPhase   = 0.0;    // Phase pour la variation de HR

  // ── Timers & Streams ──────────────────────────────────────────────────────────
  Timer? _emitTimer;
  Timer? _scenarioTimer;

  final StreamController<List<int>> _ecgController =
      StreamController<List<int>>.broadcast();

  final StreamController<BleConnectionUpdate> _connectionController =
      StreamController<BleConnectionUpdate>.broadcast();

  // ── Getters publics (interface identique à BleService) ───────────────────────
  Stream<List<int>>         get ecgDataStream        => _ecgController.stream;
  Stream<BleConnectionUpdate> get connectionStateStream =>
      _connectionController.stream;
  bool   get isConnected        => _isConnected;
  bool   get isConnecting       => false; // Le mock se connecte instantanément
  String? get connectedDeviceId => _isConnected ? 'mock-movesense-0000' : null;
  int?   get batteryLevel       => 87;    // Batterie fictive stable
  double? get temperature       => 36.6; // Température corporelle fictive

  /// Scénario courant (pour affichage UI optionnel)
  MockScenario get currentScenario => _currentScenario;

  /// Nombre de paquets émis depuis le démarrage (validation)
  int get packetCount => _packetCount;

  // ── API publique (mêmes signatures que BleService) ───────────────────────────

  /// Simule un scan : retourne immédiatement un "appareil mock"
  Stream<MockDevice> scanForDevicesStream() async* {
    debugPrint('[MOCK] 📡 Scan simulé — appareil mock détecté instantanément.');
    await Future.delayed(const Duration(milliseconds: 200));
    yield MockDevice(id: 'mock-movesense-0000', name: 'Movesense Mock 00:00');
  }

  /// Simule une connexion BLE instantanée
  Future<bool> connectToDevice(String deviceId) async {
    debugPrint('[MOCK] 🔗 Connexion simulée à: $deviceId');
    await Future.delayed(const Duration(milliseconds: 300));
    _isConnected = true;
    _connectionController.add(BleConnectionUpdate(
      isConnected: true,
      isDiscovering: false,
      deviceId: deviceId,
    ));
    debugPrint('[MOCK] ✅ Connecté (simulation) — prêt à streamer.');
    return true;
  }

  /// Simule une déconnexion
  Future<void> disconnectDevice(String deviceId) async {
    debugPrint('[MOCK] 🔌 Déconnexion simulée.');
    await stopECGStream();
    _isConnected = false;
    _connectionController.add(BleConnectionUpdate(
      isConnected: false,
      isDiscovering: false,
      deviceId: null,
    ));
  }

  /// Démarre la génération et l'émission des paquets ECG simulés
  Future<void> startECGStream(String deviceId) async {
    if (_isStreaming) {
      debugPrint('[MOCK] ⚠️ Stream déjà actif.');
      return;
    }

    debugPrint('[MOCK] ▶️ Démarrage stream ECG simulation (scénario: ${_currentScenario.name})');
    _isStreaming  = true;
    _packetCount  = 0;
    _ecgPhase     = 0.0;

    // Rotation automatique des scénarios pour tester le pipeline complet
    _scenarioTimer = Timer.periodic(_scenarioDuration, (_) => _rotateScenario());

    // Émission des paquets à 4 Hz
    _emitTimer = Timer.periodic(
      Duration(milliseconds: (1000 ~/ _emitHz).toInt()),
      (_) => _emitPacket(),
    );
  }

  /// Arrête proprement la génération
  Future<void> stopECGStream() async {
    _emitTimer?.cancel();
    _emitTimer = null;
    _scenarioTimer?.cancel();
    _scenarioTimer = null;
    _isStreaming = false;
    debugPrint('[MOCK] ⏹️ Stream ECG arrêté — $_packetCount paquets émis.');
  }

  /// Lecture batterie (fictif)
  Future<int?> readBatteryLevel(String deviceId) async => 87;

  /// Lecture température (fictif)
  Future<double?> readTemperature(String deviceId) async => 36.6;

  /// Libère toutes les ressources
  void dispose() {
    stopECGStream();
    _ecgController.close();
    _connectionController.close();
    debugPrint('[MOCK] 🗑️ BleServiceMock disposed.');
  }

  // ── Génération du signal ECG ─────────────────────────────────────────────────

  void _emitPacket() {
    // 1. Mettre à jour le HR progressivement (variation naturelle)
    _updateHeartRate();

    // 2. Générer N échantillons ECG pour ce paquet
    final samples = <int>[];
    final stepPerSample = 1.0 / (_heartRate * _samplesPerPacket / _emitHz);

    for (int i = 0; i < _samplesPerPacket; i++) {
      samples.add(_generateEcgSample(_ecgPhase));
      _ecgPhase = (_ecgPhase + stepPerSample) % 1.0;
    }

    // 3. Construire le paquet BLE :
    //    [0x00 (flags HR 8-bit), heartRate, sample0, sample1, sample2, sample3]
    final packet = <int>[
      0x00,       // flags : HR sur 8 bits
      _heartRate, // FC courante
      ...samples, // Échantillons ECG 12-bit
    ];

    _ecgController.add(packet);
    _packetCount++;

    // Log périodique (toutes les 40 paquets ≈ 10 s)
    if (_packetCount % 40 == 0) {
      debugPrint(
        '[MOCK] 📊 Monitoring — '
        'scénario=${_currentScenario.name} | HR=$_heartRate | '
        'paquets=$_packetCount',
      );
    }
  }

  /// Génère un échantillon ECG 12-bit (0-4095) centré sur 2048.
  ///
  /// Modèle simplifié P-QRS-T :
  ///  • phase 0.00-0.08 : onde P (dépolarisation auriculaire)
  ///  • phase 0.08-0.12 : segment PR (isoélectrique)
  ///  • phase 0.12-0.20 : complexe QRS (dépolarisation ventriculaire)
  ///  • phase 0.20-0.35 : segment ST (plateau)
  ///  • phase 0.35-0.55 : onde T (repolarisation ventriculaire)
  ///  • phase 0.55-1.00 : ligne isoélectrique + bruit
  int _generateEcgSample(double phase) {
    double value = 0.0;

    // ── Onde P ────────────────────────────────────────────────────────────────
    if (phase >= 0.00 && phase < 0.08) {
      final t = (phase - 0.00) / 0.08;
      value = 0.15 * sin(t * pi); // Petite onde positive arrondie
    }
    // ── Segment PR (isoélectrique) ────────────────────────────────────────────
    else if (phase >= 0.08 && phase < 0.12) {
      value = 0.0;
    }
    // ── Complexe QRS ──────────────────────────────────────────────────────────
    else if (phase >= 0.12 && phase < 0.20) {
      final t = (phase - 0.12) / 0.08;
      if (t < 0.15) {
        // Onde Q (petite déflexion négative)
        value = -0.10 * sin(t / 0.15 * pi);
      } else if (t < 0.50) {
        // Pic R (déflexion positive majeure)
        final r = (t - 0.15) / 0.35;
        value = sin(r * pi);
      } else {
        // Onde S (déflexion négative brève)
        final s = (t - 0.50) / 0.50;
        value = -0.25 * sin(s * pi);
      }
    }
    // ── Segment ST (plateau isoélectrique léger) ──────────────────────────────
    else if (phase >= 0.20 && phase < 0.35) {
      // Légère surélévation ST en mode critique (simulation anomalie)
      value = (_currentScenario == MockScenario.critical) ? 0.12 : 0.02;
    }
    // ── Onde T ────────────────────────────────────────────────────────────────
    else if (phase >= 0.35 && phase < 0.55) {
      final t = (phase - 0.35) / 0.20;
      value = 0.35 * sin(t * pi);
      // Onde T aplatie en mode warning
      if (_currentScenario == MockScenario.warning) value *= 0.6;
    }
    // ── Ligne isoélectrique ───────────────────────────────────────────────────
    else {
      value = 0.0;
    }

    // Bruit physiologique gaussien (centré sur 0)
    final noise = (_rng.nextDouble() - 0.5) * 2.0 * _noiseLevel / _ecgAmplitude;

    // Bruit supplémentaire en mode critique (artefacts musculaires)
    final artifactNoise = (_currentScenario == MockScenario.critical)
        ? (_rng.nextDouble() - 0.5) * 0.08
        : 0.0;

    // Conversion en ADC 12-bit
    final raw = _ecgCenter + ((value + noise + artifactNoise) * _ecgAmplitude).round();
    return raw.clamp(0, 4095);
  }

  /// Met à jour la FC avec une variation progressive et naturelle.
  void _updateHeartRate() {
    final range = _hrRanges[_currentScenario]!;
    _hrPhase += 0.01;
    // Variation sinusoïdale ±5 bpm autour de la cible centrale
    final center = (range.hrMin + range.hrMax) / 2.0;
    final halfRange = (range.hrMax - range.hrMin) / 2.0;
    final targetHr = (center + sin(_hrPhase) * halfRange * 0.7).round();
    // Glissement progressif (évite les sauts brusques)
    if (_heartRate < targetHr) {
      _heartRate = min(_heartRate + 1, targetHr);
    } else if (_heartRate > targetHr) {
      _heartRate = max(_heartRate - 1, targetHr);
    }
    _heartRate = _heartRate.clamp(range.hrMin, range.hrMax);
  }

  /// Passe au scénario suivant dans le cycle normal → warning → critical → normal
  void _rotateScenario() {
    _currentScenario = switch (_currentScenario) {
      MockScenario.normal   => MockScenario.warning,
      MockScenario.warning  => MockScenario.critical,
      MockScenario.critical => MockScenario.normal,
    };
    debugPrint('[MOCK] 🔄 Nouveau scénario de test : ${_currentScenario.name}');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MockDevice – Représente un "appareil BLE" fictif découvert lors du scan mock.
// Mimique le sous-ensemble de DiscoveredDevice utilisé dans AppProvider.
// ─────────────────────────────────────────────────────────────────────────────
class MockDevice {
  final String id;
  final String name;
  const MockDevice({required this.id, required this.name});
}
