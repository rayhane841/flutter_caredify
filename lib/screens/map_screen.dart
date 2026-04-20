import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

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

  // ✅ Position patient (Tunis centre - Avenue Habib Bourguiba)
  final LatLng _patientLocation = const LatLng(36.8065, 10.1815);

  // ✅ Liste des points d'intérêt en Tunisie 🇹🇳
  final List<_MapPoint> _points = [
    // 🚑 DAE (Défibrillateurs) en Tunisie
    _MapPoint(
      id: '1',
      type: 'aed',
      name: 'DAE Avenue Habib Bourguiba',
      address: 'Avenue Habib Bourguiba, 1000 Tunis',
      distance: '120 m',
      lat: 36.8075,
      lng: 10.1825,
    ),
    _MapPoint(
      id: '2',
      type: 'aed',
      name: 'DAE Métro Tunis Marine',
      address: 'Station Métro Marine, 1000 Tunis',
      distance: '350 m',
      lat: 36.8045,
      lng: 10.1795,
    ),
    _MapPoint(
      id: '3',
      type: 'aed',
      name: 'DAE Tunisia Mall',
      address: 'Les Berges du Lac, 1053 Tunis',
      distance: '2.1 km',
      lat: 36.8385,
      lng: 10.2425,
    ),

    // 🏥 Hôpitaux en Tunisie
    _MapPoint(
      id: '4',
      type: 'hospital',
      name: 'Hôpital Charles Nicolle',
      address: 'Boulevard du 9 Avril 1938, 1006 Tunis',
      distance: '1.8 km',
      lat: 36.8125,
      lng: 10.1695,
    ),
    _MapPoint(
      id: '5',
      type: 'hospital',
      name: 'Hôpital La Rabta',
      address: 'Rue Jebel Lakhdar, 1007 Tunis',
      distance: '2.4 km',
      lat: 36.8185,
      lng: 10.1625,
    ),
    _MapPoint(
      id: '6',
      type: 'hospital',
      name: 'Hôpital Mongi Slim',
      address: 'La Marsa, 2046 Tunis',
      distance: '8.5 km',
      lat: 36.8785,
      lng: 10.3245,
    ),
    _MapPoint(
      id: '7',
      type: 'hospital',
      name: 'Clinique El Manar',
      address: 'Rue du Lac Windermere, 1053 Tunis',
      distance: '3.2 km',
      lat: 36.8425,
      lng: 10.2185,
    ),

    // 👨‍⚕️ Cardiologues en Tunisie
    _MapPoint(
      id: '8',
      type: 'cardiologist',
      name: 'Dr. Ahmed Ben Ali — Cardiologue',
      address: 'Avenue Mohamed V, 1002 Tunis',
      distance: '450 m',
      lat: 36.8095,
      lng: 10.1855,
    ),
    _MapPoint(
      id: '9',
      type: 'cardiologist',
      name: 'Dr. Fatma Gharbi — Cardiologue',
      address: 'Rue de Marseille, 1000 Tunis',
      distance: '680 m',
      lat: 36.8115,
      lng: 10.1775,
    ),
    _MapPoint(
      id: '10',
      type: 'cardiologist',
      name: 'Dr. Mohamed Trabelsi — Cardiologue',
      address: 'Centre Urbain Nord, 1003 Tunis',
      distance: '4.1 km',
      lat: 36.8525,
      lng: 10.1925,
    ),
  ];

  // ✅ Filtrage des points
  List<_MapPoint> get _filteredPoints {
    if (_selectedFilter == 'all') return _points;
    return _points.where((p) => p.type == _selectedFilter).toList();
  }

  // ✅ Titre selon le filtre
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        // ✅ Bouton retour conditionnel
        leading: widget.showBackButton
            ? Container(
                margin: const EdgeInsets.only(left: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Retour au Dashboard',
                ),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Carte des urgences',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${_filteredPoints.length} établissements à proximité',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white),
              onPressed: () {},
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ Filtres (chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Tout',
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'DAE',
                    selected: _selectedFilter == 'aed',
                    onTap: () => setState(() => _selectedFilter = 'aed'),
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Hôpitaux',
                    selected: _selectedFilter == 'hospital',
                    onTap: () => setState(() => _selectedFilter = 'hospital'),
                    color: Colors.red,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Cardiologues',
                    selected: _selectedFilter == 'cardiologist',
                    onTap: () =>
                        setState(() => _selectedFilter = 'cardiologist'),
                    color: Colors.purple,
                  ),
                ],
              ),
            ),
          ),

          // ✅✅✅ CARTE INTERACTIVE - CENTRÉE SUR TUNIS 🇹🇳 ✅✅✅
          SizedBox(
            height: 250,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                // ✅ Bounds centrés sur Tunis, Tunisie
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds(
                    LatLng(36.7800, 10.1500), // Sud-Ouest (Tunis)
                    LatLng(36.8400, 10.2200), // Nord-Est (Tunis)
                  ),
                  padding: const EdgeInsets.all(20),
                ),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // ✅ Couche de tuiles OpenStreetMap
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.caredify.app',
                ),
                // ✅ Marqueurs
                MarkerLayer(
                  markers: [
                    // Position du patient (Tunis)
                    Marker(
                      point: _patientLocation,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    // Points d'intérêt tunisiens
                    ..._filteredPoints.map((p) => Marker(
                          point: LatLng(p.lat, p.lng),
                          width: 36,
                          height: 36,
                          child: _MarkerIcon(type: p.type),
                        )),
                  ],
                ),
              ],
            ),
          ),

          // ✅ Légende
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _LegendItem(color: Colors.blue, label: 'Vous'),
                const SizedBox(width: 12),
                _LegendItem(color: Colors.green, label: 'DAE'),
                const SizedBox(width: 12),
                _LegendItem(color: Colors.red, label: 'Hôpital'),
                const SizedBox(width: 12),
                _LegendItem(color: Colors.purple, label: 'Cardio'),
              ],
            ),
          ),

          const Divider(height: 1),

          // ✅ Liste des résultats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '$_filterTitle - ${_filteredPoints.length} RÉSULTATS',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredPoints.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text(
                                'Aucun résultat',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredPoints.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            return _PointCard(point: _filteredPoints[index]);
                          },
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

// ==================== _FilterChip ====================

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }
}

// ==================== _LegendItem ====================

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
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
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: _color.withOpacity(0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(_icon, color: Colors.white, size: 18),
    );
  }
}

// ==================== _PointCard ====================

class _PointCard extends StatelessWidget {
  final _MapPoint point;
  const _PointCard({required this.point});

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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  point.address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                point.distance,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _color,
                ),
              ),
              const SizedBox(height: 4),
              Icon(Icons.arrow_forward_ios, size: 14, color: _color),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== _MapPoint ====================

class _MapPoint {
  final String id;
  final String type;
  final String name;
  final String address;
  final String distance;
  final double lat;
  final double lng;

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
