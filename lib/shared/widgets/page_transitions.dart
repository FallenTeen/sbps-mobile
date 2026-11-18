import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Standard page transition for GoRouter:
/// Subtle horizontal slide + smooth fade-in.
/// Optimized for 60fps performance on low-to-mid tier devices (~250ms).
CustomTransitionPage<T> buildAppTransitionPage<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 250),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) {
        return child;
      }
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.06, 0),
        end: Offset.zero,
      ).animate(curvedAnimation);

      final fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(curvedAnimation);

      return SlideTransition(
        position: slideAnimation,
        child: FadeTransition(opacity: fadeAnimation, child: child),
      );
    },
  );
}

/// Fade + subtle scale for peer/sibling destinations (bottom-nav branches).
/// Unlike [buildAppTransitionPage] there is no horizontal slide: switching
/// tabs should feel like cross-fading content, not drilling into a new screen.
CustomTransitionPage<T> buildFadeThroughPage<T>({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 220),
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.of(context).disableAnimations) {
        return child;
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Helper PageRoute for Navigator.of(context).push calls
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    Duration duration = const Duration(milliseconds: 250),
    super.settings,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: duration,
         reverseTransitionDuration: duration,
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           if (MediaQuery.of(context).disableAnimations) {
             return child;
           }
           final curvedAnimation = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );

           return SlideTransition(
             position: Tween<Offset>(
               begin: const Offset(0.06, 0),
               end: Offset.zero,
             ).animate(curvedAnimation),
             child: FadeTransition(
               opacity: Tween<double>(
                 begin: 0.0,
                 end: 1.0,
               ).animate(curvedAnimation),
               child: child,
             ),
           );
         },
       );
}
