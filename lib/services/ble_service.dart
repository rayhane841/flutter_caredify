import 'dart:async';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BleConnectionUpdate {
  final bool isConnected;
  final bool isDiscovering;
  final String? deviceId;

  BleConnectionUpdate({
    required this.isConnected,
    this.isDiscovering = false,
    this.deviceId,
  });
}

class BleService {
  // Singleton pattern - une seule instance partagée dans toute l'app
  static final BleService _instance = BleService._internal();

  factory BleService() {
    return _instance;
  }

  BleService._internal() {
    // Restaurer l'état de connexion à l'initialisation
    _restoreConnectionState();
  }

  final FlutterReactiveBle _ble = FlutterReactiveBle();

  StreamSubscription? _connectionSubscription;
  StreamSubscription<List<int>>? _internalEcgSubscription;
  StreamSubscription<DiscoveredDevice>? _deviceFoundSubscription;

  // Suivi de l'état de connexion
  String? _connectedDeviceId;
  bool _isConnected = false;
  bool _isConnecting = false;

  // Flags globaux de connexion — accessibles partout
  static bool connect = false;
  static bool isDiscovering = false;

  // Sauvegarder l'état de connexion de façon persistante
  Future<void> _saveConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ble_connected', _isConnected);
      await prefs.setString('ble_device_id', _connectedDeviceId ?? '');
    } catch (e) {
      print('[BLE] Error saving connection state: $e');
    }
  }

  void _notifyStateChange() {
    _connectionStateController.add(
      BleConnectionUpdate(
        isConnected: _isConnected,
        isDiscovering: BleService.isDiscovering,
        deviceId: _connectedDeviceId,
      ),
    );
  }

  // Getters pour accès externe
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get connectedDeviceId => _connectedDeviceId;

  static Future<void> _restoreConnectionState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wasConnected = prefs.getBool('ble_connected') ?? false;
      final deviceId = prefs.getString('ble_device_id');

      if (wasConnected && deviceId != null && deviceId.isNotEmpty) {
        print('[BLE] Restoring previous connection to: $deviceId');
        Future.delayed(const Duration(seconds: 2), () {
          final service = BleService();
          service.connectToDevice(deviceId);
        });
      }
    } catch (e) {
      print('[BLE] Error restoring connection state: $e');
    }
  }

  // Stream de changement d'état de connexion (broadcast)
  final StreamController<BleConnectionUpdate> _connectionStateController =
      StreamController<BleConnectionUpdate>.broadcast();

  Stream<BleConnectionUpdate> get connectionStateStream =>
      _connectionStateController.stream;

  // Stream de données ECG (broadcast)
  final StreamController<List<int>> _ecgDataController =
      StreamController<List<int>>.broadcast();

  Stream<List<int>> get ecgDataStream => _ecgDataController.stream;

  // Batterie et température
  int? _batteryLevel;
  double? _temperature;

  int? get batteryLevel => _batteryLevel;
  double? get temperature => _temperature;

  // ─── UUIDs Movesense ECG ────────────────────────────────────────
  static const String _ecgServiceUuidV1 =
      '00002bd0-0000-1000-8000-00805f9b34fb';
  static const String _ecgCharacteristicUuidV1 =
      '00002bd1-0000-1000-8000-00805f9b34fb';

  static const String _ecgServiceUuidV2 =
      '34800001-7185-4d5d-a111-7001c6403986';
  static const String _ecgCharacteristicUuidV2 =
      '34800002-7185-4d5d-a111-7001c6403986';

  static const String _dataServiceUuidV2 =
      '34800004-7185-4d5d-a111-7001c6403986';
  static const String _dataCharacteristicUuidV2 =
      '34800005-7185-4d5d-a111-7001c6403986';

  static const String _hrServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String _hrCharacteristicUuid =
      '00002a37-0000-1000-8000-00805f9b34fb';

  static const String _batteryServiceUuid =
      '0000180f-0000-1000-8000-00805f9b34fb';
  static const String _batteryCharacteristicUuid =
      '00002a19-0000-1000-8000-00805f9b34fb';


  static const List<Map<String, String>> _temperatureUuidAlternatives = [
    {
      'service': '34800003-7185-4d5d-a111-7001c6403986',
      'characteristic': '34800006-7185-4d5d-a111-7001c6403986',
      'label': 'Movesense Info Service (34800006)'
    },
    {
      'service': '34800004-7185-4d5d-a111-7001c6403986',
      'characteristic': '34800007-7185-4d5d-a111-7001c6403986',
      'label': 'Movesense Alternative (34800007)'
    },
    {
      'service': '00001809-0000-1000-8000-00805f9b34fb',
      'characteristic': '00002a6e-0000-1000-8000-00805f9b34fb',
      'label': 'Standard BLE Health Thermometer'
    },
    {
      'service': '0000180a-0000-1000-8000-00805f9b34fb',
      'characteristic': '00002a6e-0000-1000-8000-00805f9b34fb',
      'label': 'Device Info Service'
    },
  ];

  // ─── Scan ──────────────────────────────────────────────────────

  /// Scanne les appareils BLE et retourne un Stream continu
  Stream<DiscoveredDevice> scanForDevicesStream() {
    print('[SCAN] Starting BLE scan...');
    _deviceFoundSubscription?.cancel();

    return _ble
        .scanForDevices(withServices: [], scanMode: ScanMode.lowLatency)
        .map((device) {
      print('📱 Device found: ${device.name} | ID: ${device.id}');
      if (device.name.contains('Movesense')) {
        print('   ✅ Movesense device detected!');
      }
      return device;
    });
  }

  // ─── Connexion ────────────────────────────────────────────────

  /// Se connecte à un appareil Movesense par son deviceId (timeout 15s)
  Future<bool> connectToDevice(String deviceId) async {
    print('[BLE] 🔄 Starting connection attempt to: $deviceId');

    if (_isConnected && _connectedDeviceId == deviceId) {
      print('[BLE] ✅ Device already connected, reusing existing session.');
      return true;
    }

    if (_isConnecting) {
      print('[BLE] ⚠️ Connection already in progress. Please wait.');
      return false;
    }

    try {
      _isConnecting = true;
      _notifyStateChange();

      if (_connectionSubscription != null &&
          _connectedDeviceId != deviceId) {
        print('[BLE] 🔄 Switching devices. Cancelling previous connection.');
        await _connectionSubscription?.cancel();
        _connectionSubscription = null;
      }

      final connectionCompleter = Completer<bool>();
      bool hasConnected = false;

      final connectionStream = _ble.connectToDevice(id: deviceId);

      _connectionSubscription = connectionStream.listen(
        (state) {
          print('[BLE] Connection state: ${state.connectionState}');
          switch (state.connectionState) {
            case DeviceConnectionState.connected:
              print('✅ Movesense device connected');
              if (!hasConnected) {
                hasConnected = true;
                _isConnecting = false;
                _isConnected = true;
                _connectedDeviceId = deviceId;
                BleService.connect = true;
                BleService.isDiscovering = true;
                _saveConnectionState();
                _notifyStateChange();

                _performServiceDiscovery(deviceId).then((_) {
                  BleService.isDiscovering = false;
                  _notifyStateChange();
                  if (!connectionCompleter.isCompleted) {
                    connectionCompleter.complete(true);
                  }
                }).catchError((error) {
                  print('[BLE] Discovery error: $error');
                  BleService.isDiscovering = false;
                  _notifyStateChange();
                  if (!connectionCompleter.isCompleted) {
                    connectionCompleter.complete(true);
                  }
                });
              }
              break;
            case DeviceConnectionState.disconnected:
              print('❌ Movesense device disconnected');
              if (_connectedDeviceId == deviceId ||
                  _connectedDeviceId == null) {
                _isConnected = false;
                _connectedDeviceId = null;
                BleService.connect = false;
                BleService.isDiscovering = false;
                _saveConnectionState();
                _notifyStateChange();
              }
              break;
            case DeviceConnectionState.connecting:
              print('🔄 Connecting to Movesense device...');
              break;
            case DeviceConnectionState.disconnecting:
              print('🚫 Disconnecting from Movesense device...');
              break;
          }
        },
        onError: (error) {
          print('❌ Connection error: $error');
          _isConnecting = false;
          _isConnected = false;
          _connectedDeviceId = null;
          BleService.connect = false;
          _notifyStateChange();
          if (!connectionCompleter.isCompleted) {
            connectionCompleter.complete(false);
          }
        },
      );

      print('[BLE] ⏳ Waiting for connection or timeout (15 seconds)...');
      final result = await connectionCompleter.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('[BLE] ❌ Connection timeout after 15 seconds');
          _isConnecting = false;
          _connectionSubscription?.cancel();
          _connectionSubscription = null;
          _notifyStateChange();
          return false;
        },
      );

      print('[BLE] 🎯 Connection result: $result');
      return result;
    } catch (e) {
      print('❌ Connection exception: $e');
      _isConnecting = false;
      _notifyStateChange();
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      return false;
    }
  }

  // ─── Déconnexion ──────────────────────────────────────────────

  /// Déconnecte proprement l'appareil courant
  Future<void> disconnectDevice(String deviceId) async {
    try {
      print('[BLE] User requested disconnect from: $deviceId');
      await stopECGStream();
      await _connectionSubscription?.cancel();
      _connectionSubscription = null;
      _isConnected = false;
      _connectedDeviceId = null;
      BleService.connect = false;
      _saveConnectionState();
      _notifyStateChange();
      print('✅ Successfully disconnected from device: $deviceId');
    } catch (e) {
      print('❌ Disconnect error: $e');
    }
  }

  // ─── ECG Stream ───────────────────────────────────────────────

  /// Démarre le stream ECG en essayant les UUIDs dans l'ordre
  Future<void> startECGStream(String deviceId) async {
    int tryCount = 0;
    const maxTries = 3;

    while (tryCount < maxTries) {
      tryCount++;
      try {
        print('[ECG] Starting ECG stream (Attempt $tryCount/$maxTries)');
        await _internalEcgSubscription?.cancel();

        bool success = false;

        // 1. UUID V1
        try {
          success = await _trySubscribeToCharacteristic(
            deviceId,
            _ecgServiceUuidV1,
            _ecgCharacteristicUuidV1,
            'Movesense v1',
          );
        } catch (e) {
          print('[ECG] Movesense v1 error: $e');
        }

        // 2. UUID V2
        if (!success) {
          try {
            success = await _trySubscribeToCharacteristic(
              deviceId,
              _ecgServiceUuidV2,
              _ecgCharacteristicUuidV2,
              'Movesense 2.0 (ECG)',
            );
          } catch (e) {
            print('[ECG] Movesense v2 error: $e');
          }
        }

        // 3. UUID V2 Data
        if (!success) {
          try {
            success = await _trySubscribeToCharacteristic(
              deviceId,
              _dataServiceUuidV2,
              _dataCharacteristicUuidV2,
              'Movesense 2.0 (Data)',
            );
          } catch (e) {
            print('[ECG] Movesense v2 Data error: $e');
          }
        }

        // 4. HR Standard
        if (!success) {
          try {
            success = await _trySubscribeToCharacteristic(
              deviceId,
              _hrServiceUuid,
              _hrCharacteristicUuid,
              'Standard Heart Rate',
            );
          } catch (e) {
            print('[ECG] HR Service error: $e');
          }
        }

        if (success) {
          print('✅ ECG stream active for device: $deviceId');
          return;
        } else {
          print('❌ All known characteristics failed for device: $deviceId');
          if (tryCount >= maxTries) {
            throw Exception('No compatible ECG or HR data characteristic found.');
          }
        }
        return;
      } catch (e) {
        print('❌ Attempt $tryCount failed: $e');
        if (tryCount >= maxTries) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }
  }

  /// Arrête le stream ECG
  Future<void> stopECGStream() async {
    try {
      await _internalEcgSubscription?.cancel();
      _internalEcgSubscription = null;
      print('ECG internal subscription stopped');
    } catch (e) {
      print('Error stopping ECG stream: $e');
    }
  }

  // ─── Helpers privés ───────────────────────────────────────────

  Future<bool> _trySubscribeToCharacteristic(
    String deviceId,
    String serviceUuid,
    String charUuid,
    String label,
  ) async {
    try {
      print('[ECG] Trying $label: Service=$serviceUuid, Char=$charUuid');

      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(serviceUuid),
        characteristicId: Uuid.parse(charUuid),
        deviceId: deviceId,
      );

      final completer = Completer<bool>();
      await _internalEcgSubscription?.cancel();

      _internalEcgSubscription = _ble
          .subscribeToCharacteristic(characteristic)
          .listen(
            (data) {
              if (!completer.isCompleted) {
                print('[ECG] Received first data packet from $label');
                completer.complete(true);
              }
              if (data.isNotEmpty) {
                _ecgDataController.add(data);
              }
            },
            onError: (error) {
              print('[ECG] Error with $label: $error');
              if (!completer.isCompleted) {
                completer.complete(false);
              } else {
                _ecgDataController.addError(error);
              }
            },
            cancelOnError: true,
          );

      return await Future.any([
        completer.future,
        Future.delayed(const Duration(milliseconds: 2000), () => false),
      ]);
    } catch (e) {
      print('[ECG] Exception trying $label: $e');
      return false;
    }
  }

  Future<void> _performServiceDiscovery(String deviceId) async {
    try {
      print('🔍 [DIAG] Starting service discovery for: $deviceId');
      try {
        await _ble
            .requestMtu(deviceId: deviceId, mtu: 247)
            .timeout(const Duration(seconds: 5));
        print('🔍 [DIAG] MTU request sent');
      } catch (e) {
        print('🔍 [DIAG] MTU request failed: $e');
      }

      final services = await _ble.discoverServices(deviceId);
      print('🔍 [DIAG] Found ${services.length} services:');
      for (var service in services) {
        print('   📂 Service: ${service.serviceId}');
        for (var char in service.characteristics) {
          print('      📜 Characteristic: ${char.characteristicId}');
        }
      }
    } catch (e) {
      print('❌ [DIAG] Service discovery error: $e');
    }
  }

  // ─── Batterie / Température ───────────────────────────────────

  Future<int?> readBatteryLevel(String deviceId) async {
    try {
      if (!_isConnected || _connectedDeviceId != deviceId) return null;
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse(_batteryServiceUuid),
        characteristicId: Uuid.parse(_batteryCharacteristicUuid),
        deviceId: deviceId,
      );
      final response = await _ble.readCharacteristic(characteristic);
      if (response.isNotEmpty) {
        _batteryLevel = response[0];
        return _batteryLevel;
      }
      return null;
    } catch (e) {
      print('[BATTERY] Failed to read battery: $e');
      return null;
    }
  }

  Future<double?> readTemperature(String deviceId) async {
    try {
      if (!_isConnected || _connectedDeviceId != deviceId) return null;
      for (var uuidOption in _temperatureUuidAlternatives) {
        try {
          final characteristic = QualifiedCharacteristic(
            serviceId: Uuid.parse(uuidOption['service']!),
            characteristicId: Uuid.parse(uuidOption['characteristic']!),
            deviceId: deviceId,
          );
          final response = await _ble.readCharacteristic(characteristic);
          if (response.length >= 2) {
            int rawValue = response[0] | (response[1] << 8);
            _temperature = rawValue / 100.0;
            return _temperature;
          }
        } catch (e) {
          // Essayer la prochaine alternative
        }
      }
      return null;
    } catch (e) {
      print('[TEMP] Unexpected error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> readDeviceMetrics(String deviceId) async {
    final battery = await readBatteryLevel(deviceId);
    final temperature = await readTemperature(deviceId);
    return {'battery': battery, 'temperature': temperature};
  }

  /// Récupère la liste des services découverts (pour débogage)
  Future<List<String>> getDiscoveredServices(String deviceId) async {
    try {
      final services = await _ble.discoverServices(deviceId);
      List<String> result = [];
      for (var s in services) {
        result.add('Service: ${s.serviceId}');
        for (var c in s.characteristics) {
          result.add('  - Char: ${c.characteristicId}');
        }
      }
      return result;
    } catch (e) {
      return ['Error discovering services: $e'];
    }
  }

  /// Libère les ressources (NE PAS appeler depuis les pages individuelles
  /// si l'on veut garder la connexion active entre les écrans)
  void dispose() {
    print('[BLE] Service dispose called');
    _connectionSubscription?.cancel();
    _internalEcgSubscription?.cancel();
    _deviceFoundSubscription?.cancel();
    _connectionStateController.close();
    _ecgDataController.close();
  }
}
