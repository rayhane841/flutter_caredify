import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ecg_reading.dart';
import '../models/patient_profile.dart';
import '../services/auth_service.dart';
import '../services/ble_service.dart';

class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final double? speedAccuracy;

  Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    this.speedAccuracy,
  });
}

// ✅ Ajout de l'état "safe"
enum EmergencyState { none, pending, confirmed, safe }

class AppProvider extends ChangeNotifier {
  int _heartRate = 72;
  int _riskScore = 18;
  HealthStatus _healthStatus = HealthStatus.normal;
  bool _isMonitoring = false;
  EmergencyState _emergencyState = EmergencyState.none;
  int _emergencyCountdown = 600;
  final bool _sensorConnected = true;

  PatientProfile _profile = PatientProfile.defaultProfile;
  List<EcgReading> _history = [];
  EcgReading? _lastReading;

  String? _aiClass;
  double? _aiScore;
  bool _aiAlertPending = false;
  bool _cardiologistConfirmed = false;

  bool _locationEnabled = true;
  Position? _currentPosition;
  Timer? _positionTimer;

  Timer? _monitoringTimer;
  Timer? _countdownTimer;
  double _phase = 0;
  final Random _random = Random();

  VoidCallback? onNavigateToTab;

  final AuthService _authService = AuthService();
  AuthService get authService => _authService;

  final BleService _bleService = BleService();
  List<double> _realEcgData = [];
  String _bleStatus = 'idle';
  String _connectedDeviceName = '';

  StreamSubscription? _ecgSubscription;
  StreamSubscription? _bleStatusSubscription;
  StreamSubscription? _scanSubscription;
  bool _autoScanActive = false;

  List<double> get realEcgData => _realEcgData;
  String get bleStatus => _bleStatus;
  String get connectedDeviceName => _connectedDeviceName;

  int get heartRate => _heartRate;
  int get riskScore => _riskScore;
  HealthStatus get healthStatus => _healthStatus;
  bool get isMonitoring => _isMonitoring;
  EmergencyState get emergencyState => _emergencyState;
  int get emergencyCountdown => _emergencyCountdown;
  bool get sensorConnected => _sensorConnected;
  PatientProfile get profile => _profile;
  List<EcgReading> get history => _history;
  EcgReading? get lastReading => _lastReading;
  String? get aiClass => _aiClass;
  double? get aiScore => _aiScore;
  bool get aiAlertPending => _aiAlertPending;
  bool get cardiologistConfirmed => _cardiologistConfirmed;
  bool get locationEnabled => _locationEnabled;
  Position? get currentPosition => _currentPosition;

  bool get hasActiveEmergencyFromAI =>
      _cardiologistConfirmed && _emergencyState != EmergencyState.none;

