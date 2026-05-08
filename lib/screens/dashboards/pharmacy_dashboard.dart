import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';

class PharmacyDashboardScreen extends StatefulWidget {
  final AppUser? user;

  const PharmacyDashboardScreen({super.key, this.user});

  @override
  State<PharmacyDashboardScreen> createState() =>
      _PharmacyDashboardScreenState();
}

class _PharmacyDashboardScreenState extends State<PharmacyDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingCount = 0;
  int _readyCount = 0;
  int _dispensedCount = 0;
  int _lowStockCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final pending = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('status', isEqualTo: 'pending')
        .get();

    final ready = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('status', isEqualTo: 'ready')
        .get();

    final dispensed = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('status', isEqualTo: 'dispensed')
        .where(
          'dispensedDate',
          isEqualTo: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        )
        .get();

    final lowStock = await FirebaseFirestore.instance
        .collection('medications')
        .where('stock', isLessThanOrEqualTo: 10)
        .get();

    setState(() {
      _pendingCount = pending.docs.length;
      _readyCount = ready.docs.length;
      _dispensedCount = dispensed.docs.length;
      _lowStockCount = lowStock.docs.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy Dashboard'),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.inventory),
            onPressed: () => _showInventory(),
            tooltip: 'Inventory',
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
            Tab(text: 'Pending', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Ready', icon: Icon(Icons.check_circle_outline)),
            Tab(text: 'History', icon: Icon(Icons.history)),
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
                    'Pending',
                    '$_pendingCount',
                    Icons.pending_actions,
                    Colors.orange,
                    () => _tabController.animateTo(0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Ready',
                    '$_readyCount',
                    Icons.check_circle,
                    Colors.green,
                    () => _tabController.animateTo(1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Dispensed Today',
                    '$_dispensedCount',
                    Icons.local_pharmacy,
                    Colors.blue,
                    null,
                  ),
                ),
              ],
            ),
          ),

          // Low Stock Warning
          if (_lowStockCount > 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$_lowStockCount medications low on stock',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showLowStock(),
                    child: const Text('VIEW'),
                  ),
                ],
              ),
            ),

          // Main Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPendingPrescriptions(),
                _buildReadyPrescriptions(),
                _buildDispensedHistory(),
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

  Widget _buildPendingPrescriptions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data!.docs;

        if (prescriptions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 16),
                Text('No pending prescriptions'),
                SizedBox(height: 8),
                Text(
                  'All prescriptions have been processed',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            final prescription = prescriptions[index];
            final data = prescription.data() as Map<String, dynamic>;
            return _buildPrescriptionCard(
              prescription.id,
              data,
              isPending: true,
            );
          },
        );
      },
    );
  }

  Widget _buildReadyPrescriptions() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('status', isEqualTo: 'ready')
          .orderBy('readyAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data!.docs;

        if (prescriptions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No ready prescriptions'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            final prescription = prescriptions[index];
            final data = prescription.data() as Map<String, dynamic>;
            return _buildPrescriptionCard(
              prescription.id,
              data,
              isPending: false,
            );
          },
        );
      },
    );
  }

  Widget _buildDispensedHistory() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prescriptions')
          .where('status', isEqualTo: 'dispensed')
          .orderBy('dispensedAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final prescriptions = snapshot.data!.docs;

        if (prescriptions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No dispensed prescriptions'),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: prescriptions.length,
          itemBuilder: (context, index) {
            final prescription = prescriptions[index];
            final data = prescription.data() as Map<String, dynamic>;
            return _buildHistoryCard(prescription.id, data);
          },
        );
      },
    );
  }

  Widget _buildPrescriptionCard(
    String prescriptionId,
    Map<String, dynamic> data, {
    required bool isPending,
  }) {
    final priority = data['priority'] ?? 'normal';
    Color priorityColor;
    String priorityText;

    switch (priority) {
      case 'stat':
        priorityColor = Colors.red;
        priorityText = 'STAT';
        break;
      case 'urgent':
        priorityColor = Colors.orange;
        priorityText = 'URGENT';
        break;
      default:
        priorityColor = Colors.grey;
        priorityText = 'ROUTINE';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: priorityColor.withOpacity(0.2),
          child: Icon(Icons.medication, color: priorityColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                data['medication'] ?? 'Medication',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                priorityText,
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
            Text('Prescribed: ${_formatDate(data['createdAt'])}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prescription Details
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prescription Details:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('Medication: ${data['medication']}'),
                      Text('Dosage: ${data['dosage']}'),
                      Text('Frequency: ${data['frequency']}'),
                      Text('Duration: ${data['duration']}'),
                      if (data['instructions'] != null &&
                          data['instructions'].toString().isNotEmpty)
                        Text('Instructions: ${data['instructions']}'),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Drug Interaction Check
                if (data['allergies'] != null && data['allergies'].isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.warning_amber,
                              color: Colors.red,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Allergy Warning!',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Patient is allergic to: ${data['allergies'].join(', ')}',
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _preparePrescription(prescriptionId, data),
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Prepare'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelPrescription(prescriptionId),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _dispensePrescription(prescriptionId, data),
                          icon: const Icon(Icons.local_pharmacy),
                          label: const Text('Dispense'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
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
  }

  Widget _buildHistoryCard(String prescriptionId, Map<String, dynamic> data) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 1,
      child: ListTile(
        leading: const Icon(Icons.medication, color: Colors.teal),
        title: Text(data['medication'] ?? 'Medication'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${data['patientName'] ?? 'Unknown'}'),
            Text('Dispensed: ${_formatDate(data['dispensedAt'])}'),
            Text('By: ${data['dispensedByName'] ?? 'Unknown'}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(height: 4),
            Text(
              data['quantity']?.toString() ?? '1',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        onTap: () => _viewDispensedDetails(data),
      ),
    );
  }

  Future<void> _preparePrescription(
    String prescriptionId,
    Map<String, dynamic> data,
  ) async {
    // Check if medication is in stock
    final medicationStock = await _checkMedicationStock(data['medication']);

    if (medicationStock == null || medicationStock < 1) {
      _showOutOfStockDialog(data['medication']);
      return;
    }

    await FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(prescriptionId)
        .update({
          'status': 'ready',
          'readyAt': FieldValue.serverTimestamp(),
          'preparedBy': widget.user?.uid,
          'preparedByName': widget.user?.displayName,
        });

    // Update stock
    await _updateMedicationStock(data['medication'], -1);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription prepared and ready for dispensing'),
        ),
      );
      _loadCounts();
      setState(() {});
    }
  }

  Future<void> _dispensePrescription(
    String prescriptionId,
    Map<String, dynamic> data,
  ) async {
    // Show dispensing dialog
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _DispenseDialog(
        medication: data['medication'],
        dosage: data['dosage'],
        patientName: data['patientName'],
      ),
    );

    if (result == null) return;

    await FirebaseFirestore.instance
        .collection('prescriptions')
        .doc(prescriptionId)
        .update({
          'status': 'dispensed',
          'dispensedAt': FieldValue.serverTimestamp(),
          'dispensedDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'dispensedBy': widget.user?.uid,
          'dispensedByName': widget.user?.displayName,
          'quantity': result['quantity'],
          'instructions': result['instructions'],
        });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medication dispensed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      _loadCounts();
      setState(() {});
    }
  }

  Future<void> _cancelPrescription(String prescriptionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Prescription'),
        content: const Text(
          'Are you sure you want to cancel this prescription?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('prescriptions')
          .doc(prescriptionId)
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': widget.user?.uid,
            'cancelledByName': widget.user?.displayName,
          });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prescription cancelled')));
        _loadCounts();
        setState(() {});
      }
    }
  }

  Future<int?> _checkMedicationStock(String medicationName) async {
    final stockDoc = await FirebaseFirestore.instance
        .collection('medications')
        .where('name', isEqualTo: medicationName)
        .limit(1)
        .get();

    if (stockDoc.docs.isNotEmpty) {
      final data = stockDoc.docs.first.data() as Map<String, dynamic>;
      return data['stock'] as int?;
    }
    return null;
  }

  Future<void> _updateMedicationStock(String medicationName, int change) async {
    final stockDoc = await FirebaseFirestore.instance
        .collection('medications')
        .where('name', isEqualTo: medicationName)
        .limit(1)
        .get();

    if (stockDoc.docs.isNotEmpty) {
      final doc = stockDoc.docs.first;
      final currentStock =
          (doc.data() as Map<String, dynamic>)['stock'] as int? ?? 0;
      await doc.reference.update({
        'stock': currentStock + change,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showOutOfStockDialog(String medicationName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Out of Stock'),
        content: Text(
          '$medicationName is currently out of stock. Please restock before dispensing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showInventory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _InventorySheet(),
    );
  }

  void _showLowStock() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _LowStockSheet(),
    );
  }

  void _viewDispensedDetails(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['medication'] ?? 'Dispensed Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient: ${data['patientName']}'),
            Text('Dosage: ${data['dosage']}'),
            Text('Quantity: ${data['quantity']}'),
            Text('Dispensed by: ${data['dispensedByName']}'),
            Text('Dispensed at: ${_formatDate(data['dispensedAt'])}'),
            if (data['instructions'] != null)
              Text('Instructions: ${data['instructions']}'),
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

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      return DateFormat('MMM dd, yyyy hh:mm a').format(date.toDate());
    }
    return date.toString();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

// Dispense Dialog
class _DispenseDialog extends StatefulWidget {
  final String medication;
  final String dosage;
  final String patientName;

  const _DispenseDialog({
    required this.medication,
    required this.dosage,
    required this.patientName,
  });

  @override
  State<_DispenseDialog> createState() => _DispenseDialogState();
}

class _DispenseDialogState extends State<_DispenseDialog> {
  final _quantityController = TextEditingController(text: '1');
  final _instructionsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dispense Medication'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '${widget.medication}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('${widget.dosage}'),
                Text('Patient: ${widget.patientName}'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _quantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _instructionsController,
            decoration: const InputDecoration(
              labelText: 'Additional Instructions',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'quantity': int.tryParse(_quantityController.text) ?? 1,
              'instructions': _instructionsController.text,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Confirm Dispense'),
        ),
      ],
    );
  }
}

