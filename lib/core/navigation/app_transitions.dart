import 'package:flutter/material.dart';

enum AppTransitionStyle { fadeSlide, sharedAxisHorizontal, sharedAxisVertical }

abstract final class AppTransitions {
  static const _forwardDuration = Duration(milliseconds: 230);
  static const _reverseDuration = Duration(milliseconds: 190);

  static Route<T> route<T>({
    required Widget page,
    RouteSettings? settings,
    AppTransitionStyle style = AppTransitionStyle.fadeSlide,
    bool fullscreenDialog = false,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: _forwardDuration,
      reverseTransitionDuration: _reverseDuration,
      fullscreenDialog: fullscreenDialog,
      pageBuilder: (_, _, _) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        final fade = FadeTransition(opacity: curved, child: child);

        switch (style) {
          case AppTransitionStyle.sharedAxisHorizontal:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
                child: fade,
              ),
            );
          case AppTransitionStyle.sharedAxisVertical:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.99, end: 1).animate(curved),
                child: fade,
              ),
            );
          case AppTransitionStyle.fadeSlide:
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(curved),
              child: fade,
            );
        }
      },
    );
  }

  static Future<T?> showDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x73000000),
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss dialog',
      barrierColor: barrierColor,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, _) => builder(context),
      transitionBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
