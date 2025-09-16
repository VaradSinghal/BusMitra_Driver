import 'dart:async' show StreamSubscription, Timer;
import 'package:busmitra_driver/screens/login_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';
import 'package:busmitra_driver/widgets/modern_card.dart';
import 'package:busmitra_driver/widgets/animated_widgets.dart';
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
  Color _statusColor = AppConstants.textSecondary;

  final LocationService _locationService = LocationService();
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final BackgroundLocationService _backgroundLocationService = BackgroundLocationService.instance;

  bool _isLoading = true;
  bool _isTracking = false;
  bool _isConnected = true;
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
  Future<void> _redirectToLogin() async {
    if (mounted) {
      // Stop location tracking and clean up before redirecting
      if (_isTracking) {
        await _stopLocationTracking();
      }
      _databaseService.removeDriverFromActive();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
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
      _startConnectionMonitoring();
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
          _isTracking = true; // Ensure location tracking is ON for active journey
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
            _statusColor = AppConstants.textSecondary;
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
      setState(() {
        _currentRoute = route;
        _currentStatus = 'On Route';
        _statusColor = Colors.blue;
        _isTracking = true; // Automatically turn ON location tracking
      });
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

    // Start location tracking (this will also update the UI state)
    _startLocationTracking();
  } catch (e) {
    _showSnackBar('Failed to start journey: $e', AppConstants.errorColor);
    if (mounted) {
      setState(() {
        _currentRoute = null;
        _currentStatus = 'Start Duty';
        _statusColor = Colors.green;
        _isTracking = false;
      });
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
        // Update location regardless of accuracy for continuous tracking
        // Only skip if accuracy is extremely poor (>200m)
        if (position.accuracy <= 200) {
          // Use unawaited to prevent blocking the stream
          _databaseService.updateDriverLocation(
            _currentRoute?.id, // Pass null if no route
            position.latitude,
            position.longitude,
            speed: position.speed,
            heading: position.heading,
            accuracy: position.accuracy,
          ).catchError((error) {
            debugPrint('Location update error: $error');
            // Don't stop tracking for individual update failures
          });
          debugPrint(
              'Location updated: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
        } else {
          debugPrint('Location accuracy too poor: ${position.accuracy}m, skipping update');
        }
      }, onError: (error) {
        debugPrint('Location stream error: $error');
        
        // Only show error to user if it's a critical error
        if (error.toString().contains('permission') || 
            error.toString().contains('service')) {
          _showSnackBar('Location error: $error', AppConstants.errorColor);
          if (mounted) {
            setState(() => _isTracking = false);
          }
        } else {
          // For network errors, try to continue tracking
          debugPrint('Network error, continuing location tracking...');
          // Attempt to restart location tracking
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted && _isTracking) {
              _startLocationTracking();
            }
          });
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

  Future<void> _stopLocationTracking() async {
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
    // Stop location tracking first
    await _stopLocationTracking();
    
    // End the journey in database
    await _databaseService.endJourney();
    
    if (mounted) {
      setState(() {
        _currentRoute = null;
        _activeJourney = null;
        _currentStatus = 'Off Duty';
        _statusColor = AppConstants.textSecondary;
        _isTracking = false; // Automatically turn OFF location tracking
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
                     _activeJourney != null ||
                     _currentRoute != null;
    
    // If trying to turn OFF location sharing while on duty, show restriction dialog
    if (isOnDuty && _isTracking) {
      _showLocationSharingRestrictionDialog();
      return;
    }
    
    if (_isTracking) {
      _stopLocationTracking();
      _showSnackBar('Location sharing stopped', AppConstants.textSecondary);
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

  // Monitor Firebase connection status and send heartbeat
  void _startConnectionMonitoring() {
    // Check connection status every 30 seconds
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      _checkConnectionStatus();
    });

    // Send heartbeat every 15 seconds when tracking
    Timer.periodic(const Duration(seconds: 15), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_isTracking) {
        _databaseService.sendHeartbeat().catchError((error) {
          debugPrint('Heartbeat error: $error');
        });
      }
    });
  }

  Future<void> _checkConnectionStatus() async {
    try {
      // Test Firebase connection with a simple write operation
      final testData = {'test': 'connection', 'timestamp': ServerValue.timestamp};
      await _databaseService.realtimeDb.ref('connection_test').set(testData).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Connection timeout'),
      );
      
      // Clean up test data
      await _databaseService.realtimeDb.ref('connection_test').remove();
      
      if (mounted && !_isConnected) {
        setState(() => _isConnected = true);
        debugPrint('Firebase connection restored');
      }
    } catch (e) {
      if (mounted && _isConnected) {
        setState(() => _isConnected = false);
        debugPrint('Firebase connection lost: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppConstants.backgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
                strokeWidth: 3,
              ),
              const SizedBox(height: AppConstants.spacingL),
              Text(
                'Loading Dashboard...',
                style: TextStyle(
                  fontSize: 16,
                  color: AppConstants.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Dashboard',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppConstants.textOnPrimary,
          ),
        ),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: AppConstants.textOnPrimary,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            tooltip: 'View Map',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            tooltip: 'Profile',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: AppConstants.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Welcome Header
              FadeInWidget(
                delay: const Duration(milliseconds: 100),
                child: _buildWelcomeHeader(),
              ),
              
              // Status Card
              FadeInWidget(
                delay: const Duration(milliseconds: 200),
                child: _buildStatusCard(),
              ),
              
              // Connection Status
              FadeInWidget(
                delay: const Duration(milliseconds: 300),
                child: _buildConnectionStatus(),
              ),
              
              // Location Sharing Card
              FadeInWidget(
                delay: const Duration(milliseconds: 400),
                child: _buildLocationSharingCard(),
              ),
              
              // Current Route Card
              if (_currentRoute != null || _activeJourney != null)
                FadeInWidget(
                  delay: const Duration(milliseconds: 500),
                  child: _buildCurrentRouteCard(),
                ),
              
              // Status Actions
              FadeInWidget(
                delay: const Duration(milliseconds: 600),
                child: _buildStatusActions(),
              ),
              
              // Quick Actions
              FadeInWidget(
                delay: const Duration(milliseconds: 700),
                child: _buildQuickActions(),
              ),
              
              const SizedBox(height: AppConstants.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    return GradientCard(
      gradientColors: AppConstants.primaryGradient,
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.textOnPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
            ),
            child: Icon(
              Icons.directions_bus,
              size: 32,
              color: AppConstants.textOnPrimary,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConstants.textOnPrimary.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXS),
                Text(
                  _driverData?['name'] ?? 'Driver',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                    color: AppConstants.textOnPrimary,
                  ),
                ),
                if (_driverData?['busNumber'] != null) ...[
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    'Bus: ${_driverData!['busNumber']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.textOnPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    final isActive = _currentStatus == 'On Route' || _currentStatus == 'Start Duty';
    
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Row(
              children: [
              isActive 
                ? PulseWidget(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  )
                : Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              const SizedBox(width: AppConstants.spacingS),
                Text(
                'Current Status',
                  style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppConstants.textColor,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppConstants.spacingM),
            Container(
              width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
              color: _statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: _statusColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              _currentStatus,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _statusColor,
              ),
              textAlign: TextAlign.center,
            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildConnectionStatus() {
    return ModernCard(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingS),
            decoration: BoxDecoration(
              color: _isConnected 
                  ? AppConstants.successColor.withValues(alpha: 0.1)
                  : AppConstants.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(
              _isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: _isConnected ? AppConstants.successColor : AppConstants.errorColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isConnected ? 'Connected' : 'Connection Issues',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isConnected ? AppConstants.successColor : AppConstants.errorColor,
                  ),
                ),
                Text(
                  _isConnected ? 'Firebase Realtime Database' : 'Check your internet connection',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSharingCard() {
    final isLocked = (_activeJourney != null || 
                     _currentStatus == 'On Route' || 
                     _currentStatus == 'Start Duty' ||
                     _currentRoute != null) && _isTracking;

    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: _isTracking 
                      ? AppConstants.successColor.withValues(alpha: 0.1)
                      : AppConstants.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                        _isTracking ? Icons.location_on : Icons.location_off,
                  color: _isTracking ? AppConstants.successColor : AppConstants.textSecondary,
                  size: 20,
                      ),
              ),
              const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Live Location Sharing',
                              style: TextStyle(
                                fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.textColor,
                              ),
                            ),
                            Text(
                              _isTracking
                          ? 'Sharing with passengers'
                          : 'Location sharing disabled',
                              style: TextStyle(
                                fontSize: 14,
                        color: AppConstants.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isTracking,
                onChanged: isLocked ? null : (value) => _toggleLocationSharing(),
                activeThumbColor: AppConstants.successColor,
                inactiveThumbColor: AppConstants.textSecondary,
                inactiveTrackColor: AppConstants.textSecondary.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                   if (_isTracking) ...[
          const SizedBox(height: AppConstants.spacingM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.successColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: AppConstants.successColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppConstants.successColor,
                      size: 16,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded( // Wrap with Expanded
                      child: Text(
                        'Location data is being sent to Firebase for passenger tracking',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppConstants.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Row(
                  children: [
                    Icon(
                      Icons.update,
                      color: AppConstants.successColor,
                      size: 14,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded( // Wrap with Expanded
                      child: Text(
                        'Updates every 30 seconds or 5 meters movement',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppConstants.successColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        
        if (isLocked) ...[
          const SizedBox(height: AppConstants.spacingM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(
                color: AppConstants.warningColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lock,
                  color: AppConstants.warningColor,
                  size: 16,
                ),
                const SizedBox(width: AppConstants.spacingS),
                Expanded( // Wrap with Expanded
                  child: Text(
                    'Location sharing is locked during active trip',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppConstants.warningColor,
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
  );
  }
  
  Widget _buildCurrentRouteCard() {
    return GradientCard(
      gradientColors: AppConstants.infoColor.withValues(alpha: 0.1) == AppConstants.infoColor.withValues(alpha: 0.1) 
          ? [AppConstants.infoColor.withValues(alpha: 0.1), AppConstants.infoColor.withValues(alpha: 0.05)]
          : AppConstants.primaryGradient,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: AppConstants.infoColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  Icons.route,
                  color: AppConstants.infoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Route',
                          style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                            color: AppConstants.textColor,
                      ),
                    ),
                      Text(
                        _activeJourney?['routeName'] ?? _currentRoute?.name ?? '',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.infoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_currentRoute?.startPoint ?? 'Start'} → ${_currentRoute?.endPoint ?? 'End'}',
                  style: TextStyle(
                          fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.textColor,
                        ),
                      ),
                const SizedBox(height: AppConstants.spacingS),
                      Text(
                        'Bus: ${_driverData?['busNumber'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConstants.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MapScreen()),
                          );
                        },
              icon: const Icon(Icons.map_outlined),
              label: const Text('View Live Route'),
                        style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.infoColor,
                foregroundColor: AppConstants.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  Icons.work_outline,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Text(
                'Change Status',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          _buildStatusGrid(),
        ],
      ),
    );
  }

Widget _buildStatusGrid() {
  final availableStatuses = _getAvailableStatuses();
  final itemCount = availableStatuses.length;
  final crossAxisCount = itemCount > 2 ? 2 : itemCount;
  final rowCount = (itemCount / crossAxisCount).ceil();
  final itemHeight = 100.0; // Approximate height of each item
  
  return Container(
    height: (rowCount * itemHeight) + ((rowCount - 1) * AppConstants.spacingM),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppConstants.spacingM,
        mainAxisSpacing: AppConstants.spacingM,
        childAspectRatio: 2.2,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        final status = availableStatuses[index];
        return _buildStatusButton(status);
      },
    ),
  );
}

  List<Map<String, dynamic>> _getAvailableStatuses() {
    final statuses = <Map<String, dynamic>>[];
    
    if (_currentStatus != 'Start Duty' && _currentStatus != 'On Route') {
      statuses.add({
        'label': 'Start Duty',
        'color': AppConstants.successColor,
        'icon': Icons.play_arrow,
        'description': 'Begin your shift',
      });
    }
    
    if (_currentStatus == 'Start Duty' || _currentStatus == 'Break') {
      statuses.add({
        'label': 'On Route',
        'color': AppConstants.infoColor,
        'icon': Icons.directions_bus,
        'description': 'Start driving',
      });
    }
    
    if (_currentStatus == 'On Route') {
      statuses.add({
        'label': 'Break',
        'color': AppConstants.warningColor,
        'icon': Icons.pause,
        'description': 'Take a break',
      });
    }
    
    if (_currentStatus == 'On Route' || _currentStatus == 'Break') {
      statuses.add({
        'label': 'End Duty',
        'color': AppConstants.errorColor,
        'icon': Icons.stop,
        'description': 'Finish shift',
      });
    }
    
    return statuses;
  }
Widget _buildStatusButton(Map<String, dynamic> status) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _changeStatus(status['label']),
      borderRadius: BorderRadius.circular(AppConstants.radiusM),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingS, horizontal: AppConstants.spacingM),
        decoration: BoxDecoration(
          color: status['color'].withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppConstants.radiusM),
          border: Border.all(
            color: status['color'].withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status['icon'],
              color: status['color'],
              size: 20,
            ),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status['label'],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: status['color'],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    status['description'],
                    style: TextStyle(
                      fontSize: 10,
                      color: status['color'].withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildQuickActions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
              children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showIssueDialog,
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Report Issue'),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                    foregroundColor: AppConstants.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _triggerSOS,
                  icon: const Icon(Icons.emergency),
                  label: const Text('SOS'),
                  style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.errorColor,
                    foregroundColor: AppConstants.textOnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                ),
                ),
              ],
            ),
          ],
      ),
    );
  }

}
