// Test data for Route 8B to verify map screen functionality
import 'package:busmitra_driver/models/route_model.dart';

class Route8BTestData {
  static BusRoute getRoute8B() {
    return BusRoute(
      id: "route_8B",
      name: "Route 8B: North Station to Airport",
      startPoint: "North Bus Station",
      endPoint: "International Airport",
      distance: 22.3,
      estimatedTime: 60,
      active: true,
      stops: [
        RouteStop(
          id: "stop_1",
          name: "North Bus Station",
          latitude: 28.7041,
          longitude: 77.1025,
          sequence: 1,
        ),
        RouteStop(
          id: "stop_2",
          name: "Metro Station",
          latitude: 28.7010,
          longitude: 77.1100,
          sequence: 2,
        ),
        RouteStop(
          id: "stop_3",
          name: "Business District",
          latitude: 28.6980,
          longitude: 77.1180,
          sequence: 3,
        ),
        RouteStop(
          id: "stop_4",
          name: "Convention Center",
          latitude: 28.6950,
          longitude: 77.1250,
          sequence: 4,
        ),
        RouteStop(
          id: "stop_5",
          name: "Hotel Zone",
          latitude: 28.6920,
          longitude: 77.1320,
          sequence: 5,
        ),
        RouteStop(
          id: "stop_6",
          name: "Airport Entrance",
          latitude: 28.6890,
          longitude: 77.1400,
          sequence: 6,
        ),
        RouteStop(
          id: "stop_7",
          name: "International Airport",
          latitude: 28.6860,
          longitude: 77.1480,
          sequence: 7,
        ),
      ],
    );
  }
}

