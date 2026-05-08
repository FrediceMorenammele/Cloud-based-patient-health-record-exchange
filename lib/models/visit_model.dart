// lib/models/visit_model.dart
class Visit {
  final String id;
  final String patientId;
  final String? patientName;
  final String date;
  final String time;
  final String status; // waiting, in_progress, completed, cancelled
  final String? chiefComplaint;
  final String? historyOfPresentIllness;
  final String? physicalExam;
  final String? diagnosis;
  final String? treatment;
  final String? clinicalNotes;
  final Map<String, dynamic>? vitalSigns;
  final List<String>? labOrders;
  final List<String>? prescriptions;
  final String? physicianId;
  final String? physicianName;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime createdAt;
  final DateTime updatedAt;

  Visit({
    required this.id,
    required this.patientId,
    this.patientName,
    required this.date,
    required this.time,
    required this.status,
    this.chiefComplaint,
    this.historyOfPresentIllness,
    this.physicalExam,
    this.diagnosis,
    this.treatment,
    this.clinicalNotes,
    this.vitalSigns,
    this.labOrders,
    this.prescriptions,
    this.physicianId,
    this.physicianName,
    this.startTime,
    this.endTime,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'patientName': patientName,
      'date': date,
      'time': time,
      'status': status,
      'chiefComplaint': chiefComplaint,
      'historyOfPresentIllness': historyOfPresentIllness,
      'physicalExam': physicalExam,
      'diagnosis': diagnosis,
      'treatment': treatment,
      'clinicalNotes': clinicalNotes,
      'vitalSigns': vitalSigns,
      'labOrders': labOrders,
      'prescriptions': prescriptions,
      'physicianId': physicianId,
      'physicianName': physicianName,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Visit.fromFirestore(Map<String, dynamic> data, String id) {
    return Visit(
      id: id,
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'],
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      status: data['status'] ?? 'waiting',
      chiefComplaint: data['chiefComplaint'],
      historyOfPresentIllness: data['historyOfPresentIllness'],
      physicalExam: data['physicalExam'],
      diagnosis: data['diagnosis'],
      treatment: data['treatment'],
      clinicalNotes: data['clinicalNotes'],
      vitalSigns: data['vitalSigns'] != null
          ? Map<String, dynamic>.from(data['vitalSigns'])
          : null,
      labOrders: data['labOrders'] != null
          ? List<String>.from(data['labOrders'])
          : null,
      prescriptions: data['prescriptions'] != null
          ? List<String>.from(data['prescriptions'])
          : null,
      physicianId: data['physicianId'],
      physicianName: data['physicianName'],
      startTime: data['startTime'] != null
          ? DateTime.parse(data['startTime'])
          : null,
      endTime: data['endTime'] != null ? DateTime.parse(data['endTime']) : null,
      createdAt: DateTime.parse(
        data['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        data['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  // CopyWith method for creating updated copies
  Visit copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? date,
    String? time,
    String? status,
    String? chiefComplaint,
    String? historyOfPresentIllness,
    String? physicalExam,
    String? diagnosis,
    String? treatment,
    String? clinicalNotes,
    Map<String, dynamic>? vitalSigns,
    List<String>? labOrders,
    List<String>? prescriptions,
    String? physicianId,
    String? physicianName,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Visit(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      chiefComplaint: chiefComplaint ?? this.chiefComplaint,
      historyOfPresentIllness:
          historyOfPresentIllness ?? this.historyOfPresentIllness,
      physicalExam: physicalExam ?? this.physicalExam,
      diagnosis: diagnosis ?? this.diagnosis,
      treatment: treatment ?? this.treatment,
      clinicalNotes: clinicalNotes ?? this.clinicalNotes,
      vitalSigns: vitalSigns ?? this.vitalSigns,
      labOrders: labOrders ?? this.labOrders,
      prescriptions: prescriptions ?? this.prescriptions,
      physicianId: physicianId ?? this.physicianId,
      physicianName: physicianName ?? this.physicianName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
