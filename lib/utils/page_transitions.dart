import 'package:flutter/material.dart';

/// Custom page route with slide and fade animations
class SlideFadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;
  final Offset beginOffset;
  final Duration duration;

  SlideFadePageRoute({
    required this.child,
    this.beginOffset = const Offset(1.0, 0.0), // Slide from right by default
    this.duration = const Duration(milliseconds: 400),
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: duration,
          reverseTransitionDuration: duration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide transition
            final slideAnimation = Tween<Offset>(
              begin: beginOffset,
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
            );

            // Fade transition
            final fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(
              CurvedAnimation(
                parent: animation,
                curve: Interval(0.0, 0.8, curve: Curves.easeIn),
              ),
            );

            return SlideTransition(
              position: slideAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
        );
}

/// Helper function to create animated page route
PageRoute<T> createAnimatedRoute<T>(Widget page, {Offset? beginOffset}) {
  return SlideFadePageRoute<T>(
    child: page,
    beginOffset: beginOffset ?? const Offset(1.0, 0.0),
  );
}
