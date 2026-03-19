import 'package:flutter/material.dart';

/// Responsive design utilities for adaptive UI
class Responsive {
  Responsive._();

  /// Screen size breakpoints
  static const double mobile = 480;
  static const double tablet = 768;
  static const double desktop = 1024;

  /// Get current screen size type
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < mobile) return ScreenType.mobile;
    if (width < tablet) return ScreenType.mobileLarge;
    if (width < desktop) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) {
    final type = getScreenType(context);
    return type == ScreenType.mobile || type == ScreenType.mobileLarge;
  }

  /// Check if current screen is tablet
  static bool isTablet(BuildContext context) {
    return getScreenType(context) == ScreenType.tablet;
  }

  /// Check if current screen is desktop
  static bool isDesktop(BuildContext context) {
    return getScreenType(context) == ScreenType.desktop;
  }

  /// Get responsive value based on screen size
  /// Returns mobile value by default, tablet/desktop if applicable
  static T getValue<T>({
    required BuildContext context,
    required T mobile,
    T? mobileLarge,
    T? tablet,
    T? desktop,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobileLarge ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobileLarge ?? mobile;
      case ScreenType.mobileLarge:
        return mobileLarge ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }

  /// Scale font size based on screen width
  /// Base is designed for mobile (360px width)
  static double scaleFontSize(BuildContext context, double fontSize) {
    final width = MediaQuery.sizeOf(context).width;
    final scaleFactor = width / 360;
    // Clamp scale factor to avoid too large/small fonts
    final clampedScale = scaleFactor.clamp(0.8, 1.3);
    return fontSize * clampedScale;
  }

  /// Get responsive padding
  static EdgeInsets getPadding(BuildContext context) {
    if (isDesktop(context)) {
      return const EdgeInsets.symmetric(horizontal: 48, vertical: 32);
    } else if (isTablet(context)) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    } else {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context) {
    return getValue(
      context: context,
      mobile: 12,
      tablet: 16,
      desktop: 16,
    );
  }

  /// Get responsive spacing
  static double getSpacing(BuildContext context, double multiplier) {
    final baseSpacing = getValue(
      context: context,
      mobile: 8.0,
      tablet: 12.0,
      desktop: 16.0,
    );
    return baseSpacing * multiplier;
  }
}

/// Screen size types
enum ScreenType {
  mobile,
  mobileLarge,
  tablet,
  desktop,
}

/// Extension on BuildContext for easy access to responsive utilities
extension ResponsiveContext on BuildContext {
  ScreenType get screenType => Responsive.getScreenType(this);
  bool get isMobile => Responsive.isMobile(this);
  bool get isTablet => Responsive.isTablet(this);
  bool get isDesktop => Responsive.isDesktop(this);

  /// Get screen size
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Get screen width
  double get screenWidth => screenSize.width;

  /// Get screen height
  double get screenHeight => screenSize.height;

  /// Get bottom padding (for navigation bar, etc.)
  double get bottomPadding => MediaQuery.paddingOf(this).bottom;

  /// Get top padding (for status bar, notch, etc.)
  double get topPadding => MediaQuery.paddingOf(this).top;

  /// Check if keyboard is visible
  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;

  /// Get keyboard height
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;
}

/// Responsive builder widget
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.mobileLarge,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? mobileLarge;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    final screenType = context.screenType;

    switch (screenType) {
      case ScreenType.desktop:
        return desktop?.call(context) ??
            tablet?.call(context) ??
            mobileLarge?.call(context) ??
            mobile(context);
      case ScreenType.tablet:
        return tablet?.call(context) ?? mobileLarge?.call(context) ?? mobile(context);
      case ScreenType.mobileLarge:
        return mobileLarge?.call(context) ?? mobile(context);
      case ScreenType.mobile:
        return mobile(context);
    }
  }
}

/// Responsive padding widget
class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({
    super.key,
    required this.child,
    this.horizontal,
    this.vertical,
  });

  final Widget child;
  final double? horizontal;
  final double? vertical;

  @override
  Widget build(BuildContext context) {
    final defaultPadding = Responsive.getPadding(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal ?? defaultPadding.left,
        vertical: vertical ?? defaultPadding.top,
      ),
      child: child,
    );
  }
}

/// Responsive container with max width
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final double? maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final constrainedMaxWidth = maxWidth ??
        Responsive.getValue<double?>(
          context: context,
          mobile: double.infinity,
          tablet: 800,
          desktop: 1200,
        ) ?? double.infinity;

    return Container(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constrainedMaxWidth),
        child: child,
      ),
    );
  }
}
