// lib/screens/role_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:nhre/screens/dashboards/admin_dashboard.dart';
import 'package:nhre/screens/dashboards/clerk_dashboard.dart';
import 'package:nhre/screens/dashboards/lab_dashboard.dart';
import 'package:nhre/screens/dashboards/manager_reports.dart';
import 'package:nhre/screens/dashboards/nurse_dashboard.dart';
import 'package:nhre/screens/dashboards/pharmacy_dashboard.dart';
import 'package:nhre/screens/dashboards/physician_dashboard.dart';
import 'package:nhre/widgets/app_drawer.dart';
import '../models/user_model.dart';

class RoleSelectionScreen extends StatelessWidget {
  final AppUser user;
  const RoleSelectionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    // Route based on role
    Widget destination;
    switch (user.role) {
      case UserRole.admin:
        destination = const AdminDashboardScreen();
        break;
      case UserRole.physician:
      // Update the physician case in role_selection_screen.dart
      case UserRole.physician:
        destination = PhysicianDashboardScreen(user: user);
        break;
        break;
      case UserRole.nurse:
        destination = const NurseDashboardScreen();
        break;
      case UserRole.clerk:
        destination = const ClerkDashboardScreen();
        break;
      case UserRole.labTech:
        destination = const LabDashboardScreen();
        break;
      case UserRole.pharmacist:
        destination = const PharmacyDashboardScreen();
        break;
      case UserRole.manager:
        destination = const ManagerReportsScreen();
        break;
    }

    return Scaffold(
      drawer: AppDrawer(user: user),
      body: destination,
    );
  }
}
