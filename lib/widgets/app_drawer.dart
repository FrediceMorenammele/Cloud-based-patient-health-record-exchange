// lib/widgets/app_drawer.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/login_screen.dart';

class AppDrawer extends StatelessWidget {
  final AppUser user;
  const AppDrawer({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue.shade800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.health_and_safety,
                  size: 40,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  user.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  user.role.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  user.facilityName,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Search Patients'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to patient search
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Register Patient'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to patient registration
            },
          ),
          if (user.role == UserRole.admin || user.role == UserRole.manager)
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('User Management'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to user management
              },
            ),
          if (user.role == UserRole.admin)
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Audit Logs'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to audit logs
              },
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await authProvider.logout('system'); // Get real IP in production
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
