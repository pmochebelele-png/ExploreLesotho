import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final List<String> allowedRoles;

  const ProtectedRoute({
    super.key,
    required this.child,
    this.allowedRoles = const [],
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (!authProvider.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(
        body: Center(child: Text('Please login to continue')),
      );
    }

    if (allowedRoles.isNotEmpty &&
        !allowedRoles.contains(authProvider.user?.role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/unauthorized');
      });
      return const Scaffold(
        body: Center(child: Text('Unauthorized access')),
      );
    }

    return child;
  }
}
