import 'package:busmitra_driver/models/route_model.dart';
import 'package:busmitra_driver/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';
import 'package:busmitra_driver/services/auth_service.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();
  Map<String, dynamic>? _driverData;
  BusRoute? _assignedRoute;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  void _loadDriverData() async {
    try {
      final data = await _authService.getCurrentDriverData();
      setState(() {
        _driverData = data;
      });
     if (data?['assignedRoute'] != null) {
        final route = await _databaseService.getRouteById(data?['assignedRoute']);
        setState(() {
          _assignedRoute = route;
        });
      }
    } catch (e) {
      debugPrint('Error loading driver data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                navigator.pop();
                await _authService.logout();
                if (mounted) {
                  navigator.pushReplacementNamed('/login');
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: AppConstants.errorColor),
              ),
            ),
          ],
        );
      },
    );
  }

      @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: AppConstants.accentColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile Header (existing code)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppConstants.accentColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppConstants.primaryColor,
                          child: const Icon(
                            Icons.person,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _driverData?['name'] ?? 'Unknown Driver',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _driverData?['driverId'] ?? 'No ID',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppConstants.lightTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Assigned Route Information
                  if (_assignedRoute != null)
                    Card(
                      elevation: 4,
                      color: AppConstants.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Assigned Route',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.textColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _assignedRoute!.name,
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppConstants.textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_assignedRoute!.startPoint} to ${_assignedRoute!.endPoint}',
                              style: const TextStyle(
                                color: AppConstants.lightTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Distance: ${_assignedRoute!.distance} km • Time: ${_assignedRoute!.estimatedTime} min',
                              style: const TextStyle(
                                color: AppConstants.lightTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Stops: ${_assignedRoute!.stops.length}',
                              style: const TextStyle(
                                color: AppConstants.lightTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_assignedRoute == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No route assigned',
                          style: TextStyle(
                            color: AppConstants.lightTextColor,
                          ),
                        ),
                      ),
                    ),

            const SizedBox(height: 30),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                  foregroundColor: AppConstants.accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Logout',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppConstants.lightTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppConstants.textColor,
                    fontWeight: FontWeight.w500,
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