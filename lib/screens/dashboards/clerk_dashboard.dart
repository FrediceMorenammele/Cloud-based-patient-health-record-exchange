import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/patient_model.dart';

class ClerkDashboardScreen extends StatefulWidget {
  const ClerkDashboardScreen({super.key});

  @override
  State<ClerkDashboardScreen> createState() => _ClerkDashboardScreenState();
}

class _ClerkDashboardScreenState extends State<ClerkDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRegistering = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient Registration'),
        backgroundColor: Colors.blue.shade800,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patient by name or ID...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showRegistrationForm(),
                icon: const Icon(Icons.person_add),
                label: const Text(
                  'Register New Patient',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(child: _buildPatientList()),
        ],
      ),
    );
  }

  Widget _buildPatientList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('patients').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var patients = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          patients = patients.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['displayName'] ?? '').toLowerCase();
            final nationalId = (data['nationalId'] ?? '').toLowerCase();
            return name.contains(_searchQuery) ||
                nationalId.contains(_searchQuery);
          }).toList();
        }

        if (patients.isEmpty)
          return const Center(child: Text('No patients found'));

        return ListView.builder(
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patientDoc = patients[index];
            final patient = Patient.fromFirestore(
              patientDoc.data() as Map<String, dynamic>,
              patientDoc.id,
            );
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    patient.displayName[0].toUpperCase(),
                    style: TextStyle(color: Colors.blue.shade800),
                  ),
                ),
                title: Text(patient.displayName),
                subtitle: Text('ID: ${patient.nationalId}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility, color: Colors.blue),
                      onPressed: () => _viewPatientDetails(patient),
                    ),
                  ],
                ),
                onTap: () => _viewPatientDetails(patient),
              ),
            );
          },
        );
      },
    );
  }

  void _showRegistrationForm() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final nationalIdController = TextEditingController();
    final phoneController = TextEditingController();
    final allergiesController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Register New Patient'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nationalIdController,
                  decoration: const InputDecoration(
                    labelText: 'National ID *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: allergiesController,
                  decoration: const InputDecoration(
                    labelText: 'Allergies (comma-separated)',
                    hintText: 'e.g., Penicillin, Peanuts',
                    border: OutlineInputBorder(),
                  ),
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                setState(() => _isRegistering = true);

                final newPatient = Patient(
                  id: '',
                  nationalId: nationalIdController.text,
                  displayName: nameController.text,
                  phoneNumber: phoneController.text.isEmpty
                      ? null
                      : phoneController.text,
                  allergies: allergiesController.text.isEmpty
                      ? []
                      : allergiesController.text
                            .split(',')
                            .map((a) => a.trim())
                            .toList(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                await FirebaseFirestore.instance
                    .collection('patients')
                    .add(newPatient.toFirestore());
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Patient registered successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  setState(() => _isRegistering = false);
                }
              }
            },
            child: _isRegistering
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _viewPatientDetails(Patient patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(patient.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('National ID: ${patient.nationalId}'),
            if (patient.phoneNumber != null)
              Text('Phone: ${patient.phoneNumber}'),
            if (patient.allergies != null && patient.allergies!.isNotEmpty)
              Text('Allergies: ${patient.allergies!.join(', ')}'),
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
}
