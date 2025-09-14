import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:busmitra_driver/services/database_service.dart';
import 'package:busmitra_driver/models/route_model.dart';

class BackgroundLocationService {
  static BackgroundLocationService? _instance;
  static BackgroundLocationService get instance => _instance ??= BackgroundLocationService._();
  
  BackgroundLocationService._();

  StreamSubscription<Position>? _locationSubscription;
  final DatabaseService _databaseService = DatabaseService();
  
  bool _isRunning = false;
  BusRoute? _currentRoute;

  /// Start background location tracking
  Future<void> startBackgroundTracking({BusRoute? route}) async {
    if (_isRunning) return;

    try {
      _currentRoute = route;
      _isRunning = true;

      // Check if we have background location permission
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always) {
        debugPrint('Background location permission not granted');
        return;
      }

      // Configure location settings for background tracking
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Update every 5 meters for real-time tracking
        timeLimit: Duration(seconds: 10), // Update every 10 seconds for real-time tracking
      );

      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        _onLocationUpdate,
        onError: _onLocationError,
      );

      debugPrint('Background location tracking started');
    } catch (e) {
      debugPrint('Error starting background location tracking: $e');
      _isRunning = false;
    }
  }

  /// Stop background location tracking
  Future<void> stopBackgroundTracking() async {
    if (!_isRunning) return;

    try {
      await _locationSubscription?.cancel();
      _locationSubscription = null;
      _isRunning = false;
      
      // Set driver as offline
      await _databaseService.setDriverOnlineStatus(false);
      
      debugPrint('Background location tracking stopped');
    } catch (e) {
      debugPrint('Error stopping background location tracking: $e');
    }
  }

  /// Handle location updates
  void _onLocationUpdate(Position position) async {
    try {
      // Only update if location is accurate enough (more lenient for continuous tracking)
      if (position.accuracy <= 100) {
        await _databaseService.updateDriverLocation(
          _currentRoute?.id,
          position.latitude,
          position.longitude,
          speed: position.speed,
          heading: position.heading,
          accuracy: position.accuracy,
        );
        
        debugPrint('Background location updated: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint('Background location accuracy too low: ${position.accuracy}m');
      }
    } catch (e) {
      debugPrint('Error updating background location: $e');
    }
  }

  /// Handle location errors
  void _onLocationError(dynamic error) {
    debugPrint('Background location error: $error');
  }

  /// Check if background tracking is running
  bool get isRunning => _isRunning;

  /// Update current route
  void updateRoute(BusRoute? route) {
    _currentRoute = route;
  }

  /// Pause tracking (for break status)
  void pauseTracking() {
    _locationSubscription?.pause();
  }

  /// Resume tracking
  void resumeTracking() {
    _locationSubscription?.resume();
  }
}
