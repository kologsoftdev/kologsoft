import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'Datafeed.dart';
import 'routes.dart';

class RouteGuard extends StatelessWidget {
  final Widget child;
  final bool requiresAuth;
  final List<String>? allowedAccessLevels;

  const RouteGuard({
    Key? key,
    required this.child,
    this.requiresAuth = true,
    this.allowedAccessLevels,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAuth(context),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data == true) {
          return child;
        }

        // Not authenticated or not authorized, redirect to login
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacementNamed(context, Routes.login);
        });

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }

  Future<bool> _checkAuth(BuildContext context) async {
    if (!requiresAuth) {
      return true;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      final accessLevel = prefs.getString('accessLevel');

      // Check if user is logged in
      if (email == null || email.isEmpty) {
        return false;
      }

      // Load user data into Datafeed if not already loaded
      final datafeed = context.read<Datafeed>();
      if (datafeed.staff.isEmpty) {
        await datafeed.getdata();
      }

      // Check access level if specified
      if (allowedAccessLevels != null && allowedAccessLevels!.isNotEmpty) {
        if (accessLevel == null ||
            !allowedAccessLevels!.contains(accessLevel)) {
          // User doesn't have required access level
          _showAccessDenied(context);
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Auth check error: $e');
      return false;
    }
  }

  void _showAccessDenied(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access Denied: You do not have permission to view this page',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pushReplacementNamed(context, Routes.home);
    });
  }
}
