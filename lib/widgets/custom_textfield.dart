import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool obscureText;
  final Color iconColor;
  final Widget? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final bool glassEffect;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.obscureText = false,
    this.iconColor = AppConstants.primaryColor,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.glassEffect = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        color: glassEffect ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: glassEffect ? Colors.white70 : Colors.grey,
        ),
        prefixIcon: Icon(prefixIcon, color: iconColor),
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: suffixIcon!,
                onPressed: onSuffixIconPressed,
                color: iconColor.withValues(alpha: 0.6),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: glassEffect ? Colors.white.withValues(alpha: 0.3) : AppConstants.textSecondary,
            width: glassEffect ? 1.0 : 1.5,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: glassEffect ? Colors.white.withValues(alpha: 0.3) : AppConstants.textSecondary,
            width: glassEffect ? 1.0 : 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: glassEffect ? Colors.white.withValues(alpha: 0.5) : AppConstants.primaryColor,
            width: glassEffect ? 1.5 : 2,
          ),
        ),
        filled: true,
        fillColor: glassEffect ? Colors.white.withValues(alpha: 0.1) : AppConstants.accentColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }
}