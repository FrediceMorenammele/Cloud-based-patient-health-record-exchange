import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/user_model.dart';

class ManagerReportsScreen extends StatefulWidget {
  final AppUser? user;

  const ManagerReportsScreen({super.key, this.user});

  @override
  State<ManagerReportsScreen> createState() => _ManagerReportsScreenState();
}

class _ManagerReportsScreenState extends State<ManagerReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Date range filters
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Stats
  int _totalPatients = 0;
  int _totalVisits = 0;
  int _totalPrescriptions = 0;
  int _totalLabOrders = 0;
  int _avgWaitTime = 0;
  double _completionRate = 0;
  bool _isLoading = true;

  // Top data
  List<Map<String, dynamic>> _topDiagnoses = [];
  List<Map<String, dynamic>> _topMedications = [];
  List<Map<String, dynamic>> _facilityStats = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllStats();
  }

  Future<void> _loadAllStats() async {
    setState(() => _isLoading = true);

    await Future.wait([
      _loadPatientStats(),
      _loadVisitStats(),
      _loadPrescriptionStats(),
      _loadLabStats(),
      _loadTopDiagnoses(),
      _loadTopMedications(),
      _loadFacilityStats(),
    ]);

    setState(() => _isLoading = false);
  }

  Future<void> _loadPatientStats() async {
    final patients = await FirebaseFirestore.instance
        .collection('patients')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: _startDate.toIso8601String(),
        )
        .where('createdAt', isLessThanOrEqualTo: _endDate.toIso8601String())
        .get();

    setState(() {
      _totalPatients = patients.docs.length;
    });
  }

  Future<void> _loadVisitStats() async {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final visits = await FirebaseFirestore.instance
        .collection('visits')
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .get();

    final completed = visits.docs.where((v) {
      final data = v.data() as Map<String, dynamic>;
      return data['status'] == 'completed';
    }).length;

    setState(() {
      _totalVisits = visits.docs.length;
      _completionRate = _totalVisits > 0 ? (completed / _totalVisits) * 100 : 0;
    });
  }

  Future<void> _loadPrescriptionStats() async {
    final prescriptions = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('createdAt', isGreaterThanOrEqualTo: _startDate)
        .where('createdAt', isLessThanOrEqualTo: _endDate)
        .get();

    setState(() {
      _totalPrescriptions = prescriptions.docs.length;
    });
  }

  Future<void> _loadLabStats() async {
    final labOrders = await FirebaseFirestore.instance
        .collection('lab_orders')
        .where('createdAt', isGreaterThanOrEqualTo: _startDate)
        .where('createdAt', isLessThanOrEqualTo: _endDate)
        .get();

    setState(() {
      _totalLabOrders = labOrders.docs.length;
    });
  }

  Future<void> _loadTopDiagnoses() async {
    final startStr = DateFormat('yyyy-MM-dd').format(_startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(_endDate);

    final visits = await FirebaseFirestore.instance
        .collection('visits')
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .get();

    final Map<String, int> diagnosisCount = {};

    for (var visit in visits.docs) {
      final data = visit.data() as Map<String, dynamic>;
      final diagnosis = data['diagnosis'];
      if (diagnosis != null && diagnosis.toString().isNotEmpty) {
        diagnosisCount[diagnosis] = (diagnosisCount[diagnosis] ?? 0) + 1;
      }
    }

    final sorted = diagnosisCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _topDiagnoses = sorted
          .take(5)
          .map((e) => {'name': e.key, 'count': e.value})
          .toList();
    });
  }

  Future<void> _loadTopMedications() async {
    final prescriptions = await FirebaseFirestore.instance
        .collection('prescriptions')
        .where('createdAt', isGreaterThanOrEqualTo: _startDate)
        .where('createdAt', isLessThanOrEqualTo: _endDate)
        .get();

    final Map<String, int> medCount = {};

    for (var pres in prescriptions.docs) {
      final data = pres.data() as Map<String, dynamic>;
      final medication = data['medication'];
      if (medication != null) {
        medCount[medication] = (medCount[medication] ?? 0) + 1;
      }
    }

    final sorted = medCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    setState(() {
      _topMedications = sorted
          .take(5)
          .map((e) => {'name': e.key, 'count': e.value})
          .toList();
    });
  }

  Future<void> _loadFacilityStats() async {
    final visits = await FirebaseFirestore.instance.collection('visits').get();

    final Map<String, Map<String, dynamic>> facilityData = {};

    for (var visit in visits.docs) {
      final data = visit.data() as Map<String, dynamic>;
      final facilityId = data['facilityId'] ?? 'Unknown';

      if (!facilityData.containsKey(facilityId)) {
        facilityData[facilityId] = {
          'name': data['facilityName'] ?? facilityId,
          'visits': 0,
          'patients': <String>{},
        };
      }

      facilityData[facilityId]!['visits'] =
          (facilityData[facilityId]!['visits'] as int) + 1;
      (facilityData[facilityId]!['patients'] as Set<String>).add(
        data['patientId'],
      );
    }

    setState(() {
      _facilityStats =
          facilityData.entries.map((e) {
            return {
              'name': e.value['name'],
              'visits': e.value['visits'],
              'patients': (e.value['patients'] as Set<String>).length,
            };
          }).toList()..sort(
            (a, b) => (b['visits'] as int).compareTo(a['visits'] as int),
          );
    });
  }

  Future<void> _exportToPDF() async {
    final pdf = pw.Document();

    // Title Page
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Lesotho EHR System',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Clinical Reports Summary',
                style: pw.TextStyle(fontSize: 24),
              ),
              pw.SizedBox(height: 40),
              pw.Text(
                'Period: ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 60),
              pw.Text(
                'Generated by: ${widget.user?.displayName ?? 'System Administrator'}',
                style: pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    // Key Metrics Page
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Key Performance Indicators',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            _buildPDFMetric(
              'Total Patients Registered',
              _totalPatients.toString(),
            ),
            _buildPDFMetric('Total Visits', _totalVisits.toString()),
            _buildPDFMetric(
              'Total Prescriptions',
              _totalPrescriptions.toString(),
            ),
            _buildPDFMetric('Total Lab Orders', _totalLabOrders.toString()),
            _buildPDFMetric(
              'Completion Rate',
              '${_completionRate.toStringAsFixed(1)}%',
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Top Diagnoses',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            ..._topDiagnoses.map(
              (d) => _buildPDFListItem('${d['name']}', '${d['count']} cases'),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Top Medications',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 10),
            ..._topMedications.map(
              (m) => _buildPDFListItem(
                '${m['name']}',
                '${m['count']} prescriptions',
              ),
            ),
          ],
        ),
      ),
    );

    // Facility Performance Page
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Facility Performance',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(),
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Facility',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Visits',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        'Patients',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                ..._facilityStats.map(
                  (f) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(f['name']),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(f['visits'].toString()),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(f['patients'].toString()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // Footer on last page
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Center(
          child: pw.Text(
            'End of Report - Lesotho EHR System',
            style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic),
          ),
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'ehr_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  pw.Widget _buildPDFMetric(String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 14)),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  pw.Widget _buildPDFListItem(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text('• $label'), pw.Text(value)],
      ),
    );
  }

  Future<void> _exportToCSV() async {
    // In a real app, this would generate and share a CSV file
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV export coming soon')));
  }

  void _showDateRangePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAllStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Reports'),
        backgroundColor: Colors.indigo.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showDateRangePicker,
            tooltip: 'Change Date Range',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportToPDF,
            tooltip: 'Export as PDF',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllStats,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Clinical', icon: Icon(Icons.medical_services)),
            Tab(text: 'Facilities', icon: Icon(Icons.location_city)),
            Tab(text: 'Reports', icon: Icon(Icons.description)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildClinicalTab(),
                _buildFacilitiesTab(),
                _buildReportsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Date Range Display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showDateRangePicker,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Change'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPI Cards
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKPICard(
                'Total Patients',
                '$_totalPatients',
                Icons.people,
                Colors.blue,
              ),
              _buildKPICard(
                'Total Visits',
                '$_totalVisits',
                Icons.calendar_today,
                Colors.green,
              ),
              _buildKPICard(
                'Prescriptions',
                '$_totalPrescriptions',
                Icons.local_pharmacy,
                Colors.teal,
              ),
              _buildKPICard(
                'Lab Orders',
                '$_totalLabOrders',
                Icons.science,
                Colors.orange,
              ),
              _buildKPICard(
                'Completion Rate',
                '${_completionRate.toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.purple,
              ),
              _buildKPICard(
                'Avg Wait Time',
                '${_avgWaitTime} min',
                Icons.timer,
                Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trends Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Key Insights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildInsightRow(
                    Icons.trending_up,
                    'Patient Growth',
                    '$_totalPatients patients in this period',
                    _totalPatients > 0
                        ? '+${(_totalPatients / 30).toStringAsFixed(0)} avg/day'
                        : 'No data',
                  ),
                  const Divider(),
                  _buildInsightRow(
                    Icons.local_hospital,
                    'Service Utilization',
                    '$_totalVisits total visits',
                    '${(_totalVisits / 30).toStringAsFixed(1)} visits/day average',
                  ),
                  const Divider(),
                  _buildInsightRow(
                    Icons.check_circle,
                    'Completion Rate',
                    '${_completionRate.toStringAsFixed(1)}% of visits completed',
                    _completionRate > 80
                        ? 'Good performance'
                        : 'Needs improvement',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Top Diagnoses
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Diagnoses',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_topDiagnoses.isEmpty)
                    const Center(child: Text('No diagnosis data available'))
                  else
                    ..._topDiagnoses.asMap().entries.map((entry) {
                      final color = [
                        Colors.blue,
                        Colors.green,
                        Colors.orange,
                        Colors.purple,
                        Colors.teal,
                      ][entry.key];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entry.value['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${entry.value['count']} cases',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '#${entry.key + 1}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Top Medications
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top Prescribed Medications',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_topMedications.isEmpty)
                    const Center(child: Text('No medication data available'))
                  else
                    ..._topMedications.map(
                      (med) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.medication, color: Colors.teal),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                med['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '${med['count']} prescriptions',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
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

  Widget _buildFacilitiesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Facility Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (_facilityStats.isEmpty)
                const Center(child: Text('No facility data available'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _facilityStats.length,
                  itemBuilder: (context, index) {
                    final facility = _facilityStats[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      facility['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${facility['visits']} visits • ${facility['patients']} unique patients',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${((facility['visits'] / _totalVisits) * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(color: Colors.indigo),
                                ),
                              ),
                            ],
                          ),
                          if (index < _facilityStats.length - 1)
                            const Divider(),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.description, size: 80, color: Colors.indigo),
            const SizedBox(height: 24),
            const Text(
              'Generate Reports',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Export data for the period ${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportToPDF,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export as PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportToCSV,
                    icon: const Icon(Icons.table_chart),
                    label: const Text('Export as CSV'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Summary',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('• ${_totalPatients} patients registered'),
                    Text('• ${_totalVisits} clinical visits'),
                    Text('• ${_totalPrescriptions} prescriptions issued'),
                    Text('• ${_totalLabOrders} laboratory orders'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
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
    );
  }

  Widget _buildInsightRow(
    IconData icon,
    String title,
    String value,
    String trend,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            trend,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
