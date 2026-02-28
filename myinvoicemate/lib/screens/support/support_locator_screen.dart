import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../backend/support/models/support_location_model.dart';
import '../../backend/support/services/support_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';

class SupportLocatorScreen extends StatefulWidget {
  const SupportLocatorScreen({super.key});

  @override
  State<SupportLocatorScreen> createState() => _SupportLocatorScreenState();
}

class _SupportLocatorScreenState extends State<SupportLocatorScreen> {
  final _supportService = SupportService();
  GoogleMapController? _mapController;

  List<SupportLocation> _allLocations = [];
  List<SupportLocation> _filteredLocations = [];
  SupportLocation? _selectedLocation;

  bool _isLoading = true;
  bool _showList = false;

  // KL as default until GPS kicks in
  LatLng _currentPosition = const LatLng(3.1390, 101.6869);

  String? _activeFilter; // null = All

  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _getCurrentLocation();
    await _loadLocations();
  }

  // -- Location permission & GPS -------------------------------------------

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    } catch (_) {
      // Keep KL default
    }
  }

  // -- Data loading --------------------------------------------------------

  Future<void> _loadLocations({String? type}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final locations = type == null
          ? await _supportService.getAllLocations()
          : await _supportService.getLocationsByType(type);

      if (!mounted) return;
      setState(() {
        _allLocations = locations;
        _filteredLocations = locations;
        _isLoading = false;
        _updateMarkers();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Helpers.showErrorSnackbar(context, 'Failed to load locations');
    }
  }

  void _applyFilter(String? type) {
    setState(() {
      _activeFilter = type;
      _selectedLocation = null;
    });
    _loadLocations(type: type);
  }

  // -- Markers ----------------------------------------------------------------

  void _updateMarkers() {
    _markers.clear();
    for (final location in _filteredLocations) {
      _markers.add(
        Marker(
          markerId: MarkerId(location.id),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: location.name,
            snippet: _getLocationTypeLabel(location.type),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerHue(location.type),
          ),
          onTap: () {
            setState(() {
              _selectedLocation = location;
              _showList = false;
            });
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(location.latitude, location.longitude),
                14,
              ),
            );
          },
        ),
      );
    }
  }

  double _getMarkerHue(String type) {
    switch (type) {
      case 'lhdn_office':
        return BitmapDescriptor.hueBlue;
      case 'sme_center':
        return BitmapDescriptor.hueGreen;
      case 'tax_support':
        return BitmapDescriptor.hueOrange;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  // -- Helpers ---------------------------------------------------------------

  String _getLocationTypeLabel(String type) {
    switch (type) {
      case 'lhdn_office':
        return 'LHDN Office';
      case 'sme_center':
        return 'SME Digital Centre';
      case 'tax_support':
        return 'Tax Support Centre';
      default:
        return type;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'lhdn_office':
        return Colors.blue;
      case 'sme_center':
        return Colors.green;
      case 'tax_support':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _distanceLabel(SupportLocation loc) {
    final d = _haversineKm(
      _currentPosition.latitude,
      _currentPosition.longitude,
      loc.latitude,
      loc.longitude,
    );
    return d < 1
        ? '${(d * 1000).round()} m away'
        : '${d.toStringAsFixed(1)} km away';
  }

  static double _haversineKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.pow(math.sin(dLon / 2), 2) *
            math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180);
    return 2 * r * math.asin(math.sqrt(a));
  }

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      Helpers.showErrorSnackbar(context, 'Cannot make phone call');
    }
  }

  Future<void> _openInGoogleMaps(SupportLocation location) async {
    final dirUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=${Uri.encodeComponent(location.name + ' ' + location.address)}'
      '&travelmode=driving',
    );
    final fallback = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${location.latitude},${location.longitude}',
    );
    if (await canLaunchUrl(dirUri)) {
      await launchUrl(dirUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      Helpers.showErrorSnackbar(context, 'Cannot open Google Maps');
    }
  }

  void _zoomToLocation(SupportLocation loc) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(loc.latitude, loc.longitude),
        14,
      ),
    );
    setState(() {
      _selectedLocation = loc;
      _showList = false;
    });
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LHDN Centres Near You',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            Text(
              '${_filteredLocations.length} location${_filteredLocations.length == 1 ? '' : 's'} found',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showList ? 'Show Map' : 'Show List',
            icon: Icon(
              _showList ? Icons.map_outlined : Icons.list,
              color: AppColors.primary,
            ),
            onPressed: () => setState(() => _showList = !_showList),
          ),
          IconButton(
            tooltip: 'My Location',
            icon: const Icon(Icons.my_location, color: AppColors.primary),
            onPressed: () async {
              await _getCurrentLocation();
              await _loadLocations(type: _activeFilter);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterRow(),
          Expanded(
            child: Stack(
              children: [
                _showList ? _buildListView() : _buildMapView(),
                if (_isLoading)
                  Container(
                    color: Colors.white70,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Filter row ------------------------------------------------------------

  Widget _buildFilterRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('All', null, Icons.location_on),
            const SizedBox(width: 8),
            _filterChip('LHDN', 'lhdn_office', Icons.account_balance),
            const SizedBox(width: 8),
            _filterChip('SME Centres', 'sme_center', Icons.business),
            const SizedBox(width: 8),
            _filterChip('Tax Support', 'tax_support', Icons.receipt_long),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String? type, IconData icon) {
    final selected = _activeFilter == type;
    return FilterChip(
      avatar: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : AppColors.primary,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) => _applyFilter(type),
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.grey.shade300,
        ),
      ),
    );
  }

  // -- Map view --------------------------------------------------------------

  Widget _buildMapView() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _currentPosition,
            zoom: 11,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          onMapCreated: (controller) => _mapController = controller,
          onTap: (_) => setState(() => _selectedLocation = null),
        ),
        if (_selectedLocation != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildLocationCard(_selectedLocation!),
          ),
        if (!_isLoading && _filteredLocations.isEmpty)
          Center(
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No centres found nearby',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => _loadLocations(),
                      child: const Text('Reload'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // -- List view -------------------------------------------------------------

  Widget _buildListView() {
    if (_filteredLocations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No centres found',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filteredLocations.length,
      itemBuilder: (context, index) {
        final loc = _filteredLocations[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _zoomToLocation(loc),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _typeColor(loc.type).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      loc.type == 'lhdn_office'
                          ? Icons.account_balance
                          : loc.type == 'sme_center'
                              ? Icons.business
                              : Icons.receipt_long,
                      color: _typeColor(loc.type),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getLocationTypeLabel(loc.type),
                          style: TextStyle(
                            fontSize: 12,
                            color: _typeColor(loc.type),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.address,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.near_me,
                                size: 13, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              _distanceLabel(loc),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            _iconAction(Icons.phone, Colors.green,
                                () => _makePhoneCall(loc.phone)),
                            const SizedBox(width: 6),
                            _iconAction(Icons.directions, AppColors.primary,
                                () => _openInGoogleMaps(loc)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _iconAction(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // -- Location detail card --------------------------------------------------

  Widget _buildLocationCard(SupportLocation location) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _typeColor(location.type).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    location.type == 'lhdn_office'
                        ? Icons.account_balance
                        : location.type == 'sme_center'
                            ? Icons.business
                            : Icons.receipt_long,
                    color: _typeColor(location.type),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _getLocationTypeLabel(location.type),
                        style: TextStyle(
                          color: _typeColor(location.type),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _selectedLocation = null),
                ),
              ],
            ),
            const Divider(height: 18),
            // Distance badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    _distanceLabel(location),
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.location_on_outlined, location.address),
            const SizedBox(height: 6),
            _infoRow(Icons.phone_outlined, location.phone),
            if (location.openingHours != null) ...[
              const SizedBox(height: 6),
              _infoRow(Icons.access_time, location.openingHours!),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: location.services.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    s,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(location.phone),
                    icon: const Icon(Icons.phone, size: 18),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openInGoogleMaps(location),
                    icon: const Icon(Icons.directions, size: 18),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}
