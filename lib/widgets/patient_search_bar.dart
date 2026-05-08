// lib/widgets/patient_search_bar.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PatientSearchBar extends StatefulWidget {
  final Function(String patientId) onPatientSelected;

  const PatientSearchBar({super.key, required this.onPatientSelected});

  @override
  State<PatientSearchBar> createState() => _PatientSearchBarState();
}

class _PatientSearchBarState extends State<PatientSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search patient by name, ID, or phone...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _controller.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _isSearching = value.isNotEmpty;
              });
            },
          ),
          if (_isSearching && _searchQuery.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 4,
                  ),
                ],
              ),
              child: _buildSearchResults(),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final patients = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['displayName'] ?? '').toLowerCase();
          final nationalId = (data['nationalId'] ?? '').toLowerCase();
          final phone = (data['phoneNumber'] ?? '').toLowerCase();
          final query = _searchQuery.toLowerCase();

          return name.contains(query) ||
              nationalId.contains(query) ||
              phone.contains(query);
        }).toList();

        if (patients.isEmpty) {
          return const SizedBox(
            height: 100,
            child: Center(child: Text('No patients found')),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            final data = patient.data() as Map<String, dynamic>;

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(data['displayName'] ?? 'Unknown'),
              subtitle: Text('ID: ${data['nationalId'] ?? 'N/A'}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                setState(() {
                  _isSearching = false;
                  _controller.clear();
                  _searchQuery = '';
                });
                widget.onPatientSelected(patient.id);
              },
            );
          },
        );
      },
    );
  }
}
