import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';

class LabDashboardScreen extends StatefulWidget {
  final AppUser? user;
  const LabDashboardScreen({super.key, this.user});

  @override
  State<LabDashboardScreen> createState() => _LabDashboardScreenState();
}

class _LabDashboardScreenState extends State<LabDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final pending = await FirebaseFirestore.instance
        .collection('lab_orders')
        .where('status', isEqualTo: 'pending')
        .get();
    setState(() => _pendingCount = pending.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laboratory Dashboard'),
        backgroundColor: Colors.orange.shade800,
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
            Tab(text: 'Pending Orders', icon: Icon(Icons.pending)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
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
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.pending,
                            size: 28,
                            color: Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_pendingCount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const Text(
                            'Pending Orders',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildPendingOrders(), _buildCompletedOrders()],
            ),
          ),
        ],
      ),
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

        final orders = snapshot.data!.docs;
        if (orders.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pending_outlined, size: 64, color: Colors.grey),
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
            final data = order.data() as Map<String, dynamic>;
            final priority = data['priority'] ?? 'routine';
            final priorityColor = priority == 'stat'
                ? Colors.red
                : (priority == 'urgent' ? Colors.orange : Colors.grey);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: priorityColor.withOpacity(0.2),
                  child: Icon(Icons.science, color: priorityColor),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        data['testName'] ?? 'Lab Test',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: priorityColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: ${data['patientName'] ?? 'Unknown'}'),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data['notes'] != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Clinical Notes:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(data['notes']),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _processOrder(order.id, data),
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Process Order'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildCompletedOrders() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('lab_orders')
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final orders = snapshot.data!.docs;
        if (orders.isEmpty)
          return const Center(child: Text('No completed orders'));
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index];
            final data = order.data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(data['testName'] ?? 'Lab Test'),
                subtitle: Text(
                  'Patient: ${data['patientName']}\nResult: ${data['result'] ?? 'No result'}',
                ),
                trailing: data['isCritical'] == true
                    ? const Icon(Icons.warning, color: Colors.red)
                    : null,
                onTap: () => _viewResult(data),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processOrder(
    String orderId,
    Map<String, dynamic> orderData,
  ) async {
    final resultController = TextEditingController();
    bool isCritical = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Test Results'),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: resultController,
                  decoration: const InputDecoration(
                    labelText: 'Test Results *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Mark as Critical Value'),
                  value: isCritical,
                  onChanged: (value) =>
                      setState(() => isCritical = value ?? false),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (resultController.text.isNotEmpty)
                Navigator.pop(context, {
                  'result': resultController.text,
                  'isCritical': isCritical,
                });
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (result == null) return;

    await FirebaseFirestore.instance
        .collection('lab_orders')
        .doc(orderId)
        .update({
          'status': 'completed',
          'result': result['result'],
          'isCritical': result['isCritical'],
          'completedAt': FieldValue.serverTimestamp(),
          'completedBy': widget.user?.uid,
          'completedByName': widget.user?.displayName,
        });

    await FirebaseFirestore.instance.collection('lab_results').add({
      'orderId': orderId,
      'patientId': orderData['patientId'],
      'patientName': orderData['patientName'],
      'testName': orderData['testName'],
      'result': result['result'],
      'isCritical': result['isCritical'],
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['isCritical']
                ? 'Critical result submitted!'
                : 'Results submitted',
          ),
          backgroundColor: result['isCritical'] ? Colors.red : Colors.green,
        ),
      );
      _loadCounts();
      setState(() {});
    }
  }

  void _viewResult(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['testName'] ?? 'Lab Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${data['patientName']}'),
            const Divider(),
            const Text(
              'Result:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(data['result'] ?? 'No result'),
            if (data['isCritical'] == true) const SizedBox(height: 8),
            if (data['isCritical'] == true)
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.red.shade100,
                child: const Text(
                  '⚠️ CRITICAL VALUE',
                  style: TextStyle(color: Colors.red),
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
