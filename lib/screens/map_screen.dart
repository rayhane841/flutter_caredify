import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';
import '../providers/app_provider.dart' hide Position;
import '../l10n/app_localizations.dart';

// ─────────────────────────────────────────────
// MapScreen — point d'entrée public
// ─────────────────────────────────────────────
class MapScreen extends StatelessWidget {
  final bool showBackButton;
  const MapScreen({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) =>
      _MapScreenContent(showBackButton: showBackButton);
}

// ─────────────────────────────────────────────
// Modèles
// ─────────────────────────────────────────────
class _MapPoint {
  final String id, type, name, address, distance;
  final double lat, lng;
  const _MapPoint({
    required this.id,
    required this.type,
    required this.name,
    required this.address,
    required this.distance,
    required this.lat,
    required this.lng,
  });
}

class _CardiologistInfo {
  final String userId;
  final String fullName;
  final double? lat;
  final double? lng;
  final bool isSharing;
  final DateTime? updatedAt;

  const _CardiologistInfo({
    required this.userId,
    required this.fullName,
    this.lat,
    this.lng,
    required this.isSharing,
    this.updatedAt,
  });
}

// ─────────────────────────────────────────────
// Liste des serveurs Overpass (fallback chain)
// ─────────────────────────────────────────────
const List<String> _overpassServers = [
  'https://overpass-api.de/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
];

// ─────────────────────────────────────────────
// StatefulWidget principal
// ─────────────────────────────────────────────
class _MapScreenContent extends StatefulWidget {
  final bool showBackButton;
  const _MapScreenContent({required this.showBackButton});
  @override
  State<_MapScreenContent> createState() => _MapScreenContentState();
}

class _MapScreenContentState extends State<_MapScreenContent> {
  final _supabase = Supabase.instance.client;
  final MapController _mapController = MapController();

  String _selectedFilter = 'all';

  LatLng? _userLocation;
  bool _isLoadingLocation = true;

  // ── distingue "GPS off" vs "désactivé dans Settings"
  // _locationError = '' → OK
  // _locationError = 'settings_disabled' → désactivé dans les paramètres
  // _locationError = <autre texte> → erreur GPS système
  String _locationError = '';

  final LatLng _defaultLocation = const LatLng(36.8065, 10.1815);

  _CardiologistInfo? _cardiologist;
  bool _isLoadingCardio = true;
  RealtimeChannel? _cardioChannel;

  List<_MapPoint> _overpassPoints = [];
  bool _isLoadingPoi = false;
  bool _poiFetchInProgress = false;
  String? _lastFetchedKey;

  Timer? _locationTimer;

  // ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadCardiologist();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _cardioChannel?.unsubscribe();
    _setLocationSharing(false);
    super.dispose();
  }

