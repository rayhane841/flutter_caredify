// Academic prototype – not for clinical use
// ─────────────────────────────────────────────────────────────────────────────
// BleServiceAuto – Orchestrateur intelligent Real/Mock pour CAREDIFY
//
// Détecte automatiquement la présence d'un bracelet Movesense via BLE.
// • Bracelet trouvé dans les 10 s  → Mode RÉEL  (BleService)
// • Aucun bracelet dans les 10 s   → Mode SIMULATION (BleServiceMock)
//
// L'UI n'a rien à faire : appeler autoInitialize() et écouter les streams.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'ble_service.dart';
import 'ble_service_mock.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Enum des modes de fonctionnement
// ─────────────────────────────────────────────────────────────────────────────
enum BleMode {
  /// Données réelles provenant du bracelet Movesense physique
  real,
  /// Données simulées (aucun bracelet disponible)
  mock,
  /// En cours de détection (scan initial)
  detecting,
}

// ─────────────────────────────────────────────────────────────────────────────
// BleServiceAuto
// ─────────────────────────────────────────────────────────────────────────────
class BleServiceAuto {
  // ── Singleton ─────────────────────────────────────────────────────────────
  static final BleServiceAuto _instance = BleServiceAuto._internal();
  factory BleServiceAuto() => _instance;
  BleServiceAuto._internal();

  // ── Sous-services ─────────────────────────────────────────────────────────
  final BleService      _realService = BleService();
  final BleServiceMock  _mockService = BleServiceMock();

  // ── État ──────────────────────────────────────────────────────────────────
  BleMode _mode           = BleMode.detecting;
  bool    _initialized    = false;
  bool    _disposed       = false;
  String  _connectedName  = '';

  // ── Streams publics (façade unifiée) ───────────────────────────────────────
  //
  // On utilise un StreamController de relais pour pouvoir rediriger la source
  // (real → mock ou mock → real) à chaud sans changer l'abonné en amont.
  final StreamController<List<int>> _ecgRelay =
      StreamController<List<int>>.broadcast();

  final StreamController<BleConnectionUpdate> _connectionRelay =
      StreamController<BleConnectionUpdate>.broadcast();

  final StreamController<BleMode> _modeRelay =
      StreamController<BleMode>.broadcast();

  // Abonnements internes aux sources actives
  StreamSubscription<List<int>>?         _ecgSub;
  StreamSubscription<BleConnectionUpdate>? _connSub;
  StreamSubscription<DiscoveredDevice>?  _scanSub;

  // ── Getters publics (interface identique à BleService) ────────────────────
  Stream<List<int>>           get ecgDataStream        => _ecgRelay.stream;
  Stream<BleConnectionUpdate> get connectionStateStream => _connectionRelay.stream;
  Stream<BleMode>             get modeChangedStream     => _modeRelay.stream;

  /// Mode actuel : 'real', 'mock', ou 'detecting'
  BleMode get currentMode => _mode;

  /// Nom lisible du mode courant (pour l'UI)
  String get currentModeLabel => switch (_mode) {
    BleMode.real      => 'real',
    BleMode.mock      => 'mock',
    BleMode.detecting => 'detecting',
  };

  bool get isConnected {
    return switch (_mode) {
      BleMode.real      => _realService.isConnected,
      BleMode.mock      => _mockService.isConnected,
      BleMode.detecting => false,
    };
  }

  bool get isConnecting => _mode == BleMode.detecting;

  String? get connectedDeviceId {
    return switch (_mode) {
      BleMode.real      => _realService.connectedDeviceId,
      BleMode.mock      => _mockService.connectedDeviceId,
      BleMode.detecting => null,
    };
  }

  String get connectedDeviceName => _connectedName;

  int? get batteryLevel {
    return switch (_mode) {
      BleMode.real      => _realService.batteryLevel,
      BleMode.mock      => _mockService.batteryLevel,
      BleMode.detecting => null,
    };
  }