  String get emergencyCountdownFormatted {
    final minutes = _emergencyCountdown ~/ 60;
    final seconds = _emergencyCountdown % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  AppProvider() {
    _loadData();
    _listenToConnectionState();
  }

  void _listenToConnectionState() {
    _bleStatusSubscription = _bleService.connectionStateStream.listen((update) {
      if (!update.isConnected && _bleStatus == 'connected') {
        _isMonitoring = false;
        _bleStatus = 'disconnected';
        _realEcgData = [];
        _heartRate = 0;
        notifyListeners();
        Future.delayed(const Duration(seconds: 2), () {
          if (_bleStatus == 'disconnected') startAutoScan();
        });
      }
    });
  }

  Future<void> startAutoScan() async {
    if (_autoScanActive) return;
    _autoScanActive = true;
    _bleStatus = 'scanning';
    notifyListeners();

    _scanSubscription =
        _bleService.scanForDevicesStream().listen((device) async {
      if (device.name.contains('Movesense') && _autoScanActive) {
        await _scanSubscription?.cancel();
        _scanSubscription = null;
        _autoScanActive = false;
        _bleStatus = 'connecting';
        notifyListeners();

        final success = await _bleService.connectToDevice(device.id);
        if (success) {
          _connectedDeviceName = device.name;
          _bleStatus = 'connected';
          _isMonitoring = true;
          notifyListeners();
          await _bleService.startECGStream(device.id);
          _ecgSubscription = _bleService.ecgDataStream.listen((rawData) {
            final doubles = rawData.map((v) => v / 1000.0).toList();
            for (final point in doubles) {
              _realEcgData.add(point);
              if (_realEcgData.length > 500) _realEcgData.removeAt(0);
            }
            if (rawData.length >= 2) {
              final flags = rawData[0];
              final isHr16bit = (flags & 0x01) != 0;
              if (!isHr16bit && rawData[1] > 20 && rawData[1] < 250) {
                _heartRate = rawData[1];
              } else if (isHr16bit && rawData.length >= 3) {
                final hr16 = rawData[1] | (rawData[2] << 8);
                if (hr16 > 20 && hr16 < 250) _heartRate = hr16;
              }
            }
            notifyListeners();
          });
        } else {
          _bleStatus = 'scanning';
          notifyListeners();
          await Future.delayed(const Duration(seconds: 2));
          startAutoScan();
        }
      }
    }, onError: (e) {
      _autoScanActive = false;
      _bleStatus = 'idle';
      notifyListeners();
    });
  }

  Future<void> stopAutoScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _ecgSubscription?.cancel();
    _ecgSubscription = null;
    final deviceId = _bleService.connectedDeviceId;
    if (_bleService.isConnected && deviceId != null) {
      await _bleService.disconnectDevice(deviceId);
    }
    _autoScanActive = false;
    _bleStatus = 'idle';
    _isMonitoring = false;
    _realEcgData = [];
    _connectedDeviceName = '';
    notifyListeners();
  }

