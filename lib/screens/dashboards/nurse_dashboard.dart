import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../patient/patient_triage_screen.dart';

class NurseDashboardScreen extends StatefulWidget {
  final AppUser? user;

  const NurseDashboardScreen({super.key, this.user});

  @override
  State<NurseDashboardScreen> createState() => _NurseDashboardScreenState();
}

class _NurseDashboardScreenState extends State<NurseDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _waitingCount = 0;
  int _inTriageCount = 0;
  int _todayDischargedCount = 0;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final waiting = await FirebaseFirestore.instance
        .collection('visits')
        .where('date', isEqualTo: _selectedDate)
        .where('status', isEqualTo: 'waiting')
        .get();

    final inTriage = await FirebaseFirestore.instance
        .collection('visits')
        .where('date', isEqualTo: _selectedDate)
        .where('status', isEqualTo: 'in_triage')
        .get();

    final discharged = await FirebaseFirestore.instance
        .collection('visits')
        .where('date', isEqualTo: _selectedDate)
        .where('status', isEqualTo: 'discharged')
        .get();

    setState(() {
      _waitingCount = waiting.docs.length;
      _inTriageCount = inTriage.docs.length;
      _todayDischargedCount = discharged.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nurse Dashboard'),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadCounts();
              setState(() {});
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Waiting Room', icon: Icon(Icons.people)),
            Tab(text: 'In Triage', icon: Icon(Icons.medical_services)),
            Tab(text: 'Today\'s Patients', icon: Icon(Icons.calendar_today)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Waiting',
                    '$_waitingCount',
                    Icons.access_time,
                    Colors.orange,
                    () => _tabController.animateTo(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'In Triage',
                    '$_inTriageCount',
                    Icons.medical_services,
                    Colors.blue,
                    () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Discharged',
                    '$_todayDischargedCount',
                    Icons.check_circle,
                    Colors.green,
                    null,
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWaitingRoom(),
                _buildInTriage(),
                _buildTodayPatients(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingRoom() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .where('date', isEqualTo: _selectedDate)
          .where('status', isEqualTo: 'waiting')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final visits = snapshot.data!.docs;

        // Sort by arrival time
        visits.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          return (aData['arrivalTime'] ?? '').compareTo(
            bData['arrivalTime'] ?? '',
          );
        });

        if (visits.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No patients waiting'),
                SizedBox(height: 8),
                Text(
                  'The waiting room is empty',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final visitData = visit.data() as Map<String, dynamic>;

            return FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(visitData['patientId'])
                  .get(),
              builder: (context, patientSnapshot) {
                if (!patientSnapshot.hasData) {
                  return const Card(child: ListTile(title: Text('Loading...')));
                }

                final patientData =
                    patientSnapshot.data!.data() as Map<String, dynamic>;
                final arrivalTime =
                    visitData['arrivalTime'] ?? visitData['time'] ?? '--:--';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      radius: 28,
                      child: Text(
                        (patientData['displayName']?[0] ?? 'P').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      patientData['displayName'] ?? 'Unknown Patient',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${patientData['nationalId'] ?? 'N/A'}'),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Arrived: $arrivalTime',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'WAITING',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        _startTriage(
                          visit.id,
                          visitData['patientId'],
                          patientData['displayName'] ?? 'Unknown',
                        );
                      },
                      icon: const Icon(Icons.medical_services, size: 18),
                      label: const Text('Start Triage'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInTriage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .where('date', isEqualTo: _selectedDate)
          .where('status', isEqualTo: 'in_triage')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final visits = snapshot.data!.docs;

        if (visits.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text('No patients in triage'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final visitData = visit.data() as Map<String, dynamic>;

            return FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(visitData['patientId'])
                  .get(),
              builder: (context, patientSnapshot) {
                if (!patientSnapshot.hasData) {
                  return const Card(child: ListTile(title: Text('Loading...')));
                }

                final patientData =
                    patientSnapshot.data!.data() as Map<String, dynamic>;
                final triageData =
                    visitData['triageData'] as Map<String, dynamic>?;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      radius: 28,
                      child: Text(
                        (patientData['displayName']?[0] ?? 'P').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      patientData['displayName'] ?? 'Unknown Patient',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ID: ${patientData['nationalId'] ?? 'N/A'}'),
                        if (triageData != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            children: [
                              if (triageData['temperature'] != null)
                                Chip(
                                  label: Text('${triageData['temperature']}°C'),
                                  backgroundColor: Colors.blue.shade50,
                                ),
                              if (triageData['bloodPressure'] != null)
                                Chip(
                                  label: Text(triageData['bloodPressure']),
                                  backgroundColor: Colors.blue.shade50,
                                ),
                              if (triageData['chiefComplaint'] != null)
                                Chip(
                                  label: Text(triageData['chiefComplaint']),
                                  backgroundColor: Colors.orange.shade50,
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'IN TRIAGE',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.orange),
                          onPressed: () {
                            _continueTriage(
                              visit.id,
                              visitData['patientId'],
                              patientData['displayName'] ?? 'Unknown',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.send, color: Colors.green),
                          onPressed: () {
                            _sendToPhysician(visit.id);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTodayPatients() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .where('date', isEqualTo: _selectedDate)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final visits = snapshot.data!.docs;

        // Sort by time
        visits.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          return (aData['time'] ?? '').compareTo(bData['time'] ?? '');
        });

        if (visits.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No patients today'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: visits.length,
          itemBuilder: (context, index) {
            final visit = visits[index];
            final visitData = visit.data() as Map<String, dynamic>;

            return FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(visitData['patientId'])
                  .get(),
              builder: (context, patientSnapshot) {
                if (!patientSnapshot.hasData) {
                  return const Card(child: ListTile(title: Text('Loading...')));
                }

                final patientData =
                    patientSnapshot.data!.data() as Map<String, dynamic>;
                final status = visitData['status'] ?? 'unknown';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status),
                      child: Text(
                        (patientData['displayName']?[0] ?? 'P').toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(patientData['displayName'] ?? 'Unknown'),
                    subtitle: Text('Time: ${visitData['time'] ?? '--:--'}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          fontSize: 10,
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      _viewPatientSummary(
                        visit.id,
                        visitData['patientId'],
                        patientData,
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _startTriage(
    String visitId,
    String patientId,
    String patientName,
  ) async {
    // Navigate to triage screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientTriageScreen(
          patientId: patientId,
          patientName: patientName,
          visitId: visitId,
        ),
      ),
    );

    if (result == true) {
      _loadCounts();
      setState(() {});
    }
  }

  Future<void> _continueTriage(
    String visitId,
    String patientId,
    String patientName,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientTriageScreen(
          patientId: patientId,
          patientName: patientName,
          visitId: visitId,
        ),
      ),
    );

    if (result == true) {
      _loadCounts();
      setState(() {});
    }
  }

  Future<void> _sendToPhysician(String visitId) async {
    await FirebaseFirestore.instance.collection('visits').doc(visitId).update({
      'status': 'in_progress',
      'triageCompletedAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient sent to physician'),
          backgroundColor: Colors.green,
        ),
      );
      _loadCounts();
      setState(() {});
    }
  }

  void _viewPatientSummary(
    String visitId,
    String patientId,
    Map<String, dynamic> patientData,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(patientData['displayName'] ?? 'Patient Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${patientData['nationalId'] ?? 'N/A'}'),
            if (patientData['phoneNumber'] != null)
              Text('Phone: ${patientData['phoneNumber']}'),
            if (patientData['allergies'] != null &&
                patientData['allergies'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Allergies:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 8,
                      children: (patientData['allergies'] as List)
                          .map((a) => Chip(label: Text(a)))
                          .toList(),
                    ),
                  ],
                ),
              ),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'waiting':
        return Colors.orange;
      case 'in_triage':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'discharged':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'waiting':
        return 'WAITING';
      case 'in_triage':
        return 'IN TRIAGE';
      case 'in_progress':
        return 'WITH DOCTOR';
      case 'completed':
        return 'COMPLETED';
      case 'discharged':
        return 'DISCHARGED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
