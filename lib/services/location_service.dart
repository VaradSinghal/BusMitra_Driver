import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static const int _updateIntervalSeconds = 10; // More frequent updates - every 10 seconds
  static const int _distanceFilterMeters = 5; // Update every 5 meters for real-time tracking

  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  /// Get location stream with optimized settings for regular updates
  Stream<Position> getLocationStream() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: _distanceFilterMeters,
      timeLimit: const Duration(seconds: _updateIntervalSeconds),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Get background location stream for when app is in background
  Stream<Position> getBackgroundLocationStream() {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _distanceFilterMeters,
      timeLimit: const Duration(seconds: _updateIntervalSeconds),
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Request background location permission
  Future<bool> requestBackgroundLocationPermission() async {
    // First check if we have basic location permission
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse && 
          permission != LocationPermission.always) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    // Request background location permission
    final backgroundPermission = await Permission.locationAlways.request();
    return backgroundPermission == PermissionStatus.granted;
  }

  /// Check if background location permission is granted
  Future<bool> hasBackgroundLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<LocationPermission> checkLocationPermission() async {
    return await Geolocator.checkPermission();
  }

  Future<LocationPermission> requestLocationPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get location with timeout
  Future<Position?> getLocationWithTimeout({Duration timeout = const Duration(seconds: 10)}) async {
    try {
      return await getCurrentLocation().timeout(timeout);
    } catch (e) {
      debugPrint('Error getting location with timeout: $e');
      return null;
    }
  }

  /// Check if location is accurate enough for tracking
  bool isLocationAccurate(Position position) {
    return position.accuracy <= 100; // More lenient - within 100 meters accuracy
  }
}