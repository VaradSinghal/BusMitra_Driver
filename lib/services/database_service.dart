import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:busmitra_driver/models/route_model.dart';
import 'package:busmitra_driver/services/auth_service.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtimeDb = FirebaseDatabase.instance;
  final CollectionReference _journeysCollection = FirebaseFirestore.instance.collection('journeys');

  /// ================= FIRESTORE (static data) =================

  // Get all active routes
  Future<List<BusRoute>> getRoutes() async {
    try {
      final querySnapshot = await _firestore
          .collection('routes')
          .where('active', isEqualTo: true)
          .get();

      return querySnapshot.docs
          .map((doc) => BusRoute.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('Error fetching routes: $e');
      return [];
    }
  }

  // Get a specific route by ID
  Future<BusRoute?> getRouteById(String routeId) async {
    try {
      final doc = await _firestore.collection('routes').doc(routeId).get();
      if (doc.exists) {
        return BusRoute.fromMap(doc.id, doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching route: $e');
      return null;
    }
  }

  // Get routes assigned to current driver
  Future<List<BusRoute>> getAssignedRoutes() async {
    try {
      final driverData = await AuthService().getCurrentDriverData();
      final assignedRouteId = driverData?['assignedRoute'];

      if (assignedRouteId != null) {
        final route = await getRouteById(assignedRouteId);
        return route != null ? [route] : [];
      }
      return await getRoutes();
    } catch (e) {
      debugPrint('Error fetching assigned routes: $e');
      return [];
    }
  }

  // Start a journey → Save to Firestore
// In your DatabaseService class
Future<void> startJourney(BusRoute route) async {
  try {
    // Get the current driver ID safely
    final driverId = await AuthService().getCurrentDriverId();
    if (driverId == null) {
      throw Exception('No driver is logged in');
    }

    // Get driver data safely
    final driverData = await AuthService().getCurrentDriverData();
    if (driverData == null) {
      throw Exception('Driver data not found');
    }

    // Create journey document
    final journeyData = {
      'routeId': route.id,
      'routeName': route.name,
      'driverId': driverId,
      'driverName': driverData['name'] ?? 'Unknown Driver', // Use null-safe access
      'busNumber': driverData['busNumber'] ?? 'Unknown', // Use null-safe access
      'startPoint': route.startPoint,
      'endPoint': route.endPoint,
      'startTime': FieldValue.serverTimestamp(),
      'status': 'active',
      'currentLocation': null,
      'speed': 0,
      'heading': 0,
    };

    // Add to journeys collection
    await _journeysCollection.add(journeyData);

    debugPrint('Journey started for route: ${route.name}');

  } catch (e) {
    debugPrint('Error starting journey: $e');
    throw Exception('Failed to start journey: $e');
  }
}

  // End journey → Firestore
  Future<void> endJourney() async {
    final driverId = await AuthService().getCurrentDriverId();
    await _firestore.collection('active_drivers').doc(driverId).delete();
  }

  // Check if driver has active journey
  Future<Map<String, dynamic>?> getActiveJourney() async {
    final driverId = await AuthService().getCurrentDriverId();
    final doc =
        await _firestore.collection('active_drivers').doc(driverId).get();
    return doc.exists ? doc.data() : null;
  }

  // Report an issue → Firestore
  Future<void> reportIssue(String issueType, String description) async {
    final driverId = await AuthService().getCurrentDriverId();
    final driverData = await AuthService().getCurrentDriverData();
    final activeJourney = await getActiveJourney();

    await _firestore.collection('reported_issues').add({
      'driverId': driverId,
      'driverName': driverData?['name'] ?? 'Unknown Driver',
      'busNumber': driverData?['busNumber'] ?? 'Unknown Bus',
      'issueType': issueType,
      'description': description,
      'routeId': activeJourney?['routeId'],
      'routeName': activeJourney?['routeName'],
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // Trigger SOS → Firestore
  Future<void> triggerSOS() async {
    final driverId = await AuthService().getCurrentDriverId();
    final driverData = await AuthService().getCurrentDriverData();
    final activeJourney = await getActiveJourney();

    await _firestore.collection('emergency_alerts').add({
      'driverId': driverId,
      'driverName': driverData?['name'] ?? 'Unknown Driver',
      'busNumber': driverData?['busNumber'] ?? 'Unknown Bus',
      'routeId': activeJourney?['routeId'],
      'routeName': activeJourney?['routeName'],
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  /// ================= REALTIME DB (live tracking) =================

  // Push live driver location with improved error handling and validation
  Future<void> updateDriverLocation(
    String? routeId,
    double lat,
    double lng, {
    double speed = 0,
    double heading = 0,
    double accuracy = 0,
  }) async {
    try {
      final driverId = await AuthService().getCurrentDriverId();
      final driverData = await AuthService().getCurrentDriverData();

      if (driverId == null) {
        debugPrint('No driver ID available for location update');
        return;
      }

      // Validate coordinates
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        debugPrint('Invalid coordinates: lat=$lat, lng=$lng');
        return;
      }

      // Get route name efficiently
      String routeName = 'No Route';
      if (routeId != null && routeId.isNotEmpty && routeId != 'no_route') {
        routeName = await _getRouteName(routeId);
      }

      final locationData = {
        'driverId': driverId,
        'driverName': driverData?['name'] ?? 'Unknown Driver',
        'busNumber': driverData?['busNumber'] ?? 'Unknown Bus',
        'routeId': routeId ?? 'no_route',
        'routeName': routeName,
        'latitude': lat,
        'longitude': lng,
        'speed': speed,
        'heading': heading,
        'accuracy': accuracy,
        'timestamp': ServerValue.timestamp,
        'isOnline': true,
        'lastSeen': ServerValue.timestamp,
        'isOnDuty': true, // Indicate driver is on duty
      };

      // Update active driver location with retry mechanism
      await _updateWithRetry('active_drivers/$driverId', locationData);

      // Keep location history for analytics (only if accuracy is good)
      if (accuracy <= 50) { // Only store accurate locations
        await _realtimeDb.ref('location_history/$driverId').push().set({
          'latitude': lat,
          'longitude': lng,
          'speed': speed,
          'heading': heading,
          'accuracy': accuracy,
          'timestamp': ServerValue.timestamp,
          'routeId': routeId ?? 'no_route',
          'routeName': routeName,
        });
      }

      debugPrint('Location updated successfully: $lat, $lng (accuracy: ${accuracy}m)');
    } catch (e) {
      debugPrint('Error updating driver location: $e');
      // Don't rethrow to prevent breaking the location stream
    }
  }

  // Helper method to update with retry mechanism
  Future<void> _updateWithRetry(String path, Map<String, dynamic> data, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        await _realtimeDb.ref(path).update(data);
        return;
      } catch (e) {
        debugPrint('Update attempt ${i + 1} failed: $e');
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: 1 * (i + 1))); // Exponential backoff
      }
    }
  }

  // Get route name by ID
  Future<String> _getRouteName(String routeId) async {
    try {
      final route = await getRouteById(routeId);
      return route?.name ?? 'Unknown Route';
    } catch (e) {
      return 'Unknown Route';
    }
  }

  // Set driver online status
  Future<void> setDriverOnlineStatus(bool isOnline) async {
    try {
      final driverId = await AuthService().getCurrentDriverId();
      final driverData = await AuthService().getCurrentDriverData();

      if (driverId == null) return;

      await _realtimeDb.ref('active_drivers/$driverId').update({
        'isOnline': isOnline,
        'lastSeen': ServerValue.timestamp,
        'driverId': driverId,
        'driverName': driverData?['name'] ?? 'Unknown Driver',
        'busNumber': driverData?['busNumber'] ?? 'Unknown Bus',
      });
    } catch (e) {
      debugPrint('Error setting driver online status: $e');
    }
  }

  // Remove driver from active drivers when going offline
  Future<void> removeDriverFromActive() async {
    try {
      final driverId = await AuthService().getCurrentDriverId();
      if (driverId != null) {
        await _realtimeDb.ref('active_drivers/$driverId').remove();
      }
    } catch (e) {
      debugPrint('Error removing driver from active: $e');
    }
  }
}
