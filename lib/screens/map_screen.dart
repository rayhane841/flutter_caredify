import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../utils/theme_helper.dart';

class MapScreen extends StatelessWidget {
  final bool showBackButton;
  const MapScreen({super.key, this.showBackButton = false});

  @override
  Widget build(BuildContext context) {
    return _MapScreenContent(showBackButton: showBackButton);
  }
}

class _MapScreenContent extends StatefulWidget {
  final bool showBackButton;
  const _MapScreenContent({required this.showBackButton});
  @override
  State<_MapScreenContent> createState() => _MapScreenContentState();
}

class _MapScreenContentState extends State<_MapScreenContent> {
  final MapController _mapController = MapController();
  String _selectedFilter = 'all';

  // ✅ Localisation réelle — null jusqu'à ce qu'elle soit obtenue
  LatLng? _userLocation;
  bool _isLoadingLocation = true;
  String _locationError = '';

  // Position par défaut (Tunis centre) si GPS indisponible
  final LatLng _defaultLocation = const LatLng(36.8065, 10.1815);

  final List<_MapPoint> _points = [
    const _MapPoint(
        id: '1',
        type: 'aed',
        name: 'DAE Avenue Habib Bourguiba',
        address: 'Avenue Habib Bourguiba, 1000 Tunis',
        distance: '120 m',
        lat: 36.8075,
        lng: 10.1825),
    const _MapPoint(
        id: '2',
        type: 'aed',
        name: 'DAE Métro Tunis Marine',
        address: 'Station Métro Marine, 1000 Tunis',
        distance: '350 m',
        lat: 36.8045,
        lng: 10.1795),
    const _MapPoint(
        id: '3',
        type: 'aed',
        name: 'DAE Tunisia Mall',
        address: 'Les Berges du Lac, 1053 Tunis',
        distance: '2.1 km',
        lat: 36.8385,
        lng: 10.2425),
    const _MapPoint(
        id: '4',
        type: 'hospital',
        name: 'Hôpital Charles Nicolle',
        address: 'Boulevard du 9 Avril 1938, 1006 Tunis',
        distance: '1.8 km',
        lat: 36.8125,
        lng: 10.1695),
    const _MapPoint(
        id: '5',
        type: 'hospital',
        name: 'Hôpital La Rabta',
        address: 'Rue Jebel Lakhdar, 1007 Tunis',
        distance: '2.4 km',
        lat: 36.8185,
        lng: 10.1625),
    const _MapPoint(
        id: '6',
        type: 'hospital',
        name: 'Hôpital Mongi Slim',
        address: 'La Marsa, 2046 Tunis',
        distance: '8.5 km',
        lat: 36.8785,
        lng: 10.3245),
    const _MapPoint(
        id: '7',
        type: 'hospital',
        name: 'Clinique El Manar',
        address: 'Rue du Lac Windermere, 1053 Tunis',
        distance: '3.2 km',
        lat: 36.8425,
        lng: 10.2185),
    const _MapPoint(
        id: '8',
        type: 'cardiologist',
        name: 'Dr. Ahmed Ben Ali — Cardiologue',
        address: 'Avenue Mohamed V, 1002 Tunis',
        distance: '450 m',
        lat: 36.8095,
        lng: 10.1855),
    const _MapPoint(
        id: '9',
        type: 'cardiologist',
        name: 'Dr. Fatma Gharbi — Cardiologue',
        address: 'Rue de Marseille, 1000 Tunis',
        distance: '680 m',
        lat: 36.8115,
        lng: 10.1775),
    const _MapPoint(
        id: '10',
        type: 'cardiologist',
        name: 'Dr. Mohamed Trabelsi — Cardiologue',
        address: 'Centre Urbain Nord, 1003 Tunis',
        distance: '4.1 km',
        lat: 36.8525,
        lng: 10.1925),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // ✅ Obtenir la vraie localisation GPS
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = '';
    });

    try {
      // 1. Vérifier si le service GPS est activé
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'GPS désactivé';
          _userLocation = _defaultLocation;
        });
        return;
      }

      // 2. Vérifier les permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _locationError = 'Permission refusée';
            _userLocation = _defaultLocation;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _locationError = 'Permission refusée définitivement';
          _userLocation = _defaultLocation;
        });
        return;
      }

      // 3. ✅ Obtenir la position réelle
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

      // 4. ✅ Centrer la carte sur la vraie position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(realLocation, 15.0);
        } catch (_) {}
      });
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationError = 'Erreur GPS';
        _userLocation = _defaultLocation;
      });
    }
  }

  List<_MapPoint> get _filteredPoints => _selectedFilter == 'all'
      ? _points
      : _points.where((p) => p.type == _selectedFilter).toList();

  String get _filterTitle {
    switch (_selectedFilter) {
      case 'aed':
        return 'DAE';
      case 'hospital':
        return 'HÔPITAUX';
      case 'cardiologist':
        return 'CARDIOLOGUES';
      default:
        return 'TOUS LES ÉTABLISSEMENTS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = ThemeHelper.background(context);
    final surface = ThemeHelper.surface(context);
    final border = ThemeHelper.border(context);
    final textPrimary = ThemeHelper.textPrimary(context);
    final textSecondary = ThemeHelper.textSecondary(context);

    // ✅ Position utilisée pour la carte
    final mapCenter = _userLocation ?? _defaultLocation;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: ThemeHelper.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: widget.showBackButton
            ? Container(
                margin: const EdgeInsets.only(left: 8),
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
            const Text('Carte des urgences',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 2),
            // ✅ Afficher le statut GPS dans le subtitle
            Text(
              _isLoadingLocation
                  ? 'Localisation en cours...'
                  : _locationError.isNotEmpty
                      ? '⚠️ $_locationError — position approximative'
                      : '📍 ${_filteredPoints.length} établissements à proximité',
              style:
                  TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
            ),
          ],
        ),
        actions: [
          // ✅ Bouton recentrer sur ma position
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
            child: IconButton(
                icon: const Icon(Icons.my_location, color: Colors.white),
                onPressed: () async {
                  await _getCurrentLocation();
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 15.0);
                  }
                }),
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Bannière d'erreur GPS si nécessaire
          if (_locationError.isNotEmpty && !_isLoadingLocation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.orange.withOpacity(0.15),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_locationError — Affichage de la position par défaut (Tunis)',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  ),
                ),
                GestureDetector(
                  onTap: _getCurrentLocation,
                  child: const Text('Réessayer',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline)),
                ),
              ]),
            ),

          // Filtres
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(
                    label: 'Tout',
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                    color: Colors.blue),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'DAE',
                    selected: _selectedFilter == 'aed',
                    onTap: () => setState(() => _selectedFilter = 'aed'),
                    color: Colors.green),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Hôpitaux',
                    selected: _selectedFilter == 'hospital',
                    onTap: () => setState(() => _selectedFilter = 'hospital'),
                    color: Colors.red),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Cardiologues',
                    selected: _selectedFilter == 'cardiologist',
                    onTap: () =>
                        setState(() => _selectedFilter = 'cardiologist'),
                    color: Colors.purple),
              ]),
            ),
          ),

          // ✅ Carte avec vraie position
          SizedBox(
            height: 250,
            child: _isLoadingLocation
                ? Container(
                    color: surface,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text('Localisation en cours...',
                              style: TextStyle(color: textSecondary)),
                        ],
                      ),
                    ),
                  )
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      // ✅ Centré sur la vraie position
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
                        // ✅ Marqueur position réelle de l'utilisateur
                        Marker(
                            point: mapCenter,
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Cercle pulsant
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                // Marqueur central
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: _locationError.isNotEmpty
                                        ? Colors.orange
                                        : Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.4),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: Icon(
                                    _locationError.isNotEmpty
                                        ? Icons.location_on
                                        : Icons.my_location,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            )),

                        // Marqueurs des établissements
                        ..._filteredPoints.map((p) => Marker(
                            point: LatLng(p.lat, p.lng),
                            width: 36,
                            height: 36,
                            child: _MarkerIcon(type: p.type))),
                      ]),
                    ],
                  ),
          ),

          // Légende
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _LegendItem(
                  color:
                      _locationError.isNotEmpty ? Colors.orange : Colors.blue,
                  label: _locationError.isNotEmpty ? 'Défaut' : 'Vous'),
              const SizedBox(width: 12),
              const _LegendItem(color: Colors.green, label: 'DAE'),
              const SizedBox(width: 12),
              const _LegendItem(color: Colors.red, label: 'Hôpital'),
              const SizedBox(width: 12),
              const _LegendItem(color: Colors.purple, label: 'Cardio'),
            ]),
          ),

          const Divider(height: 1),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                        '$_filterTitle - ${_filteredPoints.length} RÉSULTATS',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textSecondary))),
                Expanded(
                  child: _filteredPoints.isEmpty
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                              Icon(Icons.search_off,
                                  size: 48, color: textSecondary),
                              const SizedBox(height: 12),
                              Text('Aucun résultat',
                                  style: TextStyle(
                                      fontSize: 16, color: textSecondary))
                            ]))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPoints.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) => _PointCard(
                              point: _filteredPoints[index],
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              border: border),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ✅ Bouton flottant — recentrer sur ma position
      floatingActionButton: !_isLoadingLocation
          ? FloatingActionButton.small(
              backgroundColor: ThemeHelper.primary,
              onPressed: () async {
                await _getCurrentLocation();
                if (_userLocation != null) {
                  _mapController.move(_userLocation!, 15.0);
                }
              },
              child:
                  const Icon(Icons.my_location, color: Colors.white, size: 20),
            )
          : null,
    );
  }
}