  double? get temperature {
    return switch (_mode) {
      BleMode.real      => _realService.temperature,
      BleMode.mock      => _mockService.temperature,
      BleMode.detecting => null,
    };
  }

  // ── API principale ─────────────────────────────────────────────────────────

  /// Point d'entrée unique. Doit être appelé UNE SEULE FOIS (depuis AppProvider
  /// ou initState). Gère tout automatiquement.
  ///
  /// Retourne le mode choisi après détection.
  Future<BleMode> autoInitialize() async {
    if (_initialized) {
      debugPrint('[BLE_AUTO] ⚠️ Déjà initialisé (mode: ${_mode.name}). Ignoré.');
      return _mode;
    }
    _initialized = true;
    _setMode(BleMode.detecting);

    debugPrint('[BLE_AUTO] 🔍 Scan en cours... (timeout 10 s)');

    // Tentative de détection d'un Movesense physique
    final found = await _detectMovesense(timeout: const Duration(seconds: 10));

    if (found != null) {
      await _activateRealMode(found);
    } else {
      await _activateMockMode();
    }

    return _mode;
  }

  /// Délègue un scan au service actif.
  /// En mode mock, retourne immédiatement le "mock device".
  Stream<dynamic> scanForDevicesStream() {
    return switch (_mode) {
      BleMode.real || BleMode.detecting => _realService.scanForDevicesStream(),
      BleMode.mock                      => _mockService.scanForDevicesStream(),
    };
  }

  /// Connexion à un appareil (délégation au service actif).
  Future<bool> connectToDevice(String deviceId) async {
    return switch (_mode) {
      BleMode.real || BleMode.detecting =>
        _realService.connectToDevice(deviceId),
      BleMode.mock =>
        _mockService.connectToDevice(deviceId),
    };
  }

  /// Démarrage du stream ECG (délégation).
  Future<void> startECGStream(String deviceId) async {
    return switch (_mode) {
      BleMode.real || BleMode.detecting =>
        _realService.startECGStream(deviceId),
      BleMode.mock =>
        _mockService.startECGStream(deviceId),
    };
  }

  /// Arrêt du stream ECG (délégation).
  Future<void> stopECGStream() async {
    return switch (_mode) {
      BleMode.real || BleMode.detecting =>
        _realService.stopECGStream(),
      BleMode.mock =>
        _mockService.stopECGStream(),
    };
  }

  /// Déconnexion (délégation).
  Future<void> disconnectDevice(String deviceId) async {
    return switch (_mode) {
      BleMode.real || BleMode.detecting =>
        _realService.disconnectDevice(deviceId),
      BleMode.mock =>
        _mockService.disconnectDevice(deviceId),
    };
  }

  /// Force un basculement vers le mode Mock (utile pour tests unitaires).
  Future<void> forceSimulationMode() async {
    if (_mode == BleMode.mock) return;
    debugPrint('[BLE_AUTO] 🔧 Basculement forcé → mode SIMULATION.');
    // Arrêter le mode réel proprement
    if (_realService.isConnected && _realService.connectedDeviceId != null) {
      await _realService.stopECGStream();
      await _realService.disconnectDevice(_realService.connectedDeviceId!);
    }
    await _activateMockMode();
  }

