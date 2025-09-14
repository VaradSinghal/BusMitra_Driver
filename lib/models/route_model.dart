// lib/models/route_model.dart
import 'package:flutter/foundation.dart';
class BusRoute {
  final String id;
  final String name;
  final String startPoint;
  final String endPoint;
  final double distance;
  final int estimatedTime;
  final List<RouteStop> stops;
  final bool active;

  BusRoute({
    required this.id,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    required this.distance,
    required this.estimatedTime,
    required this.stops,
    required this.active,
  });

  factory BusRoute.fromMap(String id, Map<String, dynamic> map) {
    // Handle different data types from Firestore
    final stopsData = map['stops'] as List<dynamic>? ?? [];
    debugPrint('BusRoute.fromMap - Raw stops data: $stopsData');
    final stops = stopsData.map((stop) {
      if (stop is Map<String, dynamic>) {
        return RouteStop.fromMap(stop);
      }
      debugPrint('BusRoute.fromMap - Invalid stop data: $stop');
      return RouteStop(
        id: '',
        name: '',
        latitude: 0,
        longitude: 0,
        sequence: 0,
      );
    }).toList();

    return BusRoute(
      id: id,
      name: map['name']?.toString() ?? '',
      startPoint: map['startPoint']?.toString() ?? '',
      endPoint: map['endPoint']?.toString() ?? '',
      distance: (map['distance'] is double) 
          ? map['distance'] as double 
          : (map['distance'] is int) 
            ? (map['distance'] as int).toDouble() 
            : 0.0,
      estimatedTime: (map['estimatedTime'] is int) 
          ? map['estimatedTime'] as int 
          : 0,
      stops: stops,
      active: map['active'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startPoint': startPoint,
      'endPoint': endPoint,
      'distance': distance,
      'estimatedTime': estimatedTime,
      'stops': stops.map((stop) => stop.toMap()).toList(),
      'active': active,
    };
  }
}

class RouteStop {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int sequence;

  RouteStop({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sequence,
  });

  factory RouteStop.fromMap(Map<String, dynamic> map) {
    // Debug the raw data
    debugPrint('RouteStop.fromMap - Raw data: $map');
    
    // Handle latitude with more robust parsing and alternative field names
    double latitude = 0.0;
    if (map['latitude'] != null) {
      if (map['latitude'] is double) {
        latitude = map['latitude'] as double;
      } else if (map['latitude'] is int) {
        latitude = (map['latitude'] as int).toDouble();
      } else if (map['latitude'] is String) {
        latitude = double.tryParse(map['latitude'] as String) ?? 0.0;
      }
    } else if (map['lat'] != null) {
      // Try alternative field name 'lat'
      if (map['lat'] is double) {
        latitude = map['lat'] as double;
      } else if (map['lat'] is int) {
        latitude = (map['lat'] as int).toDouble();
      } else if (map['lat'] is String) {
        latitude = double.tryParse(map['lat'] as String) ?? 0.0;
      }
    } else if (map['coordinates'] != null && map['coordinates'] is Map) {
      // Try nested coordinates object
      final coords = map['coordinates'] as Map<String, dynamic>;
      if (coords['lat'] != null) {
        if (coords['lat'] is double) {
          latitude = coords['lat'] as double;
        } else if (coords['lat'] is int) {
          latitude = (coords['lat'] as int).toDouble();
        } else if (coords['lat'] is String) {
          latitude = double.tryParse(coords['lat'] as String) ?? 0.0;
        }
      } else if (coords['latitude'] != null) {
        if (coords['latitude'] is double) {
          latitude = coords['latitude'] as double;
        } else if (coords['latitude'] is int) {
          latitude = (coords['latitude'] as int).toDouble();
        } else if (coords['latitude'] is String) {
          latitude = double.tryParse(coords['latitude'] as String) ?? 0.0;
        }
      }
    }
    
    // Handle longitude with more robust parsing and alternative field names
    double longitude = 0.0;
    if (map['longitude'] != null) {
      if (map['longitude'] is double) {
        longitude = map['longitude'] as double;
      } else if (map['longitude'] is int) {
        longitude = (map['longitude'] as int).toDouble();
      } else if (map['longitude'] is String) {
        longitude = double.tryParse(map['longitude'] as String) ?? 0.0;
      }
    } else if (map['lng'] != null) {
      // Try alternative field name 'lng'
      if (map['lng'] is double) {
        longitude = map['lng'] as double;
      } else if (map['lng'] is int) {
        longitude = (map['lng'] as int).toDouble();
      } else if (map['lng'] is String) {
        longitude = double.tryParse(map['lng'] as String) ?? 0.0;
      }
    } else if (map['lon'] != null) {
      // Try alternative field name 'lon'
      if (map['lon'] is double) {
        longitude = map['lon'] as double;
      } else if (map['lon'] is int) {
        longitude = (map['lon'] as int).toDouble();
      } else if (map['lon'] is String) {
        longitude = double.tryParse(map['lon'] as String) ?? 0.0;
      }
    } else if (map['coordinates'] != null && map['coordinates'] is Map) {
      // Try nested coordinates object
      final coords = map['coordinates'] as Map<String, dynamic>;
      if (coords['lng'] != null) {
        if (coords['lng'] is double) {
          longitude = coords['lng'] as double;
        } else if (coords['lng'] is int) {
          longitude = (coords['lng'] as int).toDouble();
        } else if (coords['lng'] is String) {
          longitude = double.tryParse(coords['lng'] as String) ?? 0.0;
        }
      } else if (coords['longitude'] != null) {
        if (coords['longitude'] is double) {
          longitude = coords['longitude'] as double;
        } else if (coords['longitude'] is int) {
          longitude = (coords['longitude'] as int).toDouble();
        } else if (coords['longitude'] is String) {
          longitude = double.tryParse(coords['longitude'] as String) ?? 0.0;
        }
      }
    }
    
    debugPrint('RouteStop.fromMap - Parsed: lat=$latitude, lng=$longitude');
    
    return RouteStop(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      latitude: latitude,
      longitude: longitude,
      sequence: (map['sequence'] is int) ? map['sequence'] as int : 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'sequence': sequence,
    };
  }
}