// ==================== _FilterChip ====================
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
            color: selected ? color : surface,
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : textPrimary)),
      ),
    );
  }
}

// ==================== _LegendItem ====================
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final textSecondary = ThemeHelper.textSecondary(context);
    return Row(children: [
      Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 12, color: textSecondary))
    ]);
  }
}

// ==================== _MarkerIcon ====================
class _MarkerIcon extends StatelessWidget {
  final String type;
  const _MarkerIcon({required this.type});

  Color get _color {
    switch (type) {
      case 'aed':
        return Colors.green;
      case 'hospital':
        return Colors.red;
      case 'cardiologist':
        return Colors.purple;
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
      case 'cardiologist':
        return Icons.medical_services;
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
        child: Icon(_icon, color: Colors.white, size: 18));
  }
}

// ==================== _PointCard ====================
class _PointCard extends StatelessWidget {
  final _MapPoint point;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  const _PointCard(
      {required this.point,
      required this.textPrimary,
      required this.textSecondary,
      required this.border});

  Color get _color {
    switch (point.type) {
      case 'aed':
        return Colors.green;
      case 'hospital':
        return Colors.red;
      case 'cardiologist':
        return Colors.purple;
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
      case 'cardiologist':
        return Icons.medical_services;
      default:
        return Icons.location_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = ThemeHelper.surface(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border)),
      child: Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(_icon, color: _color, size: 24)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(point.name,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(point.address,
              style: TextStyle(fontSize: 13, color: textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ])),
        Column(children: [
          Text(point.distance,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold, color: _color)),
          const SizedBox(height: 4),
          Icon(Icons.arrow_forward_ios, size: 14, color: _color),
        ]),
      ]),
    );
  }
}

// ==================== _MapPoint ====================
class _MapPoint {
  final String id, type, name, address, distance;
  final double lat, lng;
  const _MapPoint(
      {required this.id,
      required this.type,
      required this.name,
      required this.address,
      required this.distance,
      required this.lat,
      required this.lng});
}
