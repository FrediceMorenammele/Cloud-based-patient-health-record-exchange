// lib/utils/create_admin.dart
// Run this once to create your first admin user
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> createFirstAdmin() async {
  try {
    // Create auth user
    final userCredential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: 'admin@lesothoehr.gov.ls',
          password: 'Admin123!', // Change immediately after first login
        );

    // Create admin document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userCredential.user!.uid)
        .set({
          'uid': userCredential.user!.uid,
          'email': 'admin@lesothoehr.gov.ls',
          'displayName': 'System Administrator',
          'role': 'admin',
          'facilityId': 'MOH_CENTRAL',
          'facilityName': 'Ministry of Health',
          'status': 'active',
          'createdAt': DateTime.now().toIso8601String(),
          'lastLogin': DateTime.now().toIso8601String(),
          'consentGiven': true,
          'permissions': [
            'manage_users',
            'view_audit_logs',
            'generate_reports',
          ],
        });

    print('Admin user created successfully!');
  } catch (e) {
    print('Error: $e');
  }
}