  // ── 1. GPS patient ────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    final app = Provider.of<AppProvider>(context, listen: false);
    if (!app.locationEnabled) {
      // La localisation est désactivée dans les Paramètres de l'appli
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'settings_disabled';
        _userLocation = _defaultLocation;
      });
      _triggerPoiFetch(_defaultLocation.latitude, _defaultLocation.longitude);
      return;
    }

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setDefaultLocation('GPS désactivé');
        _triggerPoiFetch(_defaultLocation.latitude, _defaultLocation.longitude);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setDefaultLocation('Permission refusée');
          _triggerPoiFetch(
              _defaultLocation.latitude, _defaultLocation.longitude);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setDefaultLocation('Permission refusée définitivement');
        _triggerPoiFetch(_defaultLocation.latitude, _defaultLocation.longitude);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final realLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = realLocation;
        _isLoadingLocation = false;
        _locationError = '';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(realLocation, 14.0);
        } catch (_) {}
      });

      await _publishLocation(position.latitude, position.longitude,
          accuracy: position.accuracy);
      _startLocationTimer();
      _triggerPoiFetch(position.latitude, position.longitude);
    } catch (e) {
      _setDefaultLocation('Erreur GPS');
      _triggerPoiFetch(_defaultLocation.latitude, _defaultLocation.longitude);
    }
  }

  void _setDefaultLocation(String error) {
    setState(() {
      _isLoadingLocation = false;
      _locationError = error;
      _userLocation = _defaultLocation;
    });
  }

  void _triggerPoiFetch(double lat, double lng) {
    final key = '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';
    if (_lastFetchedKey == key) return;
    _lastFetchedKey = key;
    _fetchNearbyPoi(lat, lng);
  }

  // ── 2. Supabase location ──────────────────
  Future<void> _publishLocation(double lat, double lng,
      {double? accuracy}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('locations').upsert({
        'user_id': userId,
        'role': 'patient',
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'is_sharing': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      debugPrint('[MapScreen] _publishLocation error: $e');
    }
  }

  Future<void> _setLocationSharing(bool sharing) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('locations').update({
        'is_sharing': sharing,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('user_id', userId);
    } catch (_) {}
  }

  void _startLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final app = Provider.of<AppProvider>(context, listen: false);
      if (!app.locationEnabled) {
        _locationTimer?.cancel();
        return;
      }
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        final newLoc = LatLng(pos.latitude, pos.longitude);
        if (mounted) setState(() => _userLocation = newLoc);
        await _publishLocation(pos.latitude, pos.longitude,
            accuracy: pos.accuracy);
      } catch (_) {}
    });
  }

  // ── 3. Cardiologue référent ───────────────
  Future<void> _loadCardiologist() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _isLoadingCardio = false);
      return;
    }
    try {
      final patientRow = await _supabase
          .from('patients')
          .select('cardiologist_id')
          .eq('id', userId)
          .maybeSingle();

      if (patientRow == null || patientRow['cardiologist_id'] == null) {
        setState(() => _isLoadingCardio = false);
        return;
      }

      final String cardioId = patientRow['cardiologist_id'] as String;

      String cardioName = 'Cardiologue';
      try {
        final profileRow = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', cardioId)
            .maybeSingle();
        if (profileRow != null && profileRow['full_name'] != null) {
          cardioName = profileRow['full_name'] as String;
        }
      } catch (e) {
        debugPrint('[MapScreen] profiles: $e');
      }

      double? cardioLat;
      double? cardioLng;
      bool isSharing = false;
      DateTime? updatedAt;

      try {
        final locRow = await _supabase
            .from('locations')
            .select('lat, lng, is_sharing, updated_at')
            .eq('user_id', cardioId)
            .eq('role', 'carediologue')
            .maybeSingle();

        if (locRow != null) {
          cardioLat = (locRow['lat'] as num?)?.toDouble();
          cardioLng = (locRow['lng'] as num?)?.toDouble();
          isSharing = locRow['is_sharing'] as bool? ?? false;
          updatedAt = locRow['updated_at'] != null
              ? DateTime.tryParse(locRow['updated_at'] as String)
              : null;
        }
      } catch (e) {
        debugPrint('[MapScreen] locations RLS: $e');
      }

      setState(() {
        _cardiologist = _CardiologistInfo(
          userId: cardioId,
          fullName: cardioName,
          lat: cardioLat,
          lng: cardioLng,
          isSharing: isSharing,
          updatedAt: updatedAt,
        );
        _isLoadingCardio = false;
      });

      _subscribeToCardiologist(cardioId);
    } catch (e) {
      debugPrint('[MapScreen] _loadCardiologist error: $e');
      setState(() => _isLoadingCardio = false);
    }
  }

  void _subscribeToCardiologist(String cardiologistId) {
    _cardioChannel?.unsubscribe();
    _cardioChannel = _supabase
        .channel('cardiologist_location_$cardiologistId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: cardiologistId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (mounted) {
              setState(() {
                _cardiologist = _CardiologistInfo(
                  userId: cardiologistId,
                  fullName: _cardiologist?.fullName ?? 'Cardiologue',
                  lat: (row['lat'] as num?)?.toDouble(),
                  lng: (row['lng'] as num?)?.toDouble(),
                  isSharing: row['is_sharing'] as bool? ?? false,
                  updatedAt: row['updated_at'] != null
                      ? DateTime.tryParse(row['updated_at'] as String)
                      : null,
                );
              });
            }
          },
        )
        .subscribe();
  }

  // ── 4. Overpass — fallback chain sur 3 serveurs ───────────────────
  Future<void> _fetchNearbyPoi(double lat, double lng) async {
    if (_poiFetchInProgress) return;
    _poiFetchInProgress = true;
    if (mounted) setState(() => _isLoadingPoi = true);

    const int radius = 80000;
    const int limit = 200;

    final query = '''
[out:json][timeout:30];
(
  node["amenity"="hospital"](around:$radius,$lat,$lng);
  way["amenity"="hospital"](around:$radius,$lat,$lng);
  relation["amenity"="hospital"](around:$radius,$lat,$lng);
  node["amenity"="clinic"](around:$radius,$lat,$lng);
  way["amenity"="clinic"](around:$radius,$lat,$lng);
  node["healthcare"="hospital"](around:$radius,$lat,$lng);
  way["healthcare"="hospital"](around:$radius,$lat,$lng);
  node["emergency"="defibrillator"](around:$radius,$lat,$lng);
);
out center body $limit;
''';

    bool success = false;

    for (final serverUrl in _overpassServers) {
      if (success) break;
      try {
        debugPrint('[MapScreen] Essai Overpass: $serverUrl');
        final response = await http.post(
          Uri.parse(serverUrl),
          body: 'data=${Uri.encodeComponent(query)}',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'User-Agent': 'CaredifyApp/1.0',
          },
        ).timeout(const Duration(seconds: 35));

        if (response.statusCode != 200) {
          debugPrint('[MapScreen] $serverUrl → HTTP ${response.statusCode}');
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = decoded['elements'] as List<dynamic>? ?? [];

        final List<_MapPoint> points = [];
        for (final el in elements) {
          final elMap = el as Map<String, dynamic>;
          final double? elLat = (elMap['lat'] as num?)?.toDouble() ??
              ((elMap['center'] as Map<String, dynamic>?)?['lat'] as num?)
                  ?.toDouble();
          final double? elLng = (elMap['lon'] as num?)?.toDouble() ??
              ((elMap['center'] as Map<String, dynamic>?)?['lon'] as num?)
                  ?.toDouble();

          if (elLat == null || elLng == null) continue;

          final tags = (elMap['tags'] as Map<String, dynamic>?) ?? {};
          final isAed = tags['emergency'] == 'defibrillator';
          final amenity = tags['amenity'] as String? ?? '';
          final healthcare = tags['healthcare'] as String? ?? '';

          final isHospital = amenity == 'hospital' ||
              amenity == 'clinic' ||
              healthcare == 'hospital';
          if (!isAed && !isHospital) continue;

          final type = isAed ? 'aed' : 'hospital';
          final name = (tags['name'] as String?)?.isNotEmpty == true
              ? tags['name'] as String
              : (tags['name:fr'] as String?)?.isNotEmpty == true
                  ? tags['name:fr'] as String
                  : (tags['name:ar'] as String?)?.isNotEmpty == true
                      ? tags['name:ar'] as String
                      : isAed
                          ? 'Défibrillateur automatique'
                          : amenity == 'clinic'
                              ? 'Clinique'
                              : 'Hôpital';

          final dist = Distance().as(
            LengthUnit.Meter,
            LatLng(lat, lng),
            LatLng(elLat, elLng),
          );
          final distLabel = dist < 1000
              ? '${dist.round()} m'
              : '${(dist / 1000).toStringAsFixed(1)} km';

          final address = [
            tags['addr:housenumber'],
            tags['addr:street'],
            tags['addr:city'],
          ].whereType<String>().join(' ').trim();

          points.add(_MapPoint(
            id: '${elMap['type']}_${elMap['id']}',
            type: type,
            name: name,
            address: address,
            distance: distLabel,
            lat: elLat,
            lng: elLng,
          ));
        }

        points.sort((a, b) {
          final dA = Distance()
              .as(LengthUnit.Meter, LatLng(lat, lng), LatLng(a.lat, a.lng));
          final dB = Distance()
              .as(LengthUnit.Meter, LatLng(lat, lng), LatLng(b.lat, b.lng));
          return dA.compareTo(dB);
        });

        if (mounted) setState(() => _overpassPoints = points);
        success = true;
      } catch (e) {
        debugPrint('[MapScreen] $serverUrl ERREUR: $e');
      }
    }

    if (!success) {
      Future.delayed(const Duration(seconds: 15), () {
        if (mounted) {
          _poiFetchInProgress = false;
          _lastFetchedKey = null;
          _triggerPoiFetch(lat, lng);
        }
      });
    }

    _poiFetchInProgress = false;
    if (mounted) setState(() => _isLoadingPoi = false);
  }

  // ── Filtres ───────────────────────────────
  List<_MapPoint> get _filteredPoints {
    if (_selectedFilter == 'all') return _overpassPoints;
    return _overpassPoints.where((p) => p.type == _selectedFilter).toList();
  }

  String _getFilterTitle(AppLocalizations l10n) {
    switch (_selectedFilter) {
      case 'aed':
        return l10n.t('dae');
      case 'hospital':
        return l10n.t('hospitals');
      default:
        return l10n.t('nearby_facilities');
    }
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    final textSecondary = ThemeHelper.textSecondary(context);
    final mapCenter = _userLocation ?? _defaultLocation;

    final bool isSettingsDisabled = _locationError == 'settings_disabled';
    final bool showGpsBanner = _locationError.isNotEmpty && !_isLoadingLocation;
    final bool showCardioBanner = !_isLoadingCardio && _cardiologist != null;
    final double mapHeight = showGpsBanner && showCardioBanner ? 195 : 240;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: ThemeHelper.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.showBackButton
            ? Container(
                margin: const EdgeInsetsDirectional.only(start: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context)),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.t('emergency_map'),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 2),
            Text(
              _isLoadingLocation
                  ? l10n.t('locating')
                  : isSettingsDisabled
                      ? '⚠ ' + l10n.t('location_not_available')
                      : _locationError.isNotEmpty
                          ? ' $_locationError'
                          : ' ${_filteredPoints.length} ' + l10n.t('nearby_facilities'),
              style:
                  TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.white),
                onPressed: () async {
                  await _getCurrentLocation();
                  if (_userLocation != null && !isSettingsDisabled) {
                    _mapController.move(_userLocation!, 14.0);
                  }
                }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (isSettingsDisabled)
            _LocationDisabledBanner(
              onGoToSettings: () {
                Navigator.pushNamed(context, '/settings');
              },
            )
          else if (showGpsBanner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              color: Colors.orange.withOpacity(0.15),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$_locationError — ${l10n.t('approximate_position')}',
                    style: const TextStyle(fontSize: 11, color: Colors.orange),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: _getCurrentLocation,
                  child: Text(l10n.t('retry'),
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ),

          if (showCardioBanner)
            _CardiologistBanner(
              cardiologist: _cardiologist,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
              surface: surface,
              border: border,
              onCenterOnMap: () {
                if (_cardiologist?.lat != null && _cardiologist?.lng != null) {
                  _mapController.move(
                      LatLng(_cardiologist!.lat!, _cardiologist!.lng!), 15.0);
                }
              },
            ),

          // ── Filtres
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              children: [
                _FilterChip(
                    label: l10n.t('all'),
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                    color: Colors.blue),
                const SizedBox(width: 8),
                _FilterChip(
                    label: l10n.t('dae'),
                    selected: _selectedFilter == 'aed',
                    onTap: () => setState(() => _selectedFilter = 'aed'),
                    color: Colors.green),
                const SizedBox(width: 8),
                _FilterChip(
                    label: l10n.t('hospitals'),
                    selected: _selectedFilter == 'hospital',
                    onTap: () => setState(() => _selectedFilter = 'hospital'),
                    color: Colors.red),
              ],
            ),
          ),

          // ── Carte
          SizedBox(
            height: mapHeight,
            child: _isLoadingLocation
                ? Container(
                    color: surface,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 10),
                          Text(l10n.t('loading'),
                              style: TextStyle(color: textSecondary)),
                        ],
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: 14.0,
                      interactionOptions:
                          const InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.caredify.app'),
                      MarkerLayer(markers: [
                        // Vous
                        Marker(
                            point: mapCenter,
                            width: 50,
                            height: 50,
                            child: _UserMarker(
                                hasError: _locationError.isNotEmpty)),
                        // Cardiologue référent
                        if (_cardiologist?.lat != null &&
                            _cardiologist?.lng != null)
                          Marker(
                              point: LatLng(
                                  _cardiologist!.lat!, _cardiologist!.lng!),
                              width: 56,
                              height: 56,
                              child: _CardiologistMarker(
                                  isOnline: _cardiologist!.isSharing,
                                  initials: _cardiologist!.fullName
                                      .split(' ')
                                      .map((w) => w.isNotEmpty ? w[0] : '')
                                      .take(2)
                                      .join()
                                      .toUpperCase())),
                        // POIs
                        ..._filteredPoints.map((p) => Marker(
                            point: LatLng(p.lat, p.lng),
                            width: 34,
                            height: 34,
                            child: _MarkerIcon(type: p.type))),
                      ]),
                    ],
                  ),
          ),

          // ── Légende
          SizedBox(
            height: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                _LegendItem(
                    color: isSettingsDisabled
                        ? Colors.grey
                        : _locationError.isNotEmpty
                            ? Colors.orange
                            : Colors.blue,
                    label: l10n.t('you')),
                const SizedBox(width: 10),
                if (_cardiologist != null) ...[
                  _LegendItem(
                      color: _cardiologist!.isSharing
                          ? const Color(0xFF0EA5E9)
                          : Colors.grey,
                      label: l10n.t('dr')),
                  const SizedBox(width: 10),
                ],
                _LegendItem(color: Colors.green, label: l10n.t('dae')),
                const SizedBox(width: 10),
                _LegendItem(color: Colors.red, label: l10n.t('hospitals')),
              ]),
            ),
          ),

          const Divider(height: 1),

          // ── En-tête liste
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  '${_getFilterTitle(l10n)} — ${_filteredPoints.length} ' + l10n.t('no_results'),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_isLoadingPoi)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (_overpassPoints.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.3))),
                  child: const Text('OSM',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green)),
                ),
            ]),
          ),

          // ── Liste POIs
          Expanded(
            child: _isLoadingPoi && _overpassPoints.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.t('loading_facilities'),
                            style:
                                TextStyle(fontSize: 13, color: textSecondary)),
                      ],
                    ),
                  )
                : _filteredPoints.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off,
                                size: 40, color: textSecondary),
                            const SizedBox(height: 8),
                            Text(
                              _overpassPoints.isEmpty && !_isLoadingPoi
                                  ? l10n.t('no_results')
                                  : l10n.t('no_results'),
                              style:
                                  TextStyle(fontSize: 14, color: textSecondary),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            if (!_isLoadingPoi)
                              OutlinedButton.icon(
                                onPressed: () {
                                  _poiFetchInProgress = false;
                                  _lastFetchedKey = null;
                                  final loc = _userLocation ?? _defaultLocation;
                                  _triggerPoiFetch(loc.latitude, loc.longitude);
                                },
                                icon: const Icon(Icons.refresh, size: 16),
                                label: Text(l10n.t('retry'),
                                    style: const TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        itemCount: _filteredPoints.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _PointCard(
                          point: _filteredPoints[index],
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          border: border,
                          onTap: () {
                            _mapController.move(
                                LatLng(_filteredPoints[index].lat,
                                    _filteredPoints[index].lng),
                                16.0);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: !_isLoadingLocation
          ? FloatingActionButton.small(
              backgroundColor:
                  isSettingsDisabled ? Colors.grey : ThemeHelper.primary,
              onPressed: () async {
                if (isSettingsDisabled) {
                  Navigator.pushNamed(context, '/settings');
                  return;
                }
                await _getCurrentLocation();
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 14.0);
                }
              },
              child: Icon(
                isSettingsDisabled ? Icons.settings : Icons.my_location,
                color: Colors.white,
                size: 20,
              ),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────
// Bannière "Localisation désactivée dans Paramètres"
// ─────────────────────────────────────────────
class _LocationDisabledBanner extends StatelessWidget {
  final VoidCallback onGoToSettings;
  const _LocationDisabledBanner({required this.onGoToSettings});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: Colors.red.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded, size: 18, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.t('location_settings_disabled_banner'),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onGoToSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                l10n.t('settings_title'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _CardiologistBanner
// ─────────────────────────────────────────────
class _CardiologistBanner extends StatelessWidget {
  final _CardiologistInfo? cardiologist;
  final Color textPrimary, textSecondary, surface, border;
  final VoidCallback? onCenterOnMap;

  const _CardiologistBanner({
    required this.cardiologist,
    required this.textPrimary,
    required this.textSecondary,
    required this.surface,
    required this.border,
    this.onCenterOnMap,
  });

  @override
  Widget build(BuildContext context) {
    if (cardiologist == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    final bool online = cardiologist!.isSharing &&
        cardiologist!.lat != null &&
        cardiologist!.lng != null;
    final Color statusColor = online ? const Color(0xFF10B981) : Colors.grey;
    final String statusLabel =
        online ? '${l10n.t('online_status')} • ${l10n.t('direct_ecg')}' : l10n.t('offline');

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(12, 5, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: online ? const Color(0xFF0EA5E9).withOpacity(0.4) : border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: online
                    ? [const Color(0xFF0EA5E9), const Color(0xFF0284C7)]
                    : [Colors.grey.shade400, Colors.grey.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                cardiologist!.fullName
                    .split(' ')
                    .map((w) => w.isNotEmpty ? w[0] : '')
                    .take(2)
                    .join()
                    .toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Dr. ${cardiologist!.fullName}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textPrimary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(statusLabel,
                          style: TextStyle(fontSize: 10, color: statusColor),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (online)
            GestureDetector(
              onTap: onCenterOnMap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                ),
                child: Text(l10n.t('see'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0EA5E9))),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _UserMarker
// ─────────────────────────────────────────────
class _UserMarker extends StatelessWidget {
  final bool hasError;
  const _UserMarker({required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: (hasError ? Colors.orange : Colors.blue).withOpacity(0.2),
          shape: BoxShape.circle,
        ),
      ),
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: hasError ? Colors.orange : Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: (hasError ? Colors.orange : Colors.blue).withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            )
          ],
        ),
        child: Icon(
          hasError ? Icons.location_on : Icons.my_location,
          color: Colors.white,
          size: 14,
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// _CardiologistMarker
// ─────────────────────────────────────────────
class _CardiologistMarker extends StatelessWidget {
  final bool isOnline;
  final String initials;
  const _CardiologistMarker({required this.isOnline, required this.initials});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF0EA5E9) : Colors.grey;
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
            color: color.withOpacity(0.15), shape: BoxShape.circle),
      ),
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOnline
                ? [const Color(0xFF0EA5E9), const Color(0xFF0284C7)]
                : [Colors.grey.shade400, Colors.grey.shade600],
          ),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)
          ],
        ),
        child: Center(
          child: Text(initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12)),
        ),
      ),
      Positioned(
        right: 6,
        bottom: 6,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF10B981) : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────
// _MarkerIcon
// ─────────────────────────────────────────────
class _MarkerIcon extends StatelessWidget {
  final String type;
  const _MarkerIcon({required this.type});

  Color get _color {
    switch (type) {
      case 'aed':
        return Colors.green;
      case 'hospital':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'aed':
        return Icons.bolt;
      case 'hospital':
        return Icons.local_hospital;
      default:
        return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2)),
        child: Icon(_icon, color: Colors.white, size: 16));
  }
}

// ─────────────────────────────────────────────
// _PointCard
// ─────────────────────────────────────────────
class _PointCard extends StatelessWidget {
  final _MapPoint point;
  final Color textPrimary, textSecondary, border;
  final VoidCallback? onTap;
  const _PointCard({
    required this.point,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    this.onTap,
  });

  Color get _color {
    switch (point.type) {
      case 'aed':
        return Colors.green;
      case 'hospital':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (point.type) {
      case 'aed':
        return Icons.bolt;
      case 'hospital':
        return Icons.local_hospital;
      default:
        return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final surface = ThemeHelper.surface(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border)),
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: _color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(_icon, color: _color, size: 20)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                Text(point.name,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (point.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(point.address,
                      style: TextStyle(fontSize: 11, color: textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ])),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(point.distance,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _color)),
              const SizedBox(height: 2),
              Icon(Icons.arrow_forward_rounded, size: 12, color: _color),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _FilterChip
// ─────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final surface = ThemeHelper.surface(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
            color: selected ? color : surface,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : textPrimary)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// _LegendItem
// ─────────────────────────────────────────────
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final textSecondary = ThemeHelper.textSecondary(context);
    return Row(children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: textSecondary))
    ]);
  }
}
