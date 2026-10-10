import 'package:flutter/material.dart';
import '../platform/app_platform.dart';

/// Screen size breakpoints for Modiri AI Desktop & Mobile responsiveness.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  static const double mobileMax = 640;
  static const double tabletMax = 1024;
  static const double desktopMin = 1024;
  static const double desktopLarge = 1440;
}

class ResponsiveLayout {
  ResponsiveLayout._();

  static bool isDesktopPlatform() => AppPlatform.isDesktop;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.mobileMax;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= ResponsiveBreakpoints.mobileMax && width < ResponsiveBreakpoints.desktopMin;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktopMin;
  }

  static bool isWideDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.desktopLarge;
  }

  static T value<T>(BuildContext context, {
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  static EdgeInsets contentPadding(BuildContext context) {
    if (isWideDesktop(context)) return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    if (isDesktop(context)) return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    if (isTablet(context)) return const EdgeInsets.symmetric(horizontal: 20, vertical: 16);
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }
}

/// A builder widget that renders a different widget based on viewport width.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (ResponsiveLayout.isDesktop(context)) {
          return desktop(context);
        }
        if (ResponsiveLayout.isTablet(context) && tablet != null) {
          return tablet!(context);
        }
        return mobile(context);
      },
    );
  }
}