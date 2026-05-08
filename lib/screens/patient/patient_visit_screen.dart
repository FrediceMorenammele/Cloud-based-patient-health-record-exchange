// lib/screens/patient/patient_visit_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/patient_model.dart';
import '../../models/visit_model.dart';

class PatientVisitScreen extends StatefulWidget {
  final String patientId;
  final String? visitId;
  final bool readOnly;

  const PatientVisitScreen({
    super.key,
    required this.patientId,
    this.visitId,
    this.readOnly = false,
  });

  @override
  State<PatientVisitScreen> createState() => _PatientVisitScreenState();
}

class _PatientVisitScreenState extends State<PatientVisitScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Patient? _patient;
  Visit? _visit;
  bool _isLoading = true;
  bool _isSaving = false;

  // Form controllers for visit entry
  final _chiefComplaintController = TextEditingController();
  final _historyController = TextEditingController();
  final _physicalExamController = TextEditingController();
  final _diagnosisController = TextEditingController();
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();

  // Vital signs
  final _temperatureController = TextEditingController();
  final _bloodPressureController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _respiratoryRateController = TextEditingController();
  final _oxygenSaturationController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  String _selectedStatus = 'in_progress';
  List<String> _existingAllergies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load patient data
      final patientDoc = await FirebaseFirestore.instance
          .collection('patients')
          .doc(widget.patientId)
          .get();

      if (patientDoc.exists) {
        _patient = Patient.fromFirestore(patientDoc.data()!, widget.patientId);
        _existingAllergies = _patient?.allergies ?? [];
      }

      // Load visit if exists
      if (widget.visitId != null) {
        final visitDoc = await FirebaseFirestore.instance
            .collection('visits')
            .doc(widget.visitId)
            .get();

        if (visitDoc.exists) {
          _visit = Visit.fromFirestore(visitDoc.data()!, widget.visitId!);
          _populateFormFromVisit();
        }
      } else {
        // Create a new visit
        await _createNewVisit();
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateFormFromVisit() {
    if (_visit == null) return;

    _chiefComplaintController.text = _visit!.chiefComplaint ?? '';
    _historyController.text = _visit!.historyOfPresentIllness ?? '';
    _physicalExamController.text = _visit!.physicalExam ?? '';
    _diagnosisController.text = _visit!.diagnosis ?? '';
    _treatmentController.text = _visit!.treatment ?? '';
    _notesController.text = _visit!.clinicalNotes ?? '';
    _selectedStatus = _visit!.status;

    // Populate vital signs
    if (_visit!.vitalSigns != null) {
      _temperatureController.text =
          _visit!.vitalSigns!['temperature']?.toString() ?? '';
      _bloodPressureController.text =
          _visit!.vitalSigns!['bloodPressure'] ?? '';
      _heartRateController.text =
          _visit!.vitalSigns!['heartRate']?.toString() ?? '';
      _respiratoryRateController.text =
          _visit!.vitalSigns!['respiratoryRate']?.toString() ?? '';
      _oxygenSaturationController.text =
          _visit!.vitalSigns!['oxygenSaturation']?.toString() ?? '';
      _weightController.text = _visit!.vitalSigns!['weight']?.toString() ?? '';
      _heightController.text = _visit!.vitalSigns!['height']?.toString() ?? '';
    }
  }

  Future<void> _createNewVisit() async {
    final now = DateTime.now();
    final newVisit = Visit(
      id: '',
      patientId: widget.patientId,
      patientName: _patient?.displayName,
      date: DateFormat('yyyy-MM-dd').format(now),
      time: DateFormat('hh:mm a').format(now),
      status: 'in_progress',
      createdAt: now,
      updatedAt: now,
    );

    final docRef = await FirebaseFirestore.instance
        .collection('visits')
        .add(newVisit.toFirestore());

    setState(() {
      _visit = newVisit.copyWith(id: docRef.id);
    });
  }

  Future<void> _saveVisit() async {
    if (_visit == null) return;

    setState(() => _isSaving = true);

    try {
      final vitalSigns = {
        'temperature': double.tryParse(_temperatureController.text),
        'bloodPressure': _bloodPressureController.text,
        'heartRate': int.tryParse(_heartRateController.text),
        'respiratoryRate': int.tryParse(_respiratoryRateController.text),
        'oxygenSaturation': int.tryParse(_oxygenSaturationController.text),
        'weight': double.tryParse(_weightController.text),
        'height': double.tryParse(_heightController.text),
        'bmi': _calculateBMI(),
      };

      final updatedVisit = _visit!.copyWith(
        chiefComplaint: _chiefComplaintController.text,
        historyOfPresentIllness: _historyController.text,
        physicalExam: _physicalExamController.text,
        diagnosis: _diagnosisController.text,
        treatment: _treatmentController.text,
        clinicalNotes: _notesController.text,
        vitalSigns: vitalSigns,
        status: _selectedStatus,
        updatedAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('visits')
          .doc(_visit!.id)
          .update(updatedVisit.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _completeVisit() async {
    setState(() => _isSaving = true);

    try {
      await _saveVisit();

      await FirebaseFirestore.instance
          .collection('visits')
          .doc(_visit!.id)
          .update({
            'status': 'completed',
            'endTime': DateTime.now().toIso8601String(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visit completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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

  void _orderLabTest() {
    showDialog(
      context: context,
      builder: (context) => OrderLabTestDialog(
        patientId: widget.patientId,
        patientName: _patient?.displayName ?? 'Unknown',
        visitId: _visit?.id,
        onOrdered: () {
          setState(() {});
        },
      ),
    );
  }

  void _prescribeMedication() {
    showDialog(
      context: context,
      builder: (context) => PrescribeMedicationDialog(
        patientId: widget.patientId,
        patientName: _patient?.displayName ?? 'Unknown',
        allergies: _existingAllergies,
        onPrescribed: () {
          setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Visit'),
            Text(
              _patient?.displayName ?? 'Loading...',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        actions: [
          if (!widget.readOnly) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveVisit,
              tooltip: 'Save',
            ),
            IconButton(
              icon: const Icon(Icons.check_circle),
              onPressed: _isSaving ? null : _completeVisit,
              tooltip: 'Complete Visit',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Vitals', icon: Icon(Icons.favorite)),
            Tab(text: 'Clinical', icon: Icon(Icons.medical_services)),
            Tab(text: 'Orders', icon: Icon(Icons.science)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVitalsTab(),
          _buildClinicalTab(),
          _buildOrdersTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: _showQuickActions,
              backgroundColor: Colors.blue.shade800,
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildVitalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Vital Signs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildVitalField(
                        'Temperature (°C)',
                        _temperatureController,
                        TextInputType.number,
                      ),
                      _buildVitalField(
                        'Blood Pressure (mmHg)',
                        _bloodPressureController,
                        TextInputType.text,
                      ),
                      _buildVitalField(
                        'Heart Rate (bpm)',
                        _heartRateController,
                        TextInputType.number,
                      ),
                      _buildVitalField(
                        'Respiratory Rate',
                        _respiratoryRateController,
                        TextInputType.number,
                      ),
                      _buildVitalField(
                        'O2 Saturation (%)',
                        _oxygenSaturationController,
                        TextInputType.number,
                      ),
                      _buildVitalField(
                        'Weight (kg)',
                        _weightController,
                        TextInputType.number,
                      ),
                      _buildVitalField(
                        'Height (cm)',
                        _heightController,
                        TextInputType.number,
                      ),
                    ],
                  ),
                  if (_calculateBMI() != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
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
        ],
      ),
    );
  }

  Widget _buildVitalField(
    String label,
    TextEditingController controller,
    TextInputType type,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        enabled: !widget.readOnly,
      ),
      keyboardType: type,
    );
  }

  Widget _buildClinicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Clinical Assessment',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _chiefComplaintController,
                    decoration: const InputDecoration(
                      labelText: 'Chief Complaint',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !widget.readOnly,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _historyController,
                    decoration: const InputDecoration(
                      labelText: 'History of Present Illness',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    enabled: !widget.readOnly,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _physicalExamController,
                    decoration: const InputDecoration(
                      labelText: 'Physical Examination',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                    enabled: !widget.readOnly,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _diagnosisController,
                    decoration: const InputDecoration(
                      labelText: 'Diagnosis',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !widget.readOnly,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _treatmentController,
                    decoration: const InputDecoration(
                      labelText: 'Treatment Plan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    enabled: !widget.readOnly,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Additional Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    enabled: !widget.readOnly,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return Column(
      children: [
        if (!widget.readOnly)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _orderLabTest,
                    icon: const Icon(Icons.science),
                    label: const Text('Order Lab Test'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _prescribeMedication,
                    icon: const Icon(Icons.medication),
                    label: const Text('Prescribe'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lab_orders')
                .where('patientId', isEqualTo: widget.patientId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final orders = snapshot.data!.docs;

              if (orders.isEmpty) {
                return const Center(child: Text('No lab orders'));
              }

              return ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];
                  final data = order.data() as Map<String, dynamic>;
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.science, color: Colors.orange),
                      title: Text(data['testName'] ?? 'Lab Test'),
                      subtitle: Text('Status: ${data['status'] ?? 'pending'}'),
                      trailing: data['status'] == 'completed'
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.pending, color: Colors.orange),
                      onTap: () {
                        _viewLabResult(order.id, data);
                      },
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .where('patientId', isEqualTo: widget.patientId)
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final visits = snapshot.data!.docs;

        if (visits.isEmpty) {
          return const Center(child: Text('No visit history'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final data = visit.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: const Icon(Icons.medical_information),
                title: Text('Visit: ${data['date']}'),
                subtitle: Text(data['status'] ?? 'Unknown'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['chiefComplaint'] != null) ...[
                          const Text(
                            'Chief Complaint:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(data['chiefComplaint']),
                          const SizedBox(height: 8),
                        ],
                        if (data['diagnosis'] != null) ...[
                          const Text(
                            'Diagnosis:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(data['diagnosis']),
                          const SizedBox(height: 8),
                        ],
                        if (data['treatment'] != null) ...[
                          const Text(
                            'Treatment:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(data['treatment']),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Quick Actions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: Icon(Icons.bolt),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.science, color: Colors.orange),
              title: const Text('Order Lab Test'),
              onTap: () {
                Navigator.pop(context);
                _orderLabTest();
              },
            ),
            ListTile(
              leading: const Icon(Icons.medication, color: Colors.green),
              title: const Text('Prescribe Medication'),
              onTap: () {
                Navigator.pop(context);
                _prescribeMedication();
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.blue),
              title: const Text('Request Referral'),
              onTap: () {
                Navigator.pop(context);
                _requestReferral();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewLabResult(String orderId, Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(orderData['testName'] ?? 'Lab Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (orderData['result'] != null) ...[
              const Text(
                'Result:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(orderData['result']),
              const SizedBox(height: 8),
            ],
            if (orderData['referenceRange'] != null) ...[
              Text('Reference Range: ${orderData['referenceRange']}'),
            ],
            if (orderData['isCritical'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: const Text(
                  '⚠️ CRITICAL VALUE',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _requestReferral() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Referral'),
        content: const Text('Referral functionality coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _getBMICategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Normal weight';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chiefComplaintController.dispose();
    _historyController.dispose();
    _physicalExamController.dispose();
    _diagnosisController.dispose();
    _treatmentController.dispose();
    _notesController.dispose();
    _temperatureController.dispose();
    _bloodPressureController.dispose();
    _heartRateController.dispose();
    _respiratoryRateController.dispose();
    _oxygenSaturationController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }
}

// Order Lab Test Dialog
// Order Lab Test Dialog - FIXED VERSION
class OrderLabTestDialog extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String? visitId;
  final VoidCallback onOrdered;

  const OrderLabTestDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    this.visitId,
    required this.onOrdered,
  });

  @override
  State<OrderLabTestDialog> createState() => _OrderLabTestDialogState();
}

class _OrderLabTestDialogState extends State<OrderLabTestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  String? _selectedTest;
  String _priority = 'routine';
  bool _isSubmitting = false;

  final List<Map<String, String>> _availableTests = [
    {'name': 'Complete Blood Count (CBC)', 'code': 'CBC'},
    {'name': 'Blood Glucose', 'code': 'GLU'},
    {'name': 'Lipid Panel', 'code': 'LIPID'},
    {'name': 'Liver Function Test (LFT)', 'code': 'LFT'},
    {'name': 'Renal Function Test (RFT)', 'code': 'RFT'},
    {'name': 'Thyroid Function Test (TFT)', 'code': 'TFT'},
    {'name': 'Urinalysis', 'code': 'UA'},
    {'name': 'HIV Test', 'code': 'HIV'},
    {'name': 'COVID-19 PCR', 'code': 'COVID'},
    {'name': 'Blood Culture', 'code': 'CULTURE'},
    {'name': 'X-Ray', 'code': 'XRAY'},
    {'name': 'Ultrasound', 'code': 'USG'},
    {'name': 'CT Scan', 'code': 'CT'},
    {'name': 'MRI', 'code': 'MRI'},
  ];

  @override
  void initState() {
    super.initState();
    // Set default selected test
    _selectedTest = _availableTests.first['name'];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Order Lab Test'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Test Type Dropdown - FIXED
              DropdownButtonFormField<String>(
                value: _selectedTest,
                decoration: const InputDecoration(
                  labelText: 'Test Type',
                  border: OutlineInputBorder(),
                ),
                items: _availableTests.map((test) {
                  return DropdownMenuItem<String>(
                    value: test['name'],
                    child: Text(test['name']!),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedTest = value;
                  });
                },
                validator: (v) => v == null ? 'Select a test' : null,
              ),
              const SizedBox(height: 12),

              // Priority Dropdown - FIXED with unique values
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'routine',
                    child: Text('Routine'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'urgent',
                    child: Text('Urgent'),
                  ),
                  DropdownMenuItem<String>(value: 'stat', child: Text('STAT')),
                ],
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Clinical Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Clinical Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitOrder,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Place Order'),
        ),
      ],
    );
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTest == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a test')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final orderData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'visitId': widget.visitId,
        'testName': _selectedTest,
        'testCode': _availableTests.firstWhere(
          (t) => t['name'] == _selectedTest,
        )['code'],
        'priority': _priority,
        'notes': _notesController.text,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('lab_orders').add(orderData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lab order placed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onOrdered();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// Prescribe Medication Dialog
// Prescribe Medication Dialog - FIXED VERSION
class PrescribeMedicationDialog extends StatefulWidget {
  final String patientId;
  final String patientName;
  final List<String> allergies;
  final VoidCallback onPrescribed;

  const PrescribeMedicationDialog({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.allergies,
    required this.onPrescribed,
  });

  @override
  State<PrescribeMedicationDialog> createState() =>
      _PrescribeMedicationDialogState();
}

class _PrescribeMedicationDialogState extends State<PrescribeMedicationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _medicationController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _durationController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _priority = 'routine';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prescribe Medication'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.allergies.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ Patient Allergies:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: widget.allergies.map((allergy) {
                          return Chip(
                            label: Text(allergy),
                            backgroundColor: Colors.red.shade100,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Priority Dropdown - FIXED
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String>(
                    value: 'routine',
                    child: Text('Routine'),
                  ),
                  DropdownMenuItem<String>(
                    value: 'urgent',
                    child: Text('Urgent'),
                  ),
                  DropdownMenuItem<String>(value: 'stat', child: Text('STAT')),
                ],
                onChanged: (value) {
                  setState(() {
                    _priority = value!;
                  });
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _medicationController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: const InputDecoration(
                        labelText: 'Dosage *',
                        hintText: 'e.g., 500mg',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _frequencyController,
                      decoration: const InputDecoration(
                        labelText: 'Frequency *',
                        hintText: 'e.g., Twice daily',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationController,
                decoration: const InputDecoration(
                  labelText: 'Duration *',
                  hintText: 'e.g., 7 days',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Special Instructions',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitPrescription,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Prescribe'),
        ),
      ],
    );
  }

  Future<void> _submitPrescription() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final prescriptionData = {
        'patientId': widget.patientId,
        'patientName': widget.patientName,
        'medication': _medicationController.text,
        'dosage': _dosageController.text,
        'frequency': _frequencyController.text,
        'duration': _durationController.text,
        'instructions': _instructionsController.text,
        'priority': _priority,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('prescriptions')
          .add(prescriptionData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onPrescribed();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
