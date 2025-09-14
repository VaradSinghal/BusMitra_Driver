// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:busmitra_driver/utils/constants.dart';
import 'package:busmitra_driver/services/location_service.dart';
import 'package:busmitra_driver/services/database_service.dart';
import 'package:busmitra_driver/services/directions_service.dart';
import 'package:busmitra_driver/models/route_model.dart';
import 'package:busmitra_driver/test_data/route_8b_test.dart';

class MapScreen extends StatefulWidget {
  final BusRoute? route;

  const MapScreen({super.key, this.route});

  // Constructor for when you want to pass a specific route
  const MapScreen.withRoute({super.key, required this.route})
      : assert(route != null);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  LatLng _currentLocation = const LatLng(28.6139, 77.2090); // Default: Delhi
  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  BusRoute? _currentRoute;
  bool _isLoading = true;
  bool _isLoadingDirections = false;
  bool _mapError = false;

  @override
  void initState() {
    super.initState();

    if (widget.route != null) {
      _currentRoute = widget.route;
      _isLoading = false;
    } else {
      _loadActiveRoute();
    }

    _getCurrentLocation();
    
    // Set a timeout to detect map loading issues
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        setState(() {
          _mapError = true;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Clean up any ongoing operations
    super.dispose();
  }

  Widget _buildMapErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.map_outlined,
              size: 80,
              color: AppConstants.primaryColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Map Unavailable',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppConstants.textColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Google Maps API key configuration issue.\nPlease check your API key settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppConstants.lightTextColor,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _mapError = false;
                  _isLoading = true;
                });
                _loadActiveRoute();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: AppConstants.accentColor,
              ),
            ),
            const SizedBox(height: 12),
            if (_currentRoute != null) ...[
              Text(
                'Current Route: ${_currentRoute!.name}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_currentRoute!.startPoint} → ${_currentRoute!.endPoint}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppConstants.lightTextColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadActiveRoute() async {
    try {
      final journey = await _databaseService.getActiveJourney();
      if (journey != null && journey['routeId'] != null) {
        final route = await _databaseService.getRouteById(journey['routeId']);
        if (mounted) {
          setState(() => _currentRoute = route);
        }
      } else {
        // Use test route if no active journey found
        debugPrint('No active journey found, using test route');
        if (mounted) {
          setState(() => _currentRoute = Route8BTestData.getRoute8B());
        }
      }
    } catch (e) {
      debugPrint('Error loading active route: $e');
      // Use test route as fallback
      if (mounted) {
        setState(() => _currentRoute = Route8BTestData.getRoute8B());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setUpRouteOnMap() async {
    if (_mapController == null || !mounted) return;

    // Clear existing polylines and stop markers (keep current location marker)
    _polylines.clear();
    _markers.removeWhere((m) => m.markerId.value.startsWith('stop_'));

    if (_currentRoute != null && _currentRoute!.stops.isNotEmpty) {
      // Sort stops by sequence to ensure proper order
      final sortedStops = List<RouteStop>.from(_currentRoute!.stops)
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      debugPrint('Setting up route with ${sortedStops.length} stops');
      for (int i = 0; i < sortedStops.length; i++) {
        final stop = sortedStops[i];
        debugPrint('Stop ${i + 1}: ${stop.name} (${stop.latitude}, ${stop.longitude}) - Sequence: ${stop.sequence}');
      }

      // Add markers for stops first
      for (int i = 0; i < sortedStops.length; i++) {
        final stop = sortedStops[i];
        final markerId = 'stop_${stop.id}_$i'; // Include index to ensure uniqueness
        
        _markers.add(
          Marker(
            markerId: MarkerId(markerId),
            position: LatLng(stop.latitude, stop.longitude),
            infoWindow: InfoWindow(
              title: stop.name,
              snippet: 'Stop ${i + 1} of ${sortedStops.length} (Seq: ${stop.sequence})',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              i == 0
                  ? BitmapDescriptor.hueGreen // Start
                  : i == sortedStops.length - 1
                      ? BitmapDescriptor.hueRed // End
                      : BitmapDescriptor.hueBlue, // Mid stops
            ),
          ),
        );
      }

      // Get road-based directions
      debugPrint('Getting road-based directions...');
      if (mounted) {
        setState(() => _isLoadingDirections = true);
      }
      
      final roadPoints = await DirectionsService.getBusRouteDirections(_currentRoute!);
      
      if (mounted) {
        setState(() => _isLoadingDirections = false);
      }
      
      if (roadPoints != null && roadPoints.isNotEmpty) {
        debugPrint('Got ${roadPoints.length} road-based points');
        
        _polylines.add(
          Polyline(
            polylineId: PolylineId(_currentRoute!.id),
            points: roadPoints,
            color: AppConstants.primaryColor,
            width: 6,
            geodesic: false, // Set to false for road-based routing
            patterns: [], // Solid line
          ),
        );
      } else {
        debugPrint('Failed to get road directions, using straight line fallback');
        // Fallback to straight line if directions fail
        final routePoints = sortedStops
            .map((stop) => LatLng(stop.latitude, stop.longitude))
            .toList();

        _polylines.add(
          Polyline(
            polylineId: PolylineId(_currentRoute!.id),
            points: routePoints,
            color: AppConstants.primaryColor,
            width: 6,
            geodesic: true,
          ),
        );
      }

      // Update the map with new markers and polylines
      if (mounted) {
        setState(() {});
      }
      
      // Always fit the map to show the entire route
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _mapController != null) {
          _fitMapToRoute();
        }
      });
    } else {
      debugPrint('No route available, showing only current location');
      // Just show current location if no route
      _fitMapToCurrentLocation();
    }
  }

  void _fitMapToRoute() {
    if (_currentRoute == null || _currentRoute!.stops.isEmpty || _mapController == null) return;

    // Sort stops by sequence to ensure proper bounds calculation
    final sortedStops = List<RouteStop>.from(_currentRoute!.stops)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    // Include stops + current location in bounds
    final allPoints = [
      ...sortedStops.map((s) => LatLng(s.latitude, s.longitude)),
      _currentLocation
    ];

    if (allPoints.isEmpty) return;

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final point in allPoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // Calculate the span of the route
    final latSpan = maxLat - minLat;
    final lngSpan = maxLng - minLng;
    final maxSpan = latSpan > lngSpan ? latSpan : lngSpan;

    // Add some padding to the bounds to ensure the route is fully visible
    final latPadding = latSpan * 0.15; // 15% padding
    final lngPadding = lngSpan * 0.15; // 15% padding
    
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );

    // Adjust padding based on route span for better zoom level
    final padding = maxSpan > 0.1 ? 80.0 : 50.0; // Larger padding for longer routes
    
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
  }

  void _fitMapToCurrentLocation() {
    if (_mapController == null) return;
    
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation, 15), // Better zoom level for current location
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await _locationService.getCurrentLocation();
      final newLocation = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentLocation = newLocation;

          // Replace current location marker
          _markers.removeWhere((m) => m.markerId.value == 'current_location');
          _markers.add(
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentLocation,
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
            ),
          );
        });
      }

      // If map controller is ready, set up the route
      if (_mapController != null && mounted) {
        _setUpRouteOnMap();
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      // Even if location fails, set up the route with test data
      if (_mapController != null && mounted) {
        _setUpRouteOnMap();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('MapScreen build: _isLoading=$_isLoading, _currentRoute=${_currentRoute?.name}, markers=${_markers.length}');
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentRoute?.name ?? 'Live Map'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: AppConstants.accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
          if (_currentRoute != null)
            IconButton(
              icon: const Icon(Icons.zoom_out_map),
              onPressed: _fitMapToRoute,
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _mapError
                  ? _buildMapErrorWidget()
                  : GoogleMap(
                      onMapCreated: (controller) {
                        _mapController = controller;
                        // Set up route after a short delay to ensure map is ready
                        Future.delayed(const Duration(milliseconds: 500), () {
                          if (mounted) {
                            _setUpRouteOnMap();
                          }
                        });
                      },
                      initialCameraPosition: CameraPosition(
                        target: _currentLocation,
                        zoom: 12, // Slightly more zoomed out initially
                      ),
                      polylines: _polylines,
                      markers: _markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      compassEnabled: true,
                    ),
          if (_isLoadingDirections)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading road directions...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () {
              debugPrint('Manual route setup triggered');
              _setUpRouteOnMap();
            },
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            heroTag: "route_setup",
            child: const Icon(Icons.route),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: AppConstants.accentColor,
            heroTag: "location",
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
