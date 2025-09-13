import 'package:flutter/material.dart';
import 'package:busmitra_driver/utils/constants.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final Color backgroundColor;
  final Color textColor;
  final double elevation;
  final bool isGlassEffect;
  final Gradient? gradient;
  final double borderRadius;
  final double? width;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.backgroundColor = AppConstants.primaryColor,
    this.textColor = AppConstants.accentColor,
    this.elevation = 4,
    this.isGlassEffect = false,
    this.gradient,
    this.borderRadius = 12,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width ?? double.infinity,
      height: 50,
      decoration: isGlassEffect
          ? _glassDecoration()
          : _regularDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: textColor,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _regularDecoration() {
    return BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: elevation,
          offset: Offset(0, elevation / 2),
        ),
      ],
    );
  }

  BoxDecoration _glassDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.3),
        width: 1.0,
      ),
      gradient: gradient ?? LinearGradient(
        colors: [
          backgroundColor.withValues(alpha: 0.8),
          backgroundColor.withValues(alpha: 0.6),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.1),
          blurRadius: 10,
          spreadRadius: 1,
          offset: const Offset(0, 2),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}