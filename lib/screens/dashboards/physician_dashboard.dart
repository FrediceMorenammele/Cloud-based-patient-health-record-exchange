import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';
import '../../models/patient_model.dart';
import '../../widgets/patient_search_bar.dart';
import '../patient/patient_visit_screen.dart';

class PhysicianDashboardScreen extends StatefulWidget {
  final AppUser? user;

  const PhysicianDashboardScreen({super.key, this.user});

  @override
  State<PhysicianDashboardScreen> createState() =>
      _PhysicianDashboardScreenState();
}

class _PhysicianDashboardScreenState extends State<PhysicianDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingOrdersCount = 0;
  int _todayPatientsCount = 0;
  int _criticalResultsCount = 0;
  String _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final pendingOrders = await FirebaseFirestore.instance
        .collection('lab_orders')
        .where('status', isEqualTo: 'pending')
        .get();

    final todayVisits = await FirebaseFirestore.instance
        .collection('visits')
        .where('date', isEqualTo: _selectedDate)
        .get();

    final todayPatients = todayVisits.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] != 'completed';
    }).toList();

    final criticalResults = await FirebaseFirestore.instance
        .collection('lab_results')
        .where('isCritical', isEqualTo: true)
        .where('isRead', isEqualTo: false)
        .get();

    setState(() {
      _pendingOrdersCount = pendingOrders.docs.length;
      _todayPatientsCount = todayPatients.length;
      _criticalResultsCount = criticalResults.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Physician Dashboard'),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => _showNotifications(),
              ),
              if (_criticalResultsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_criticalResultsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
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
            Tab(text: 'Today\'s Patients', icon: Icon(Icons.today)),
            Tab(text: 'Pending Orders', icon: Icon(Icons.science)),
            Tab(text: 'Recent Patients', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Today\'s Patients',
                    '$_todayPatientsCount',
                    Icons.people,
                    Colors.blue,
                    () => _tabController.animateTo(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending Orders',
                    '$_pendingOrdersCount',
                    Icons.science,
                    Colors.orange,
                    () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Critical Results',
                    '$_criticalResultsCount',
                    Icons.warning,
                    Colors.red,
                    null,
                  ),
                ),
              ],
            ),
          ),
          PatientSearchBar(
            onPatientSelected: (patientId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      PatientVisitScreen(patientId: patientId),
                ),
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTodayPatients(),
                _buildPendingOrders(),
                _buildRecentPatients(),
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

  Widget _buildTodayPatients() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .where('date', isEqualTo: today)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var visits = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'completed';
        }).toList();

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
                Icon(Icons.today, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No patients scheduled for today'),
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
                if (!patientSnapshot.hasData)
                  return const Card(child: ListTile(title: Text('Loading...')));

                final patientData =
                    patientSnapshot.data!.data() as Map<String, dynamic>;
                final status = visitData['status'] ?? 'waiting';

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _getStatusColor(status).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status),
                      radius: 24,
                      child: Text(
                        (patientData['displayName']?[0] ?? 'P').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
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
                              visitData['time'] ?? '--:--',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getStatusColor(status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: status == 'waiting'
                        ? ElevatedButton(
                            onPressed: () =>
                                _startVisit(visit.id, visitData['patientId']),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Start Visit'),
                          )
                        : status == 'in_progress'
                        ? ElevatedButton(
                            onPressed: () => _continueVisit(
                              visit.id,
                              visitData['patientId'],
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Continue'),
                          )
                        : IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () => _viewPastVisit(
                              visit.id,
                              visitData['patientId'],
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

  Widget _buildPendingOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lab_orders')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        var orders = snapshot.data!.docs;
        orders.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final priorityOrder = {'stat': 3, 'urgent': 2, 'routine': 1};
          return (priorityOrder[bData['priority']] ?? 0).compareTo(
            priorityOrder[aData['priority']] ?? 0,
          );
        });

        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.science_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No pending orders'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final orderData = order.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: const Icon(Icons.science, color: Colors.orange),
                ),
                title: Text(orderData['testName'] ?? 'Lab Test'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: ${orderData['patientName'] ?? 'Unknown'}'),
                    if (orderData['priority'] == 'urgent' ||
                        orderData['priority'] == 'stat')
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (orderData['priority'] == 'stat'
                                      ? Colors.red
                                      : Colors.orange)
                                  .withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          orderData['priority'] == 'stat' ? 'STAT' : 'URGENT',
                          style: TextStyle(
                            color: orderData['priority'] == 'stat'
                                ? Colors.red
                                : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _viewOrderDetails(order.id, orderData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View'),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentPatients() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('visits')
          .orderBy('date', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

        final Map<String, Map<String, dynamic>> uniquePatients = {};
        for (var visit in snapshot.data!.docs) {
          final visitData = visit.data() as Map<String, dynamic>;
          final patientId = visitData['patientId'];
          if (!uniquePatients.containsKey(patientId)) {
            uniquePatients[patientId] = {
              'patientId': patientId,
              'lastVisitDate': visitData['date'],
              'visitId': visit.id,
            };
          }
        }

        if (uniquePatients.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No recent patients'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: uniquePatients.length,
          itemBuilder: (context, index) {
            final patientInfo = uniquePatients.values.elementAt(index);
            return FutureBuilder(
              future: FirebaseFirestore.instance
                  .collection('patients')
                  .doc(patientInfo['patientId'])
                  .get(),
              builder: (context, patientSnapshot) {
                if (!patientSnapshot.hasData)
                  return const Card(child: ListTile(title: Text('Loading...')));
                final patientData =
                    patientSnapshot.data!.data() as Map<String, dynamic>;
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
                      child: Text(
                        (patientData['displayName']?[0] ?? 'P').toUpperCase(),
                        style: TextStyle(color: Colors.blue.shade800),
                      ),
                    ),
                    title: Text(
                      patientData['displayName'] ?? 'Unknown Patient',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Last visit: ${patientInfo['lastVisitDate']}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PatientVisitScreen(
                            patientId: patientInfo['patientId'],
                            visitId: patientInfo['visitId'],
                          ),
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

  void _startVisit(String visitId, String patientId) async {
    await FirebaseFirestore.instance.collection('visits').doc(visitId).update({
      'status': 'in_progress',
      'startTime': DateTime.now().toIso8601String(),
      'physicianId': widget.user?.uid,
      'physicianName': widget.user?.displayName,
    });
    if (mounted)
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PatientVisitScreen(patientId: patientId, visitId: visitId),
        ),
      );
  }

  void _continueVisit(String visitId, String patientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            PatientVisitScreen(patientId: patientId, visitId: visitId),
      ),
    );
  }

  void _viewPastVisit(String visitId, String patientId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientVisitScreen(
          patientId: patientId,
          visitId: visitId,
          readOnly: true,
        ),
      ),
    );
  }

  void _viewOrderDetails(String orderId, Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(orderData['testName'] ?? 'Lab Order Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test: ${orderData['testName']}'),
            const SizedBox(height: 8),
            Text('Patient: ${orderData['patientName']}'),
            const SizedBox(height: 8),
            Text('Priority: ${orderData['priority'] ?? 'normal'}'),
            const SizedBox(height: 8),
            if (orderData['notes'] != null)
              Text('Notes: ${orderData['notes']}'),
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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('lab_results')
              .where('isCritical', isEqualTo: true)
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final criticalResults = snapshot.data!.docs;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${criticalResults.length} new',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (criticalResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text('No new notifications'),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: criticalResults.length,
                    itemBuilder: (context, index) {
                      final result = criticalResults[index];
                      final resultData = result.data() as Map<String, dynamic>;
                      return ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text(
                          'Critical Result: ${resultData['testName']}',
                        ),
                        subtitle: Text('Patient: ${resultData['patientName']}'),
                        trailing: TextButton(
                          onPressed: () async {
                            await result.reference.update({'isRead': true});
                            Navigator.pop(context);
                          },
                          child: const Text('Mark Read'),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PatientVisitScreen(
                                patientId: resultData['patientId'],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return Colors.orange;
      case 'in_progress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
