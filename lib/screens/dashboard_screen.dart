import 'dart:async' show StreamSubscription;
import 'package:busmitra_driver/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';
import 'package:busmitra_driver/widgets/status_indicator.dart';
import 'package:busmitra_driver/services/location_service.dart';
import 'package:busmitra_driver/services/database_service.dart';
import 'package:busmitra_driver/services/auth_service.dart';
import 'package:busmitra_driver/services/background_location_service.dart';
import 'package:busmitra_driver/models/route_model.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  DashboardScreenState createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  String _currentStatus = 'Off Duty';
  Color _statusColor = AppConstants.lightTextColor;

  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final BackgroundLocationService _backgroundLocationService = BackgroundLocationService.instance;

  bool _isLoading = true;
  bool _isTracking = false;
  BusRoute? _currentRoute;
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _activeJourney;
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<User?>? _authSubscription;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupAuthListener();
    _loadInitialData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // App is in foreground, resume location tracking if it was active
        if (_isTracking) {
          _resumeLocationTracking();
        }
        // Stop background service when app comes to foreground
        if (_backgroundLocationService.isRunning) {
          _backgroundLocationService.stopBackgroundTracking();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App is in background, start background location tracking if on duty
        if (_isTracking && (_currentStatus == 'On Route' || _activeJourney != null)) {
          _startBackgroundLocationTracking();
        } else if (_isTracking) {
          _pauseLocationTracking();
        }
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }
  void _setupAuthListener() {
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (user == null) {
        // Redirect to login if user signs out
        _redirectToLogin();
      }
    });
  }
  void _redirectToLogin() async {
    if (mounted) {
      // Stop location tracking and clean up before redirecting
      if (_isTracking) {
        _stopLocationTracking();
      }
      _databaseService.removeDriverFromActive();
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    }
  }
  Future<void> _loadInitialData() async {
    try {
      // Check if user is logged in first
      final user = _authService.getCurrentUser();
      if (user == null) {
        _redirectToLogin();
        return;
      }

      await _loadDriverData();
      await _checkActiveJourney();
    } catch (e) {
      debugPrint('Error loading initial data: $e');
      _showSnackBar('Error loading data: $e', AppConstants.errorColor);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDriverData() async {
    final data = await _authService.getCurrentDriverData();
    if (mounted) {
      setState(() => _driverData = data);
    }
  }

  Future<void> _checkActiveJourney() async {
    final journey = await _databaseService.getActiveJourney();
    if (mounted) {
      setState(() {
        _activeJourney = journey;
        if (_activeJourney != null) {
          _currentStatus = 'On Route';
          _statusColor = Colors.blue;
          _isTracking = true;
          _startLocationTracking();
        }
      });
    }
  }

  void _changeStatus(String newStatus) {
    if (mounted) {
      setState(() {
        _currentStatus = newStatus;
        switch (newStatus) {
          case 'Start Duty':
            _statusColor = Colors.green;
            _showRouteSelection();
            break;
          case 'On Route':
            _statusColor = Colors.blue;
            // Update background service with current route
            _backgroundLocationService.updateRoute(_currentRoute);
            break;
          case 'Break':
            _statusColor = Colors.orange;
            _pauseLocationTracking();
            // Pause background tracking during break
            _backgroundLocationService.pauseTracking();
            break;
          case 'End Duty':
            _statusColor = AppConstants.errorColor;
            _stopLocationTracking();
            _endJourney();
            break;
          default:
            _statusColor = AppConstants.lightTextColor;
        }
      });
    }
  }

  Future<void> _showRouteSelection() async {
    final routes = await _databaseService.getRoutes();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Route'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return ListTile(
                  title: Text(route.name),
                  subtitle: Text('${route.startPoint} → ${route.endPoint}'),
                  onTap: () {
                    Navigator.pop(context);
                    _startJourney(route);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

Future<void> _startJourney(BusRoute route) async {
  try {
    if (mounted) {
      setState(() => _currentRoute = route);
    }
    await _databaseService.startJourney(route);

    // Update background service with the new route
    _backgroundLocationService.updateRoute(route);

    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen.withRoute(route: route),
      ),
    );

    _startLocationTracking();
  } catch (e) {
    _showSnackBar('Failed to start journey: $e', AppConstants.errorColor);
    if (mounted) {
      setState(() => _currentRoute = null);
    }
  }
}
  Future<void> _startLocationTracking() async {
    try {
      // Check basic location permission first
      final permission = await _locationService.checkLocationPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        final newPermission =
            await _locationService.requestLocationPermission();
        if (newPermission != LocationPermission.whileInUse &&
            newPermission != LocationPermission.always) {
          _showSnackBar('Location permission is required for tracking',
              AppConstants.errorColor);
          return;
        }
      }

      // Request background location permission for better tracking
      final hasBackgroundPermission = await _locationService.hasBackgroundLocationPermission();
      if (!hasBackgroundPermission) {
        final backgroundGranted = await _locationService.requestBackgroundLocationPermission();
        if (!backgroundGranted) {
          _showSnackBar('Background location permission is recommended for continuous tracking',
              Colors.orange);
        }
      }

      final isEnabled = await _locationService.isLocationServiceEnabled();
      if (!isEnabled) {
        _showSnackBar('Please enable location services',
            AppConstants.errorColor);
        return;
      }

      if (mounted) {
        setState(() => _isTracking = true);
      }

      // Set driver as online in realtime database
      await _databaseService.setDriverOnlineStatus(true);

      // Use appropriate location stream based on permission
      final locationStream = hasBackgroundPermission 
          ? _locationService.getBackgroundLocationStream()
          : _locationService.getLocationStream();

      _locationSubscription = locationStream.listen((position) {
        // Only update if location is accurate enough
        if (_locationService.isLocationAccurate(position)) {
          _databaseService.updateDriverLocation(
            _currentRoute?.id, // Pass null if no route
            position.latitude,
            position.longitude,
            speed: position.speed,
            heading: position.heading,
            accuracy: position.accuracy,
          );
          debugPrint(
              'Location updated: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
        } else {
          debugPrint('Location accuracy too low: ${position.accuracy}m, skipping update');
        }
      }, onError: (error) {
        debugPrint('Location stream error: $error');
        _showSnackBar('Location error: $error', AppConstants.errorColor);
        if (mounted) {
          setState(() => _isTracking = false);
        }
      });
    } catch (e) {
      _showSnackBar('Failed to start location tracking: $e',
          AppConstants.errorColor);
      if (mounted) {
        setState(() => _isTracking = false);
      }
    }
  }

  void _pauseLocationTracking() {
    _locationSubscription?.pause();
    // Don't change _isTracking state here as we want to resume later
    // Just pause the location updates temporarily
  }

  void _resumeLocationTracking() {
    if (_locationSubscription != null) {
      _locationSubscription?.resume();
    } else {
      // If subscription was cancelled, restart location tracking
      _startLocationTracking();
    }
  }

  void _stopLocationTracking() async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    
    // Stop background location tracking
    await _backgroundLocationService.stopBackgroundTracking();
    
    if (mounted) {
      setState(() => _isTracking = false);
    }
    
    // Set driver as offline in realtime database
    await _databaseService.setDriverOnlineStatus(false);
  }

  /// Start background location tracking when app goes to background
  Future<void> _startBackgroundLocationTracking() async {
    try {
      await _backgroundLocationService.startBackgroundTracking(route: _currentRoute);
      debugPrint('Background location tracking started');
    } catch (e) {
      debugPrint('Error starting background location tracking: $e');
    }
  }

  Future<void> _endJourney() async {
    await _databaseService.endJourney();
    if (mounted) {
      setState(() {
        _currentRoute = null;
        _activeJourney = null;
      });
    }
  }

  void _showIssueDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? selectedIssue;
        final descriptionController = TextEditingController();

        return AlertDialog(
          title: const Text('Report Issue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedIssue,
                hint: const Text('Select issue type'),
                items: const [
                  DropdownMenuItem(value: 'traffic', child: Text('Heavy Traffic')),
                  DropdownMenuItem(value: 'breakdown', child: Text('Vehicle Breakdown')),
                  DropdownMenuItem(value: 'accident', child: Text('Accident')),
                  DropdownMenuItem(value: 'road_block', child: Text('Road Block')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (value) => selectedIssue = value,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                if (selectedIssue != null) {
                  _databaseService.reportIssue(
                    selectedIssue!,
                    descriptionController.text,
                  );
                  Navigator.pop(context);
                  _showSnackBar('Issue reported successfully',
                      AppConstants.primaryColor);
                }
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );
  }

  void _triggerSOS() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('SOS Emergency Alert'),
          content: const Text(
            'Are you sure you want to send an emergency alert? This will notify authorities and your transport manager.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                _databaseService.triggerSOS();
                Navigator.pop(context);
                _showSnackBar('Emergency alert sent! Help is on the way.',
                    AppConstants.errorColor);
              },
              child: const Text('Send SOS',
                  style: TextStyle(color: AppConstants.errorColor)),
            ),
          ],
        );
      },
    );
  }

  void _toggleLocationSharing() {
    // Check if driver is on duty (any active status that requires location tracking)
    final isOnDuty = _currentStatus == 'On Route' || 
                     _currentStatus == 'Start Duty' || 
                     _activeJourney != null;
    
    if (isOnDuty && _isTracking) {
      _showLocationSharingRestrictionDialog();
      return;
    }
    
    if (_isTracking) {
      _stopLocationTracking();
      _showSnackBar('Location sharing stopped', AppConstants.lightTextColor);
    } else {
      _startLocationTracking();
      _showSnackBar('Location sharing started', Colors.green);
    }
  }

  void _showLocationSharingRestrictionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 28),
              const SizedBox(width: 12),
              const Text('Cannot Turn Off Location Sharing'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'You cannot turn off location sharing while on an active trip.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Why is this restricted?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Passengers need to track your bus in real-time\n'
                      '• Safety and security requirements\n'
                      '• Trip monitoring and management\n'
                      '• Emergency response capabilities',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'To turn off location sharing, you must first end your current trip.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Understood'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _changeStatus('End Duty');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: AppConstants.accentColor,
              ),
              child: const Text('End Trip'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: AppConstants.accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_driverData != null)
              Text(
                'Hello, ${_driverData!['name'] ?? 'Driver'}!',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            const SizedBox(height: 16),
            StatusIndicator(status: _currentStatus, color: _statusColor),
            const SizedBox(height: 20),

            // Location Sharing Toggle
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isTracking ? Icons.location_on : Icons.location_off,
                        color: _isTracking ? Colors.green : AppConstants.lightTextColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Live Location Sharing',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _isTracking ? Colors.green : AppConstants.textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isTracking
                                  ? 'Your location is being shared with passengers'
                                  : 'Location sharing is disabled',
                              style: TextStyle(
                                fontSize: 14,
                                color: _isTracking ? Colors.green : AppConstants.lightTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isTracking,
                        onChanged: (_activeJourney != null || _currentStatus == 'On Route' || _currentStatus == 'Start Duty') 
                            ? null 
                            : (value) => _toggleLocationSharing(),
                        activeThumbColor: Colors.green,
                        inactiveThumbColor: AppConstants.lightTextColor,
                        inactiveTrackColor: AppConstants.lightTextColor.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  if (_isTracking) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Location data is being sent to Firebase Realtime Database for passenger tracking',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.update, color: Colors.green, size: 14),
                              const SizedBox(width: 8),
                              Text(
                                'Updates every 30 seconds or 5 meters movement',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  if ((_activeJourney != null || _currentStatus == 'On Route' || _currentStatus == 'Start Duty') && _isTracking) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Location sharing is locked during active trip. End your trip to disable.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Current route
            if (_currentRoute != null || _activeJourney != null)
              Card(
                elevation: 4,
                color: AppConstants.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Current Route',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textColor,
                          )),
                      const SizedBox(height: 10),
                      Text(
                        _activeJourney?['routeName'] ?? _currentRoute?.name ?? '',
                        style: const TextStyle(
                          color: AppConstants.textColor,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Bus: ${_driverData?['busNumber'] ?? 'Unknown'}',
                        style: const TextStyle(color: AppConstants.lightTextColor),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MapScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: AppConstants.accentColor,
                        ),
                        child: const Text('View Live Route on Map'),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            const Text('Change Status:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                )),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                if (_currentStatus != 'Start Duty' && _currentStatus != 'On Route')
                  _buildStatusButton('Start Duty', Colors.green),
                if (_currentStatus == 'Start Duty' || _currentStatus == 'Break')
                  _buildStatusButton('On Route', Colors.blue),
                if (_currentStatus == 'On Route')
                  _buildStatusButton('Break', Colors.orange),
                if (_currentStatus == 'On Route' || _currentStatus == 'Break')
                  _buildStatusButton('End Duty', AppConstants.errorColor),
              ],
            ),

            const SizedBox(height: 20),

            const Text('Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                )),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              children: [
                ActionChip(
                  label: const Text('Report Issue'),
                  onPressed: _showIssueDialog,
                  backgroundColor: AppConstants.primaryColor,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
                ActionChip(
                  label: const Text('SOS Emergency'),
                  onPressed: _triggerSOS,
                  backgroundColor: AppConstants.errorColor,
                  labelStyle: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String text, Color color) {
    return ElevatedButton(
      onPressed: () => _changeStatus(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppConstants.accentColor,
      ),
      child: Text(text),
    );
  }
}