// Inventory Sheet
class _InventorySheet extends StatefulWidget {
  @override
  State<_InventorySheet> createState() => _InventorySheetState();
}

class _InventorySheetState extends State<_InventorySheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  'Medication Inventory',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search medications...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medications')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  var medications = snapshot.data!.docs;
                  if (_searchQuery.isNotEmpty) {
                    medications = medications.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return (data['name'] ?? '').toLowerCase().contains(
                        _searchQuery,
                      );
                    }).toList();
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final doc = medications[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final stock = data['stock'] as int? ?? 0;
                      final isLow = stock <= 10;

                      return ListTile(
                        leading: Icon(
                          Icons.medication,
                          color: isLow ? Colors.red : Colors.teal,
                        ),
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text('${data['dosage'] ?? ''}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isLow
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Stock: $stock',
                            style: TextStyle(
                              color: isLow ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// Low Stock Sheet
class _LowStockSheet extends StatefulWidget {
  @override
  State<_LowStockSheet> createState() => _LowStockSheetState();
}

class _LowStockSheetState extends State<_LowStockSheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: const Center(
                child: Text(
                  'Low Stock Alert',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medications')
                    .where('stock', isLessThanOrEqualTo: 10)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData)
                    return const Center(child: CircularProgressIndicator());

                  final medications = snapshot.data!.docs;

                  if (medications.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 64,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text('All medications are well stocked'),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: scrollController,
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final doc = medications[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final stock = data['stock'] as int? ?? 0;

                      return ListTile(
                        leading: const Icon(Icons.warning, color: Colors.red),
                        title: Text(data['name'] ?? 'Unknown'),
                        subtitle: Text('Current stock: $stock units'),
                        trailing: ElevatedButton(
                          onPressed: () =>
                              _restockMedication(doc.id, data['name']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            minimumSize: const Size(80, 35),
                          ),
                          child: const Text('Restock'),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _restockMedication(String docId, String medicationName) async {
    final quantity = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restock Medication'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Quantity to add'),
          keyboardType: TextInputType.number,
          onSubmitted: (value) {
            Navigator.pop(context, int.tryParse(value) ?? 0);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 100),
            child: const Text('Add 100'),
          ),
        ],
      ),
    );

    if (quantity != null && quantity > 0) {
      final doc = await FirebaseFirestore.instance
          .collection('medications')
          .doc(docId)
          .get();
      final currentStock =
          (doc.data() as Map<String, dynamic>)['stock'] as int? ?? 0;

      await FirebaseFirestore.instance
          .collection('medications')
          .doc(docId)
          .update({
            'stock': currentStock + quantity,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $quantity units of $medicationName'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    }
  }
}