  /// Libère toutes les ressources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _cleanupSubscriptions();
    await _mockService.stopECGStream();
    _ecgRelay.close();
    _connectionRelay.close();
    _modeRelay.close();
    debugPrint('[BLE_AUTO] 🗑️ BleServiceAuto disposed.');
  }

  // ── Détection ──────────────────────────────────────────────────────────────

  /// Lance un scan BLE limité dans le temps.
  /// Retourne le premier [DiscoveredDevice] Movesense trouvé, ou null si timeout.
  Future<DiscoveredDevice?> _detectMovesense({required Duration timeout}) async {
    final completer = Completer<DiscoveredDevice?>();

    try {
      _scanSub = _realService.scanForDevicesStream().listen(
        (device) {
          if (device.name.contains('Movesense') && !completer.isCompleted) {
            debugPrint('[BLE_AUTO] 📡 Movesense détecté: ${device.name} (${device.id})');
            completer.complete(device);
          }
        },
        onError: (e) {
          debugPrint('[BLE_AUTO] ⚠️ Erreur scan: $e');
          if (!completer.isCompleted) completer.complete(null);
        },
      );

      // Timeout
      final result = await completer.future.timeout(
        timeout,
        onTimeout: () {
          debugPrint('[BLE_AUTO] ⏱️ Timeout scan — aucun Movesense trouvé.');
          return null;
        },
      );

      await _scanSub?.cancel();
      _scanSub = null;
      return result;
    } catch (e) {
      debugPrint('[BLE_AUTO] ❌ Exception détection: $e');
      await _scanSub?.cancel();
      _scanSub = null;
      return null;
    }
  }

  // ── Activation des modes ───────────────────────────────────────────────────

  Future<void> _activateRealMode(DiscoveredDevice device) async {
    debugPrint('[BLE_AUTO] 🔗 Connexion au bracelet réel: ${device.name}');

    final connected = await _realService.connectToDevice(device.id);
    if (!connected) {
      debugPrint('[BLE_AUTO] ❌ Connexion échouée → fallback simulation.');
      await _activateMockMode();
      return;
    }

    _connectedName = device.name;
    _setMode(BleMode.real);

    // Relayer le stream ECG réel
    await _ecgSub?.cancel();
    _ecgSub = _realService.ecgDataStream.listen(
      (data) { if (!_ecgRelay.isClosed) _ecgRelay.add(data); },
      onError: (e) { if (!_ecgRelay.isClosed) _ecgRelay.addError(e); },
    );

    // Relayer les changements d'état de connexion
    await _connSub?.cancel();
    _connSub = _realService.connectionStateStream.listen((update) {
      if (!_connectionRelay.isClosed) _connectionRelay.add(update);
      // Auto-fallback mock si déconnexion inattendue
      if (!update.isConnected && _mode == BleMode.real) {
        debugPrint('[BLE_AUTO] 📴 Bracelet déconnecté → basculement simulation.');
        _activateMockMode();
      }
    });

    // Démarrer le stream ECG réel
    await _realService.startECGStream(device.id);

    debugPrint('[BLE_AUTO] ✅ Mode RÉEL activé – Movesense détecté et connecté.');
  }

  Future<void> _activateMockMode() async {
    _connectedName = 'Movesense Mock';
    _setMode(BleMode.mock);

    // Connecter le mock (instantané)
    await _mockService.connectToDevice('mock-movesense-0000');

    // Relayer le stream ECG du mock
    await _ecgSub?.cancel();
    _ecgSub = _mockService.ecgDataStream.listen(
      (data) { if (!_ecgRelay.isClosed) _ecgRelay.add(data); },
      onError: (e) { if (!_ecgRelay.isClosed) _ecgRelay.addError(e); },
    );

    // Relayer les changements d'état du mock
    await _connSub?.cancel();
    _connSub = _mockService.connectionStateStream.listen((update) {
      if (!_connectionRelay.isClosed) _connectionRelay.add(update);
    });

    // Démarrer la génération ECG simulée
    await _mockService.startECGStream('mock-movesense-0000');

    debugPrint('[BLE_AUTO] 🎭 Mode SIMULATION activé – données de test en cours.');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _setMode(BleMode mode) {
    _mode = mode;
    if (!_modeRelay.isClosed) _modeRelay.add(mode);
  }

  Future<void> _cleanupSubscriptions() async {
    await _ecgSub?.cancel();
    _ecgSub = null;
    await _connSub?.cancel();
    _connSub = null;
    await _scanSub?.cancel();
    _scanSub = null;
  }
}
