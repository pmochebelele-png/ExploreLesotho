import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/dev_auth_provider.dart';

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<DevAuthProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRoleButton(
            'Admin',
            auth.isAdmin,
            Colors.purple,
            auth.switchToAdmin,
          ),
          _buildRoleButton(
            'Vendor',
            auth.isVendor,
            Colors.blue,
            auth.switchToVendor,
          ),
          _buildRoleButton(
            'Tourist',
            auth.isTourist,
            Colors.green,
            auth.switchToTourist,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleButton(
    String role,
    bool isActive,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          role,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
