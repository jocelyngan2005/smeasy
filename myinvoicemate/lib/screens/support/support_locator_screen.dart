import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../backend/support/models/support_location_model.dart';
import '../../backend/support/services/support_service.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportLocatorScreen extends StatefulWidget {
  const SupportLocatorScreen({super.key});

  @override
  State<SupportLocatorScreen> createState() => _SupportLocatorScreenState();
}

class _SupportLocatorScreenState extends State<SupportLocatorScreen> {
  final _supportService = SupportService();
  GoogleMapController? _mapController;
  List<SupportLocation> _locations = [];
  SupportLocation? _selectedLocation;
  bool _isLoading = true;
  LatLng _currentPosition = const LatLng(3.1390, 101.6869); // KL default
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(_currentPosition),
      );
    } catch (e) {
      // Use default KL location if geolocation fails
    }
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await _supportService.getNearbyLocations(
        _currentPosition.latitude,
        _currentPosition.longitude,
      );
      
      setState(() {
        _locations = locations;
        _isLoading = false;
        _updateMarkers();
      });
    } catch (e) {
      setState(() => _isLoading = false);
      Helpers.showErrorSnackbar(context, 'Failed to load locations');
    }
  }

  void _updateMarkers() {
    _markers.clear();
    
    for (var location in _locations) {
      _markers.add(
        Marker(
          markerId: MarkerId(location.id),
          position: LatLng(location.latitude, location.longitude),
          infoWindow: InfoWindow(
            title: location.name,
            snippet: location.type,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerColor(location.type),
          ),
          onTap: () {
            setState(() => _selectedLocation = location);
          },
        ),
      );
    }
  }

  double _getMarkerColor(String type) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Locator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentPosition,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // Loading Indicator
          if (_isLoading)
            Container(
              color: Colors.white70,
              child: const Center(child: CircularProgressIndicator()),
            ),

          // Location Details Card
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildLocationCard(_selectedLocation!),
            ),

          // Filter Buttons
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: _buildFilterChips(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildFilterChip('All', null),
            const SizedBox(width: 8),
            _buildFilterChip('LHDN', 'lhdn_office'),
            const SizedBox(width: 8),
            _buildFilterChip('SME Centers', 'sme_center'),
            const SizedBox(width: 8),
            _buildFilterChip('Tax Support', 'tax_support'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? type) {
    return Expanded(
      child: FilterChip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
        selected: false,
        onSelected: (selected) async {
          if (type == null) {
            _loadLocations();
          } else {
            setState(() => _isLoading = true);
            final filtered = await _supportService.getLocationsByType(type);
            setState(() {
              _locations = filtered;
              _isLoading = false;
              _updateMarkers();
            });
          }
        },
      ),
    );
  }

  Widget _buildLocationCard(SupportLocation location) {
    return Card(
      margin: EdgeInsets.zero,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() => _selectedLocation = null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getLocationTypeLabel(location.type),
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const Divider(height: 24),
            
            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(location.address)),
              ],
            ),
            const SizedBox(height: 12),
            
            // Phone
            Row(
              children: [
                const Icon(Icons.phone, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(location.phone)),
              ],
            ),
            
            if (location.openingHours != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(location.openingHours!)),
                ],
              ),
            ],

            const SizedBox(height: 16),
            
            // Services
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: location.services.map((service) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    service,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _makePhoneCall(location.phone),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openInMaps(location),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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

  Future<void> _makePhoneCall(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      Helpers.showErrorSnackbar(context, 'Cannot make phone call');
    }
  }

  Future<void> _openInMaps(SupportLocation location) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      Helpers.showErrorSnackbar(context, 'Cannot open maps');
    }
  }
}
