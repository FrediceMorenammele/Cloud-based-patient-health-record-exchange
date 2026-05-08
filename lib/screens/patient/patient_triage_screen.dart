import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientTriageScreen extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? visitId;

  const PatientTriageScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.visitId,
  });

  @override
  State<PatientTriageScreen> createState() => _PatientTriageScreenState();
}

class _PatientTriageScreenState extends State<PatientTriageScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Vital signs controllers
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _oxygenSaturationController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Triage data
  final _chiefComplaintController = TextEditingController();
  final _historyController = TextEditingController();
  String _painLevel = '0';
  String _triageCategory = 'green';

  List<String> _existingAllergies = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _loadExistingTriage();
  }

  Future<void> _loadPatientData() async {
    final patientDoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(widget.patientId)
        .get();

    if (patientDoc.exists) {
      final data = patientDoc.data() as Map<String, dynamic>;
      setState(() {
        _existingAllergies = List<String>.from(data['allergies'] ?? []);
      });
    }
  }

  Future<void> _loadExistingTriage() async {
    if (widget.visitId == null) return;

    final visitDoc = await FirebaseFirestore.instance
        .collection('visits')
        .doc(widget.visitId)
        .get();

    if (visitDoc.exists) {
      final data = visitDoc.data() as Map<String, dynamic>;
      final triageData = data['triageData'] as Map<String, dynamic>?;

      if (triageData != null) {
        _temperatureController.text =
            triageData['temperature']?.toString() ?? '';
        _bloodPressureController.text = triageData['bloodPressure'] ?? '';
        _heartRateController.text = triageData['heartRate']?.toString() ?? '';
        _respiratoryRateController.text =
            triageData['respiratoryRate']?.toString() ?? '';
        _oxygenSaturationController.text =
            triageData['oxygenSaturation']?.toString() ?? '';
        _weightController.text = triageData['weight']?.toString() ?? '';
        _heightController.text = triageData['height']?.toString() ?? '';
        _chiefComplaintController.text = triageData['chiefComplaint'] ?? '';
        _historyController.text = triageData['history'] ?? '';
        _painLevel = triageData['painLevel']?.toString() ?? '0';
        _triageCategory = triageData['triageCategory'] ?? 'green';
      }
    }
  }

  Future<void> _saveTriage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final triageData = {
        'temperature': double.tryParse(_temperatureController.text),
        'bloodPressure': _bloodPressureController.text,
        'heartRate': int.tryParse(_heartRateController.text),
        'respiratoryRate': int.tryParse(_respiratoryRateController.text),
        'oxygenSaturation': int.tryParse(_oxygenSaturationController.text),
        'weight': double.tryParse(_weightController.text),
        'height': double.tryParse(_heightController.text),
        'bmi': _calculateBMI(),
        'chiefComplaint': _chiefComplaintController.text,
        'history': _historyController.text,
        'painLevel': int.tryParse(_painLevel),
        'triageCategory': _triageCategory,
        'recordedAt': FieldValue.serverTimestamp(),
        'recordedBy': 'Nurse', // TODO: Add actual user name
      };

      final visitRef = FirebaseFirestore.instance
          .collection('visits')
          .doc(widget.visitId);

      await visitRef.update({
        'triageData': triageData,
        'status': 'in_triage',
        'triageCompleted': true,
        'triageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Triage data saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  double? _calculateBMI() {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    if (weight != null && height != null && height > 0) {
      return weight / ((height / 100) * (height / 100));
    }
    return null;
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  Color _getTriageColor(String category) {
    switch (category) {
      case 'red':
        return Colors.red;
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow.shade700;
      case 'green':
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  String _getTriageText(String category) {
    switch (category) {
      case 'red':
        return 'Immediate (Resuscitation)';
      case 'orange':
        return 'Emergent';
      case 'yellow':
        return 'Urgent';
      case 'green':
        return 'Non-urgent';
      default:
        return 'Non-urgent';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Triage: ${widget.patientName}'),
        backgroundColor: Colors.green.shade700,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveTriage,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Triage Category
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Triage Category',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildTriageOption('red', 'RED'),
                          const SizedBox(width: 8),
                          _buildTriageOption('orange', 'ORANGE'),
                          const SizedBox(width: 8),
                          _buildTriageOption('yellow', 'YELLOW'),
                          const SizedBox(width: 8),
                          _buildTriageOption('green', 'GREEN'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getTriageColor(
                            _triageCategory,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: _getTriageColor(_triageCategory),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(_getTriageText(_triageCategory)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Vital Signs
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vital Signs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          TextFormField(
                            controller: _temperatureController,
                            decoration: const InputDecoration(
                              labelText: 'Temperature (°C)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          TextFormField(
                            controller: _bloodPressureController,
                            decoration: const InputDecoration(
                              labelText: 'Blood Pressure (mmHg)',
                              hintText: '120/80',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          TextFormField(
                            controller: _heartRateController,
                            decoration: const InputDecoration(
                              labelText: 'Heart Rate (bpm)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          TextFormField(
                            controller: _respiratoryRateController,
                            decoration: const InputDecoration(
                              labelText: 'Respiratory Rate',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          TextFormField(
                            controller: _oxygenSaturationController,
                            decoration: const InputDecoration(
                              labelText: 'O2 Saturation (%)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Weight (kg)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Height (cm)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                      if (_calculateBMI() != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'BMI:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(_calculateBMI()!.toStringAsFixed(1)),
                                Text(_getBMICategory(_calculateBMI()!)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Pain Scale
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pain Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Pain Level (0-10): $_painLevel'),
                      Slider(
                        value: double.parse(_painLevel),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: _painLevel,
                        onChanged: (value) {
                          setState(() {
                            _painLevel = value.toInt().toString();
                          });
                        },
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('No Pain', style: TextStyle(fontSize: 12)),
                          Text('Moderate', style: TextStyle(fontSize: 12)),
                          Text('Worst Pain', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Clinical Assessment
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clinical Assessment',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _chiefComplaintController,
                        decoration: const InputDecoration(
                          labelText: 'Chief Complaint *',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _historyController,
                        decoration: const InputDecoration(
                          labelText: 'History of Present Illness',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
              ),

              // Allergies Warning
              if (_existingAllergies.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Card(
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Patient Allergies',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: _existingAllergies.map((allergy) {
                              return Chip(
                                label: Text(allergy),
                                backgroundColor: Colors.red.shade100,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveTriage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'SAVE TRIAGE DATA',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTriageOption(String value, String label) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _triageCategory = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _triageCategory == value
                ? _getTriageColor(value)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _triageCategory == value ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _chiefComplaintController.dispose();
    _historyController.dispose();
    super.dispose();
  }
}
