// lib/models/user_model.dart
enum UserRole {
  physician, // Doctors/Clinicians
  nurse, // Nurses/Midwives
  clerk, // Registration Clerks
  labTech, // Laboratory Technicians
  pharmacist, // Pharmacists
  manager, // Clinic Managers
  admin, // IT Administrators
}

enum AccountStatus { active, suspended, needsPasswordReset }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String facilityId; // Which clinic/hospital
  final String facilityName;
  final AccountStatus status;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool consentGiven; // Required by Lesotho DP Act
  final String? phoneNumber;
  final List<String> permissions;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.facilityId,
    required this.facilityName,
    required this.status,
    required this.createdAt,
    required this.lastLogin,
    required this.consentGiven,
    this.phoneNumber,
    required this.permissions,
  });

  // Check if user can perform an action
  bool hasPermission(String permission) => permissions.contains(permission);

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.toString().split('.').last,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'status': status.toString().split('.').last,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'consentGiven': consentGiven,
      'phoneNumber': phoneNumber,
      'permissions': permissions,
    };
  }

  factory AppUser.fromFirestore(Map<String, dynamic> data, String uid) {
    return AppUser(
      uid: uid,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: _stringToRole(data['role'] ?? 'clerk'),
      facilityId: data['facilityId'] ?? '',
      facilityName: data['facilityName'] ?? '',
      status: _stringToStatus(data['status'] ?? 'active'),
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      lastLogin: DateTime.parse(
        data['lastLogin'] ?? DateTime.now().toIso8601String(),
      ),
      consentGiven: data['consentGiven'] ?? false,
      phoneNumber: data['phoneNumber'],
      permissions: List<String>.from(data['permissions'] ?? []),
    );
  }

  static UserRole _stringToRole(String role) {
    switch (role) {
      case 'physician':
        return UserRole.physician;
      case 'nurse':
        return UserRole.nurse;
      case 'clerk':
        return UserRole.clerk;
      case 'labTech':
        return UserRole.labTech;
      case 'pharmacist':
        return UserRole.pharmacist;
      case 'manager':
        return UserRole.manager;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.clerk;
    }
  }

  static AccountStatus _stringToStatus(String status) {
    switch (status) {
      case 'active':
        return AccountStatus.active;
      case 'suspended':
        return AccountStatus.suspended;
      case 'needsPasswordReset':
        return AccountStatus.needsPasswordReset;
      default:
        return AccountStatus.active;
    }
  }
}

// Permission constants
class Permissions {
  static const String registerPatient = 'register_patient';
  static const String viewMedicalRecord = 'view_medical_record';
  static const String editMedicalRecord = 'edit_medical_record';
  static const String orderLabs = 'order_labs';
  static const String enterResults = 'enter_results';
  static const String prescribeMeds = 'prescribe_meds';
  static const String dispenseMeds = 'dispense_meds';
  static const String generateReports = 'generate_reports';
  static const String manageUsers = 'manage_users';
  static const String viewAuditLogs = 'view_audit_logs';
}
