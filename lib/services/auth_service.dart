// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/audit_log_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user data from Firestore
  // lib/services/auth_service.dart - update getCurrentUserData method
  Future<AppUser?> getCurrentUserData() async {
    final User? user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return AppUser.fromFirestore(doc.data()!, user.uid);
      } else {
        // User document doesn't exist - this shouldn't happen
        print('User document not found for UID: ${user.uid}');
        return null;
      }
    } catch (e) {
      print('Error loading user data: $e');
      return null;
    }
  }

  // SIGN IN (with audit logging)
  Future<AppUser?> signInWithEmailPassword(
    String email,
    String password,
    String ipAddress,
  ) async {
    try {
      // Check if account is locked (too many attempts - handled by Firestore rules)
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception('Sign-in failed');

      // Get user data from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      if (!userDoc.exists) throw Exception('User profile not found');

      final appUser = AppUser.fromFirestore(userDoc.data()!, firebaseUser.uid);

      // Check account status
      if (appUser.status == AccountStatus.suspended) {
        await _auth.signOut();
        throw Exception('Account suspended. Contact administrator.');
      }

      // Update last login timestamp
      await _firestore.collection('users').doc(firebaseUser.uid).update({
        'lastLogin': DateTime.now().toIso8601String(),
      });

      // Log the login (FR12)
      await _logAuditEvent(
        userId: firebaseUser.uid,
        userEmail: email,
        action: 'LOGIN_SUCCESS',
        ipAddress: ipAddress,
        details: 'Role: ${appUser.role.toString().split('.').last}',
      );

      return appUser;
    } on FirebaseAuthException catch (e) {
      await _logAuditEvent(
        userId: 'unknown',
        userEmail: email,
        action: 'LOGIN_FAILED',
        ipAddress: ipAddress,
        details: 'Error: ${e.code}',
      );
      throw _getFirebaseErrorMessage(e);
    }
  }

  // REGISTER NEW USER (Admin only in production)
  Future<AppUser?> registerUser({
    required String email,
    required String password,
    required String displayName,
    required UserRole role,
    required String facilityId,
    required String facilityName,
    required bool consentGiven,
    String? phoneNumber,
    required String adminUid, // Only admins can register
  }) async {
    try {
      // Verify the caller is an admin
      final adminDoc = await _firestore.collection('users').doc(adminUid).get();
      final adminUser = AppUser.fromFirestore(adminDoc.data()!, adminUid);
      if (adminUser.role != UserRole.admin) {
        throw Exception('Only administrators can create new users');
      }

      // Create Firebase Auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final User? firebaseUser = userCredential.user;
      if (firebaseUser == null) throw Exception('User creation failed');

      // Set display name
      await firebaseUser.updateDisplayName(displayName);

      // Set default permissions based on role
      final permissions = _getPermissionsForRole(role);

      // Create user document in Firestore
      final appUser = AppUser(
        uid: firebaseUser.uid,
        email: email,
        displayName: displayName,
        role: role,
        facilityId: facilityId,
        facilityName: facilityName,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        consentGiven: consentGiven,
        phoneNumber: phoneNumber,
        permissions: permissions,
      );

      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(appUser.toFirestore());

      await _logAuditEvent(
        userId: adminUid,
        userEmail: adminUser.email,
        action: 'USER_REGISTERED',
        ipAddress: 'system',
        details:
            'Created user: $email with role: ${role.toString().split('.').last}',
      );

      return appUser;
    } on FirebaseAuthException catch (e) {
      throw _getFirebaseErrorMessage(e);
    }
  }

  // FORGOT PASSWORD
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      await _logAuditEvent(
        userId: 'unknown',
        userEmail: email,
        action: 'PASSWORD_RESET_REQUESTED',
        ipAddress: 'system',
        details: 'Reset email sent',
      );
    } on FirebaseAuthException catch (e) {
      throw _getFirebaseErrorMessage(e);
    }
  }

  // SIGN OUT
  Future<void> signOut(
    String userId,
    String userEmail,
    String ipAddress,
  ) async {
    await _logAuditEvent(
      userId: userId,
      userEmail: userEmail,
      action: 'LOGOUT',
      ipAddress: ipAddress,
    );
    await _auth.signOut();
  }

  // DELETE USER (Admin only, with consent withdrawal per DP Act)
  Future<void> deleteUser(String userIdToDelete, String adminUid) async {
    // Verify admin
    final adminDoc = await _firestore.collection('users').doc(adminUid).get();
    final adminUser = AppUser.fromFirestore(adminDoc.data()!, adminUid);
    if (adminUser.role != UserRole.admin) {
      throw Exception('Only administrators can delete users');
    }

    // In production, consider soft-delete for compliance
    await _firestore.collection('users').doc(userIdToDelete).update({
      'status': 'suspended', // Soft delete per DP Act
      'deletedAt': DateTime.now().toIso8601String(),
      'deletedBy': adminUid,
    });

    // Note: Firebase Auth user might be disabled but kept for audit
  }

  // Helper: Role-based permissions (FR13)
  List<String> _getPermissionsForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return [
          Permissions.manageUsers,
          Permissions.viewAuditLogs,
          Permissions.generateReports,
          Permissions.registerPatient,
          Permissions.viewMedicalRecord,
        ];
      case UserRole.physician:
        return [
          Permissions.viewMedicalRecord,
          Permissions.editMedicalRecord,
          Permissions.orderLabs,
          Permissions.prescribeMeds,
          Permissions.registerPatient,
        ];
      case UserRole.nurse:
        return [
          Permissions.viewMedicalRecord,
          Permissions.editMedicalRecord,
          Permissions.registerPatient,
        ];
      case UserRole.clerk:
        return [
          Permissions.registerPatient,
          Permissions.viewMedicalRecord, // read-only
        ];
      case UserRole.labTech:
        return [Permissions.viewMedicalRecord, Permissions.enterResults];
      case UserRole.pharmacist:
        return [Permissions.viewMedicalRecord, Permissions.dispenseMeds];
      case UserRole.manager:
        return [
          Permissions.viewMedicalRecord,
          Permissions.generateReports,
          Permissions.viewAuditLogs,
        ];
    }
  }

  // Audit logging helper
  Future<void> _logAuditEvent({
    required String userId,
    required String userEmail,
    required String action,
    required String ipAddress,
    String? details,
  }) async {
    final log = AuditLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      userEmail: userEmail,
      action: action,
      details: details,
      ipAddress: ipAddress,
      deviceInfo: '', // Can add device info plugin
      timestamp: DateTime.now(),
    );
    await _firestore.collection('audit_logs').add(log.toFirestore());
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password should be at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return 'Authentication error: ${e.code}';
    }
  }
}
