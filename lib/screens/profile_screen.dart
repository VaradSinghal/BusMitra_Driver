import 'package:busmitra_driver/models/route_model.dart';
import 'package:busmitra_driver/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';
import 'package:busmitra_driver/services/auth_service.dart';
import 'package:busmitra_driver/widgets/modern_card.dart';
import 'package:busmitra_driver/widgets/animated_widgets.dart';


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

  Future<void> _loadDriverData() async {
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
      backgroundColor: AppConstants.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
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
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadDriverData,
              color: AppConstants.primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Profile Header
                    FadeInWidget(
                      delay: const Duration(milliseconds: 100),
                      child: _buildProfileHeader(),
                    ),
                    
                    // Driver Information
                    FadeInWidget(
                      delay: const Duration(milliseconds: 200),
                      child: _buildDriverInfo(),
                    ),
                    
                    // Assigned Route
                    FadeInWidget(
                      delay: const Duration(milliseconds: 300),
                      child: _buildAssignedRoute(),
                    ),
                    
                    // Statistics
                    FadeInWidget(
                      delay: const Duration(milliseconds: 400),
                      child: _buildStatistics(),
                    ),
                    
                    // Actions
                    FadeInWidget(
                      delay: const Duration(milliseconds: 500),
                      child: _buildActions(),
                    ),
                    
                    const SizedBox(height: AppConstants.spacingXL),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: AppConstants.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppConstants.primaryColor),
              strokeWidth: 3,
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              'Loading Profile...',
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

  Widget _buildProfileHeader() {
    return GradientCard(
      gradientColors: AppConstants.primaryGradient,
      margin: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        children: [
          // Profile Picture
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppConstants.textOnPrimary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundColor: AppConstants.textOnPrimary.withValues(alpha: 0.2),
              child: Icon(
                Icons.person,
                size: 60,
                color: AppConstants.textOnPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
          
          // Driver Name
          Text(
            _driverData?['name'] ?? 'Unknown Driver',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppConstants.textOnPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.spacingS),
          
          // Driver ID
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingM,
              vertical: AppConstants.spacingS,
            ),
            decoration: BoxDecoration(
              color: AppConstants.textOnPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
            ),
            child: Text(
              'ID: ${_driverData?['driverId'] ?? 'No ID'}',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.textOnPrimary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfo() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: AppConstants.infoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppConstants.infoColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Text(
                'Driver Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          
          _buildInfoRow(
            'Phone Number',
            _driverData?['phone'] ?? 'Not provided',
            Icons.phone,
          ),
          _buildInfoRow(
            'Email',
            _driverData?['email'] ?? 'Not provided',
            Icons.email,
          ),
          _buildInfoRow(
            'Bus Number',
            _driverData?['busNumber'] ?? 'Not assigned',
            Icons.directions_bus,
          ),
          _buildInfoRow(
            'License Number',
            _driverData?['licenseNumber'] ?? 'Not provided',
            Icons.credit_card,
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedRoute() {
    if (_assignedRoute == null) {
      return ModernCard(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              decoration: BoxDecoration(
                color: AppConstants.warningColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 48,
                    color: AppConstants.warningColor,
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  Text(
                    'No Route Assigned',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.warningColor,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    'Contact your supervisor to get a route assigned',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppConstants.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return GradientCard(
      gradientColors: [
        AppConstants.successColor.withValues(alpha: 0.1),
        AppConstants.successColor.withValues(alpha: 0.05),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  Icons.route,
                  color: AppConstants.successColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned Route',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.textColor,
                      ),
                    ),
                    Text(
                      _assignedRoute!.name,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppConstants.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingS,
                  vertical: AppConstants.spacingXS,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.successColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppConstants.successColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppConstants.successColor,
                      size: 16,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        _assignedRoute!.startPoint,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.spacingS),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppConstants.errorColor,
                      size: 16,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        _assignedRoute!.endPoint,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          
          Row(
            children: [
              Expanded(
                child: _buildRouteStat(
                  'Distance',
                  '${_assignedRoute!.distance} km',
                  Icons.straighten,
                ),
              ),
              Expanded(
                child: _buildRouteStat(
                  'Duration',
                  '${_assignedRoute!.estimatedTime} min',
                  Icons.access_time,
                ),
              ),
              Expanded(
                child: _buildRouteStat(
                  'Stops',
                  '${_assignedRoute!.stops.length}',
                  Icons.location_city,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStat(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppConstants.successColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: AppConstants.successColor,
            size: 20,
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppConstants.textColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
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
                  Icons.analytics_outlined,
                  color: AppConstants.primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Text(
                'Statistics',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Trips Today',
                  '12',
                  Icons.directions_bus,
                  AppConstants.infoColor,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: _buildStatCard(
                  'Hours Worked',
                  '8.5',
                  Icons.access_time,
                  AppConstants.successColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Passengers',
                  '156',
                  Icons.people,
                  AppConstants.warningColor,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: _buildStatCard(
                  'Rating',
                  '4.8',
                  Icons.star,
                  AppConstants.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppConstants.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return ModernCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingS),
                decoration: BoxDecoration(
                  color: AppConstants.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusS),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: AppConstants.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Text(
                'Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppConstants.textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement edit profile
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Edit profile feature coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit Profile'),
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
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
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

  Widget _buildInfoRow(String title, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingS),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppConstants.spacingS),
            decoration: BoxDecoration(
              color: AppConstants.infoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusS),
            ),
            child: Icon(
              icon,
              color: AppConstants.infoColor,
              size: 16,
            ),
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXS),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppConstants.textColor,
                    fontWeight: FontWeight.w600,
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