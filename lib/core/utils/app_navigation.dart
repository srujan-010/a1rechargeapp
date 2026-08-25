import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_names.dart';

/// Centralized navigation helper for safe pop operations across A1 Recharge.
class AppNavigation {
  /// Safely pops the current screen if a previous route exists in the navigation stack.
  /// If [context.canPop()] is false (e.g. root route, direct deep-link, web tab root),
  /// safely navigates to [fallbackRoute] (default: [RouteNames.dashboard]).
  static void pop(BuildContext context, {String fallbackRoute = RouteNames.dashboard}) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(fallbackRoute);
    }
  }
}
