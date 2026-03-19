import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// A glassmorphic container with blur effect and subtle border
class GlassmorphicContainer extends StatelessWidget {
  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.borderRadius = 16,
    this.blurAmount = 10,
    this.opacity = 0.1,
    this.borderOpacity = 0.2,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blurAmount;
  final double opacity;
  final double borderOpacity;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.glassBackground.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: AppColors.glassBorder.withValues(alpha: borderOpacity),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glassmorphic card variant with pre-defined styling
class GlassmorphicCard extends StatelessWidget {
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderRadius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final card = GlassmorphicContainer(
      padding: padding,
      margin: margin,
      borderRadius: borderRadius,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: card,
        ),
      );
    }

    return card;
  }
}

/// A glassmorphic button with the accent color
class GlassmorphicButton extends StatelessWidget {
  const GlassmorphicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isSecondary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isSecondary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: GlassmorphicContainer(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        borderRadius: 12,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isSecondary
              ? [
                  AppColors.accentSecondary.withValues(alpha: 0.2),
                  AppColors.accentSecondary.withValues(alpha: 0.1),
                ]
              : [
                  AppColors.accentPrimary.withValues(alpha: 0.2),
                  AppColors.accentPrimary.withValues(alpha: 0.1),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isSecondary ? AppColors.accentSecondary : AppColors.accentPrimary,
                  ),
                ),
              )
            else if (icon != null)
              Icon(
                icon,
                color: isSecondary ? AppColors.accentSecondary : AppColors.accentPrimary,
                size: 18,
              ),
            if (icon != null || isLoading) const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSecondary ? AppColors.accentSecondary : AppColors.accentPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