  Future<void> _saveMonitoringState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_monitoring', _isMonitoring);
    } catch (e) {
      debugPrint('❌ Error saving monitoring state: $e');
    }
  }

  Future<void> _loadAndResumeMonitoring() async {
    try {
      final user = _authService.currentUser;
      if (user == null) return;
      final prefs = await SharedPreferences.getInstance();
      final wasMonitoring = prefs.getBool('is_monitoring') ?? false;
      if (wasMonitoring) {
        _isMonitoring = true;
        _phase = 0;
        notifyListeners();
        _monitoringTimer?.cancel();
        _monitoringTimer =
            Timer.periodic(const Duration(milliseconds: 800), (_) {
          _phase += 0.3;
          const baseHR = 72;
          final variance = sin(_phase) * 8 + (_random.nextDouble() - 0.5) * 6;
          _heartRate = (baseHR + variance).round().clamp(40, 200);
          const baseRisk = 18;
          final riskVariance =
              sin(_phase * 0.7) * 5 + (_random.nextDouble() - 0.5) * 3;
          _riskScore = (baseRisk + riskVariance).round().clamp(5, 95);
          _healthStatus = _riskScore < 35
              ? HealthStatus.normal
              : _riskScore < 65
                  ? HealthStatus.suspect
                  : HealthStatus.critical;
          notifyListeners();
        });
      }
    } catch (e) {
      debugPrint('❌ Error resuming monitoring: $e');
    }
  }

  Future<void> initializeAfterAuth() async {
    final user = _authService.currentUser;
    if (user != null) {
      final userData = await _authService.getPatientData(user.id);
      if (userData != null) updateProfileFromMap(userData);
    }
    await _loadAndResumeMonitoring();
    if (_locationEnabled) await _startLocationTracking();
    notifyListeners();
  }

  Future<void> enableLocation(bool enabled) async {
    _locationEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('location_enabled', enabled);
    if (enabled) {
      await _startLocationTracking();
    } else {
      _stopLocationTracking();
    }
    notifyListeners();
  }

  void updateCurrentPosition(Position position) {
    _currentPosition = position;
    notifyListeners();
  }

  Future<Position?> getLastKnownPosition() async => _currentPosition;

  Future<void> _startLocationTracking() async {
    try {
      _simulatePositionUpdate();
    } catch (e) {
      debugPrint('❌ [GPS] Erreur : $e');
    }
  }

  void _stopLocationTracking() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  void _simulatePositionUpdate() {
    _currentPosition = Position(
      latitude: 36.8065 + (_random.nextDouble() - 0.5) * 0.001,
      longitude: 10.1815 + (_random.nextDouble() - 0.5) * 0.001,
      timestamp: DateTime.now(),
      accuracy: 10,
      altitude: 10,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    notifyListeners();
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_locationEnabled) {
        _simulatePositionUpdate();
      } else {
        timer.cancel();
      }
    });
  }

  void onAiAnalysisResult({required String aiClass, required double aiScore}) {
    _aiClass = aiClass;
    _aiScore = aiScore;
    if (aiClass == 'critique' && aiScore >= 0.75) {
      _aiAlertPending = true;
      _healthStatus = HealthStatus.critical;
      _riskScore = (aiScore * 100).round().clamp(75, 100);
      _emergencyState = EmergencyState.pending;
    } else if (aiClass == 'suspect') {
      _healthStatus = HealthStatus.suspect;
      _riskScore = (aiScore * 100).round().clamp(35, 74);
      _aiAlertPending = false;
    } else {
      _healthStatus = HealthStatus.normal;
      _riskScore = (aiScore * 100).round().clamp(0, 34);
      _aiAlertPending = false;
    }
    notifyListeners();
  }

  void onCardiologistConfirmed() {
    if (_emergencyState == EmergencyState.pending) {
      _cardiologistConfirmed = true;
      _aiAlertPending = false;
      confirmEmergency();
    }
  }

  void onCardiologistDismissed() {
    _aiAlertPending = false;
    _cardiologistConfirmed = false;
    _emergencyState = EmergencyState.none;
    notifyListeners();
  }

  void resetAiResult() {
    _aiClass = null;
    _aiScore = null;
    _aiAlertPending = false;
    notifyListeners();
  }

  void updateProfileFromMap(Map<String, dynamic> data) {
    _profile = PatientProfile(
      name: _safeString(data['name'], 'Utilisateur'),
      age: data['age'] ?? 0,
      bloodType: _safeString(data['blood_type'], '?'),
      patientId: _safeString(data['patient_id'], '---'),
      cardiologist: _safeString(data['cardiologist'], ''),
      emergencyContact: _safeString(data['emergency_contact'], ''),
      conditions: _safeStringList(data['conditions']),
      medications: _safeStringList(data['medications']),
    );
    notifyListeners();
  }

  String _safeString(dynamic value, String defaultValue) {
    if (value == null) return defaultValue;
    final str = value.toString().trim();
    return str.isEmpty ? defaultValue : str;
  }

  List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    }
    return [];
  }

  Future<void> _saveProfileToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('caredify_profile', jsonEncode(_profile.toJson()));
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _locationEnabled = prefs.getBool('location_enabled') ?? true;

    final historyJson = prefs.getString('caredify_history');
    if (historyJson != null) {
      final list = jsonDecode(historyJson) as List;
      _history = list
          .map((e) => EcgReading.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _history = _generateSampleHistory();
      _saveHistory();
    }

    final profileJson = prefs.getString('caredify_profile');
    if (profileJson != null) {
      final isProfileAlreadySet = _profile.name != 'Utilisateur' &&
          _profile.name != 'Chargement...' &&
          _profile.name.isNotEmpty &&
          _profile.patientId != '---';
      if (!isProfileAlreadySet) {
        _profile = PatientProfile.fromJson(
            jsonDecode(profileJson) as Map<String, dynamic>);
      }
    }

    if (_locationEnabled) await _startLocationTracking();
    notifyListeners();
  }

  List<EcgReading> _generateSampleHistory() {
    final statuses = [
      HealthStatus.normal,
      HealthStatus.normal,
      HealthStatus.suspect,
      HealthStatus.normal,
      HealthStatus.normal,
      HealthStatus.critical,
      HealthStatus.normal,
      HealthStatus.normal
    ];
    final now = DateTime.now();
    return statuses.asMap().entries.map((e) {
      final i = e.key;
      final status = e.value;
      final date = now.subtract(Duration(hours: i * 3 + _random.nextInt(2)));
      final hr = status == HealthStatus.normal
          ? 65 + _random.nextInt(20)
          : status == HealthStatus.suspect
              ? 95 + _random.nextInt(20)
              : 145 + _random.nextInt(30);
      final risk = status == HealthStatus.normal
          ? 10 + _random.nextInt(20)
          : status == HealthStatus.suspect
              ? 45 + _random.nextInt(20)
              : 78 + _random.nextInt(15);
      return EcgReading(
        id: '${now.millisecondsSinceEpoch}-$i',
        timestamp: date,
        heartRate: hr,
        status: status,
        riskScore: risk,
        durationSeconds: 30 + _random.nextInt(60),
      );
    }).toList();
  }

  void startMonitoring() {
    _isMonitoring = true;
    _saveMonitoringState();
    _phase = 0;
    notifyListeners();
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _phase += 0.3;
      const baseHR = 72;
      final variance = sin(_phase) * 8 + (_random.nextDouble() - 0.5) * 6;
      _heartRate = (baseHR + variance).round().clamp(40, 200);
      const baseRisk = 18;
      final riskVariance =
          sin(_phase * 0.7) * 5 + (_random.nextDouble() - 0.5) * 3;
      _riskScore = (baseRisk + riskVariance).round().clamp(5, 95);
      _healthStatus = _riskScore < 35
          ? HealthStatus.normal
          : _riskScore < 65
              ? HealthStatus.suspect
              : HealthStatus.critical;
      notifyListeners();
    });
  }

  void stopMonitoring() {
    _isMonitoring = false;
    _saveMonitoringState();
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    final reading = EcgReading(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      timestamp: DateTime.now(),
      heartRate: _heartRate,
      status: _healthStatus,
      riskScore: _riskScore,
      durationSeconds: 45,
    );
    _lastReading = reading;
    _history = [reading, ..._history].take(50).toList();
    _saveHistory();
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  // ✅ URGENCE — avec nouvel état "safe"
  // ════════════════════════════════════════════════════════

  void triggerEmergency() {
    _emergencyState = EmergencyState.pending;
    notifyListeners();
  }

  void confirmEmergency() {
    _emergencyState = EmergencyState.confirmed;
    _emergencyCountdown = 600;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_emergencyCountdown > 0) {
        _emergencyCountdown--;
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
      }
    });
    notifyListeners();
  }

  // ✅ NOUVEAU — cardiologue a annulé → patient est sain
  void setEmergencySafe() {
    _emergencyState = EmergencyState.safe;
    _cardiologistConfirmed = false;
    _aiAlertPending = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    notifyListeners();
  }

  void cancelEmergency() {
    _emergencyState = EmergencyState.none;
    _emergencyCountdown = 600;
    _cardiologistConfirmed = false;
    _aiAlertPending = false;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    notifyListeners();
  }

  void deleteHistoryItem(String readingId) {
    _history = _history.where((r) => r.id != readingId).toList();
    _saveHistory();
    notifyListeners();
  }

  void clearAllHistory() {
    _history = [];
    _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'caredify_history',
      jsonEncode(_history.map((e) => e.toJson()).toList()),
    );
  }

  void navigateToDashboard() {
    if (onNavigateToTab != null) onNavigateToTab!();
  }

  void updateProfile(PatientProfile profile) async {
    _profile = profile;
    await _saveProfileToPrefs();
    notifyListeners();
  }

  Future<void> onLogout() async {
    if (_isMonitoring) stopMonitoring();
    await stopAutoScan();
    if (_locationEnabled) _stopLocationTracking();
    cancelEmergency();
    resetAiResult();
  }

  @override
  void dispose() {
    _monitoringTimer?.cancel();
    _countdownTimer?.cancel();
    _positionTimer?.cancel();
    _stopLocationTracking();
    _scanSubscription?.cancel();
    _ecgSubscription?.cancel();
    _bleStatusSubscription?.cancel();
    super.dispose();
  }
}
