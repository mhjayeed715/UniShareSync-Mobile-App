import 'package:flutter/material.dart';
import '../../data/models/alumni_profile_model.dart';
import '../../data/repositories/alumni_repository.dart';

class AlumniFilterSheet extends StatefulWidget {
  final AlumniFilters currentFilters;
  final List<int> availableBatches;
  final Function(AlumniFilters) onApply;

  const AlumniFilterSheet({
    super.key,
    required this.currentFilters,
    required this.availableBatches,
    required this.onApply,
  });

  @override
  State<AlumniFilterSheet> createState() => _AlumniFilterSheetState();
}

class _AlumniFilterSheetState extends State<AlumniFilterSheet> {
  List<int> _selectedBatches = [];
  List<AlumniIndustry> _selectedIndustries = [];
  final TextEditingController _locationController = TextEditingController();
  bool _isOpenToMentor = false;
  List<String> _selectedMentorAreas = [];
  bool _hasLinkedin = false;

  final List<String> _allMentorAreas = [
    "Flutter Development",
    "Machine Learning",
    "Job Interview Prep",
    "Higher Studies Abroad",
    "Startup & Entrepreneurship",
    "Cybersecurity",
    "System Architecture"
  ];

  @override
  void initState() {
    super.initState();
    _selectedBatches = List<int>.from(widget.currentFilters.batchYears ?? []);
    _selectedIndustries = List<AlumniIndustry>.from(widget.currentFilters.industries ?? []);
    _locationController.text = widget.currentFilters.location ?? '';
    _isOpenToMentor = widget.currentFilters.isOpenToMentor ?? false;
    _selectedMentorAreas = List<String>.from(widget.currentFilters.mentorAreas ?? []);
    _hasLinkedin = widget.currentFilters.hasLinkedin ?? false;
  }

  void _clearAll() {
    setState(() {
      _selectedBatches = [];
      _selectedIndustries = [];
      _locationController.clear();
      _isOpenToMentor = false;
      _selectedMentorAreas = [];
      _hasLinkedin = false;
    });
  }

  void _apply() {
    final filters = AlumniFilters(
      batchYears: _selectedBatches.isNotEmpty ? _selectedBatches : null,
      industries: _selectedIndustries.isNotEmpty ? _selectedIndustries : null,
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      isOpenToMentor: _isOpenToMentor ? true : null,
      mentorAreas: _selectedMentorAreas.isNotEmpty ? _selectedMentorAreas : null,
      hasLinkedin: _hasLinkedin ? true : null,
    );
    widget.onApply(filters);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Directory',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Location Search Field
              const Text(
                'Current Location',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _locationController,
                  style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                  decoration: InputDecoration(
                    hintText: 'e.g., Canada, Dhaka, Chittagong',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                    prefixIcon: const Icon(Icons.location_on_rounded, color: Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Mentorship Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Open to Mentorship',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Show only registered mentors',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isOpenToMentor,
                    onChanged: (val) {
                      setState(() {
                        _isOpenToMentor = val;
                      });
                    },
                    activeThumbColor: const Color(0xFFFBBF24),
                    activeTrackColor: const Color(0xFFF59E0B).withOpacity(0.3),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mentor Areas chips (if mentor toggle enabled or general)
              const Text(
                'Mentor Areas',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _allMentorAreas.map((area) {
                  final isSelected = _selectedMentorAreas.contains(area);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedMentorAreas.remove(area);
                        } else {
                          _selectedMentorAreas.add(area);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFBBF24).withOpacity(0.1) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        area,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFD97706) : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Industry Chips
              const Text(
                'Industry Sector',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AlumniIndustry.values.map((ind) {
                  final isSelected = _selectedIndustries.contains(ind);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedIndustries.remove(ind);
                        } else {
                          _selectedIndustries.add(ind);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.3) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        ind.displayName,
                        style: TextStyle(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Batch Chips
              if (widget.availableBatches.isNotEmpty) ...[
                const Text(
                  'Select Batches',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.availableBatches.map((batch) {
                    final isSelected = _selectedBatches.contains(batch);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedBatches.remove(batch);
                          } else {
                            _selectedBatches.add(batch);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2563EB).withOpacity(0.1) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2563EB).withOpacity(0.3) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          'Batch ${batch.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],

              // Has LinkedIn Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Has LinkedIn Profile',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Outfit',
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Show only alumni with a LinkedIn profile',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _hasLinkedin,
                    onChanged: (val) {
                      setState(() {
                        _hasLinkedin = val;
                      });
                    },
                    activeThumbColor: const Color(0xFF2563EB),
                    activeTrackColor: const Color(0xFF2563EB).withOpacity(0.3),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Apply Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
