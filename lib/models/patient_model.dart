class Patient {
  final String id;
  final String nationalId;
  final String displayName;
  final String? dateOfBirth;
  final String? phoneNumber;
  final String? address;
  final String? emergencyContact;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String>? allergies;

  Patient({
    required this.id,
    required this.nationalId,
    required this.displayName,
    this.dateOfBirth,
    this.phoneNumber,
    this.address,
    this.emergencyContact,
    required this.createdAt,
    required this.updatedAt,
    this.allergies,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'nationalId': nationalId,
      'displayName': displayName,
      'dateOfBirth': dateOfBirth,
      'phoneNumber': phoneNumber,
      'address': address,
      'emergencyContact': emergencyContact,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'allergies': allergies,
    };
  }

  factory Patient.fromFirestore(Map<String, dynamic> data, String id) {
    return Patient(
      id: id,
      nationalId: data['nationalId'] ?? '',
      displayName: data['displayName'] ?? '',
      dateOfBirth: data['dateOfBirth'],
      phoneNumber: data['phoneNumber'],
      address: data['address'],
      emergencyContact: data['emergencyContact'],
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        data['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      allergies: data['allergies'] != null
          ? List<String>.from(data['allergies'])
          : [],
    );
  }
}
