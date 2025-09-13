import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:busmitra_driver/models/route_model.dart';
import 'package:busmitra_driver/config/api_config.dart';

class DirectionsService {
  static const String _baseUrl = ApiConfig.directionsBaseUrl;
  static const String _apiKey = ApiConfig.googleMapsApiKey;
  

  static Future<List<LatLng>?> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    try {
      final waypointsParam = waypoints != null && waypoints.isNotEmpty
          ? '&waypoints=${waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|')}'
          : '';
      
      final url = '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '$waypointsParam'
          '&mode=driving'
          '&key=$_apiKey';

      debugPrint('Directions URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(
        Duration(seconds: ApiConfig.requestTimeoutSeconds),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;
          
          List<LatLng> points = [];
          
          for (var leg in legs) {
            final steps = leg['steps'] as List;
            for (var step in steps) {
              final polyline = step['polyline']['points'] as String;
              final decodedPoints = _decodePolyline(polyline);
              points.addAll(decodedPoints);
            }
          }
          
          debugPrint('Generated ${points.length} road-based points');
          return points;
        } else {
          debugPrint('Directions API error: ${data['status']}');
          return null;
        }
      } else {
        debugPrint('HTTP error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting directions: $e');
      return null;
    }
  }

  /// Get directions for a complete bus route with all stops
  static Future<List<LatLng>?> getBusRouteDirections(BusRoute route) async {
    if (route.stops.length < 2) return null;

    // Sort stops by sequence
    final sortedStops = List<RouteStop>.from(route.stops)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final origin = LatLng(sortedStops.first.latitude, sortedStops.first.longitude);
    final destination = LatLng(sortedStops.last.latitude, sortedStops.last.longitude);
    
    // Use intermediate stops as waypoints (excluding first and last)
    final waypoints = sortedStops.length > 2
        ? sortedStops.skip(1).take(sortedStops.length - 2)
            .map((stop) => LatLng(stop.latitude, stop.longitude))
            .toList()
        : null;

    try {
      return await getDirections(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
      );
    } catch (e) {
      debugPrint('Error getting directions, using fallback: $e');
      // Fallback to straight line between stops
      return sortedStops.map((stop) => LatLng(stop.latitude, stop.longitude)).toList();
    }
  }

  /// Decode Google's polyline string to LatLng points
  static List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0;
    int len = polyline.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Get step-by-step directions for a route
  static Future<List<RouteStep>?> getRouteSteps(BusRoute route) async {
    try {
      final sortedStops = List<RouteStop>.from(route.stops)
        ..sort((a, b) => a.sequence.compareTo(b.sequence));

      final origin = LatLng(sortedStops.first.latitude, sortedStops.first.longitude);
      final destination = LatLng(sortedStops.last.latitude, sortedStops.last.longitude);
      
      final waypoints = sortedStops.length > 2
          ? sortedStops.skip(1).take(sortedStops.length - 2)
              .map((stop) => LatLng(stop.latitude, stop.longitude))
              .toList()
          : null;

      final waypointsParam = waypoints != null && waypoints.isNotEmpty
          ? '&waypoints=${waypoints.map((wp) => '${wp.latitude},${wp.longitude}').join('|')}'
          : '';
      
      final url = '$_baseUrl?origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '$waypointsParam'
          '&mode=driving'
          '&key=$_apiKey';

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final legs = route['legs'] as List;
          
          List<RouteStep> steps = [];
          
          for (var leg in legs) {
            final legSteps = leg['steps'] as List;
            for (var step in legSteps) {
              steps.add(RouteStep(
                instruction: step['html_instructions'] as String,
                distance: step['distance']['text'] as String,
                duration: step['duration']['text'] as String,
                startLocation: LatLng(
                  step['start_location']['lat'] as double,
                  step['start_location']['lng'] as double,
                ),
                endLocation: LatLng(
                  step['end_location']['lat'] as double,
                  step['end_location']['lng'] as double,
                ),
              ));
            }
          }
          
          return steps;
        }
      }
    } catch (e) {
      debugPrint('Error getting route steps: $e');
    }
    
    return null;
  }
}

class RouteStep {
  final String instruction;
  final String distance;
  final String duration;
  final LatLng startLocation;
  final LatLng endLocation;

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.startLocation,
    required this.endLocation,
  });
}
