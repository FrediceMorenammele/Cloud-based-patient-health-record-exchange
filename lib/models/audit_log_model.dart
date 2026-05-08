// lib/models/audit_log_model.dart
class AuditLog {
  final String id;
  final String userId;
  final String userEmail;
  final String action; // e.g., 'LOGIN', 'LOGOUT', 'REGISTER', 'PASSWORD_RESET'
  final String? details;
  final String ipAddress;
  final String? deviceInfo;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.action,
    this.details,
    required this.ipAddress,
    this.deviceInfo,
    required this.timestamp,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'action': action,
      'details': details,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
