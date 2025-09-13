import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';
import 'package:busmitra_driver/widgets/custom_button.dart';
import 'package:busmitra_driver/widgets/custom_textfield.dart';
import 'package:busmitra_driver/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _driverIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    
    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _isLoading = true);

    final String driverId = _driverIdController.text.trim();
    final String password = _passwordController.text;

    if (driverId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your credentials'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      final bool success = await _authService.login(driverId, password);

      if (mounted) {
        if (success) {
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid credentials'),
              backgroundColor: AppConstants.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.9,
                  ),
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: AppConstants.accentColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo and App Name with animation
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
                          ),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_bus,
                                size: 50,
                                color: AppConstants.accentColor,
                              ),
                            ),
                            const SizedBox(height: 15),
                            Image.asset(
                              'assets/images/busMitra.png', 
                              height: 150, 
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Login Form with staggered animation
                      SizeTransition(
                        sizeFactor: CurvedAnimation(
                          parent: _animationController,
                          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
                        ),
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: _animationController,
                            curve: const Interval(0.4, 1.0),
                          ),
                          child: Column(
                            children: [
                              CustomTextField(
                                controller: _driverIdController,
                                hintText: 'Driver ID',
                                prefixIcon: Icons.person,
                                iconColor: AppConstants.primaryColor,
                              ),

                              const SizedBox(height: 15),

                              CustomTextField(
                                controller: _passwordController,
                                hintText: 'Password',
                                prefixIcon: Icons.lock,
                                obscureText: _obscurePassword,
                                iconColor: AppConstants.primaryColor,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: AppConstants.primaryColor.withValues(alpha: 0.6),
                                  ),
                                  onPressed: _togglePasswordVisibility,
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Navigate to forgot password screen
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: AppConstants.primaryColor),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Login Button
                              CustomButton(
                                text: 'Login',
                                onPressed: _login,
                                isLoading: _isLoading,
                                backgroundColor: AppConstants.primaryColor,
                                textColor: AppConstants.accentColor,
                              ),

                              const SizedBox(height: 20),

                              // Support Text
                              const Text(
                                'Need help? Contact Support',
                                style: TextStyle(color: AppConstants.lightTextColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}  