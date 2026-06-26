import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:unisharesync_mobile_app/features/scheduler/schedule_models.dart';
import 'package:unisharesync_mobile_app/features/scheduler/schedule_repository.dart';
import 'package:unisharesync_mobile_app/services/schedule_service.dart';

class AdminClassSchedulerScreen extends StatefulWidget {
  const AdminClassSchedulerScreen({super.key});

  @override
  State<AdminClassSchedulerScreen> createState() =>
      _AdminClassSchedulerScreenState();
}

class _AdminClassSchedulerScreenState extends State<AdminClassSchedulerScreen> {
  final ScheduleRepository _repository = ScheduleRepository();
  final ScheduleService _syncService = ScheduleService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;

  List<ScheduleEntry> _entries = const <ScheduleEntry>[];
  List<ScheduleTimeSlot> _timeSlots = const <ScheduleTimeSlot>[];
  bool _isOverride = false;
  DateTime? _cachedAt;

  String _dayFilter = _allDaysLabel;
  int? _semesterFilter;
  String? _groupFilter;

  static const String _courseAssetPath =
      'Course Offer Winter 2026 - Course Distribution.csv';

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final remoteEntries = await _syncService.fetchEntries();
      if (!mounted) {
        return;
      }

      if (remoteEntries.isNotEmpty) {
        final timeSlots = _deriveTimeSlots(remoteEntries);
        setState(() {
          _entries = remoteEntries;
          _timeSlots = timeSlots;
          _isOverride = true;
          _cachedAt = DateTime.now();
          _isLoading = false;
        });
        _syncFilters();
        await _repository.saveOverrideSchedule(
          entries: remoteEntries,
          timeSlots: timeSlots,
        );
        return;
      }

      final fallback = await _repository.loadSchedule(preferOverride: false);
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = const <ScheduleEntry>[];
        _timeSlots = fallback.timeSlots;
        _isOverride = false;
        _cachedAt = fallback.cachedAt;
        _isLoading = false;
      });
      _syncFilters();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = '$error';
      });
    }
  }

  void _syncFilters() {
    final semesters = _availableSemesters();
    if (_semesterFilter != null && !semesters.contains(_semesterFilter)) {
      _semesterFilter = null;
    }
    final groups = _availableGroupsForSemester(_semesterFilter);
    if (_groupFilter != null && !groups.contains(_groupFilter)) {
      _groupFilter = null;
    }
  }

  Future<void> _importCsv() async {
    final routineResult = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      withData: kIsWeb,
    );

    if (routineResult == null) {
      return;
    }

    final routineFile = routineResult.files.single;
    String? routinePath;
    String? routineCsv;
    if (kIsWeb) {
      if (routineFile.bytes == null) {
        _showSnackBar('Unable to read routine CSV data.');
        return;
      }
      routineCsv = utf8.decode(routineFile.bytes!);
    } else {
      routinePath = routineFile.path;
      if (routinePath == null) {
        _showSnackBar('Unable to read routine CSV path.');
        return;
      }
    }

    String? coursePath;
    String? courseCsv;

    final attachCourse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach course distribution CSV?'),
        content: const Text(
          'This CSV supplies full course titles and faculty names. You can skip it if you want to reuse the bundled file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Skip'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Attach'),
          ),
        ],
      ),
    );

    if (attachCourse == true) {
      final courseResult = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: kIsWeb,
      );
      if (courseResult != null) {
        final courseFile = courseResult.files.single;
        if (kIsWeb) {
          if (courseFile.bytes == null) {
            _showSnackBar('Unable to read course CSV data.');
            return;
          }
          courseCsv = utf8.decode(courseFile.bytes!);
        } else {
          coursePath = courseFile.path;
          if (coursePath == null) {
            _showSnackBar('Unable to read course CSV path.');
            return;
          }
        }
      }
    }

    try {
      final snapshot = kIsWeb
          ? await _repository.importFromCsvStrings(
              routineCsv: routineCsv!,
              courseCsv: courseCsv ??
                  await rootBundle.loadString(_courseAssetPath),
            )
          : await _repository.importFromFiles(
              routinePath: routinePath!,
              coursePath: coursePath,
            );
      await _syncService.replaceSchedule(snapshot.entries);
      if (!mounted) {
        return;
      }
      await _loadSchedule();
      _showSnackBar('Schedule imported successfully');
    } catch (error) {
      _showSnackBar('Failed to import schedule: $error');
    }
  }

  Future<void> _resetSchedule() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset to bundled schedule'),
        content: const Text(
          'This will discard the custom schedule and restore the bundled CSV data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final snapshot = await _repository.resetToAssets();
      await _syncService.replaceSchedule(snapshot.entries);
      if (!mounted) {
        return;
      }
      await _loadSchedule();
      _showSnackBar('Bundled schedule restored');
    } catch (error) {
      _showSnackBar('Failed to reset schedule: $error');
    }
  }

  Future<void> _addEntry() async {
    final entry = await _showEntryDialog();
    if (entry == null) {
      return;
    }

    try {
      await _syncService.createEntry(entry);
      if (!mounted) {
        return;
      }
      await _loadSchedule();
      _showSnackBar('Schedule entry added');
    } catch (error) {
      _showSnackBar('Failed to add entry: $error');
    }
  }

  Future<void> _editEntry(ScheduleEntry entry) async {
    final updatedEntry = await _showEntryDialog(existing: entry);
    if (updatedEntry == null) {
      return;
    }

    if (updatedEntry.id == null) {
      _showSnackBar('Unable to update entry without an id.');
      return;
    }

    try {
      await _syncService.updateEntry(updatedEntry);
      if (!mounted) {
        return;
      }
      await _loadSchedule();
      _showSnackBar('Schedule entry updated');
    } catch (error) {
      _showSnackBar('Failed to update entry: $error');
    }
  }

  Future<void> _deleteEntry(ScheduleEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete schedule entry'),
        content: Text(
          'Delete ${entry.courseDisplay} on ${entry.day} at ${entry.timeRange}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (entry.id == null) {
      _showSnackBar('Unable to delete entry without an id.');
      return;
    }

    try {
      await _syncService.deleteEntry(entry.id!);
      if (!mounted) {
        return;
      }
      await _loadSchedule();
      _showSnackBar('Schedule entry deleted');
    } catch (error) {
      _showSnackBar('Failed to delete entry: $error');
    }
  }

  Future<ScheduleEntry?> _showEntryDialog({ScheduleEntry? existing}) {
    final sectionController =
        TextEditingController(text: existing?.section ?? '');
    final courseDisplayController =
        TextEditingController(text: existing?.courseDisplay ?? '');
    final courseTitleController =
        TextEditingController(text: existing?.courseTitle ?? '');
    final courseCodeController =
        TextEditingController(text: existing?.courseCode ?? '');
    final facultyInitialController =
        TextEditingController(text: existing?.facultyInitial ?? '');
    final facultyNameController =
        TextEditingController(text: existing?.facultyName ?? '');
    final roomController = TextEditingController(text: existing?.room ?? '');

    final timeOptions =
        _timeSlots.map((slot) => slot.label).toList(growable: false);
    final hasMatch = existing != null && timeOptions.contains(existing.timeRange);
    final customController = TextEditingController(
      text: existing?.timeRange ?? '',
    );
    var selectedDay = existing?.day ?? _dayOptions.first;
    var selectedTime = hasMatch ? existing.timeRange : _customTimeLabel;
    var errorMessage = '';

    return showDialog<ScheduleEntry>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Schedule Entry' : 'Edit Entry'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      errorMessage,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: selectedDay,
                  decoration: _dialogDecoration('Day'),
                  items: _dayOptions
                      .map(
                        (day) => DropdownMenuItem<String>(
                          value: day,
                          child: Text(day),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedDay = value;
                    });
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedTime,
                  decoration: _dialogDecoration('Time Slot'),
                  items: [
                    ...timeOptions.map(
                      (slot) => DropdownMenuItem<String>(
                        value: slot,
                        child: Text(slot),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: _customTimeLabel,
                      child: Text('Custom'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }
                    setDialogState(() {
                      selectedTime = value;
                    });
                  },
                ),
                if (selectedTime == _customTimeLabel) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: customController,
                    decoration: _dialogDecoration('Custom Time Range'),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: sectionController,
                  decoration: _dialogDecoration('Section (e.g. 9A)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: courseDisplayController,
                  decoration: _dialogDecoration('Course Display'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: courseCodeController,
                  decoration: _dialogDecoration('Course Code'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: courseTitleController,
                  decoration: _dialogDecoration('Course Title'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: facultyInitialController,
                  decoration: _dialogDecoration('Faculty Initial'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: facultyNameController,
                  decoration: _dialogDecoration('Faculty Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: roomController,
                  decoration: _dialogDecoration('Room'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final courseDisplay = courseDisplayController.text.trim();
                if (courseDisplay.isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Course display is required.';
                  });
                  return;
                }

                final timeRange = selectedTime == _customTimeLabel
                    ? customController.text.trim()
                    : selectedTime;
                if (timeRange.trim().isEmpty) {
                  setDialogState(() {
                    errorMessage = 'Time range is required.';
                  });
                  return;
                }

                final slot = _timeSlots
                    .where((slot) => slot.label == timeRange)
                    .toList();
                final parsed = slot.isNotEmpty
                    ? _TimeRange(slot.first.startMinutes, slot.first.endMinutes)
                    : _tryParseTimeRange(timeRange);
                if (parsed == null || parsed.endMinutes <= parsed.startMinutes) {
                  setDialogState(() {
                    errorMessage = 'Use a valid time range like 8.30 AM - 9.50 AM.';
                  });
                  return;
                }

                final section = sectionController.text.trim();
                final semester = _parseSemester(section);
                final group = _parseGroup(section);

                final codeInput = courseCodeController.text.trim();
                final derivedCode =
                    _extractCourseCode(courseDisplay) ?? courseDisplay;
                final courseCode = codeInput.isEmpty ? derivedCode : codeInput;
                final titleInput = courseTitleController.text.trim();
                final courseTitle = titleInput.isEmpty
                    ? courseDisplay
                    : titleInput;

                final entry = ScheduleEntry(
                  id: existing?.id,
                  day: selectedDay,
                  section: section.isEmpty ? 'All' : section,
                  semester: semester,
                  group: group,
                  courseCode: courseCode,
                  courseDisplay: courseDisplay,
                  courseTitle: courseTitle,
                  facultyInitial: facultyInitialController.text.trim().toUpperCase(),
                  facultyName: facultyNameController.text.trim(),
                  room: roomController.text.trim(),
                  timeRange: timeRange,
                  startMinutes: parsed.startMinutes,
                  endMinutes: parsed.endMinutes,
                );

                Navigator.pop(context, entry);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  List<ScheduleEntry> _filteredEntries() {
    final query = _searchController.text.trim().toLowerCase();

    final results = _entries.where((entry) {
      if (_dayFilter != _allDaysLabel && entry.day != _dayFilter) {
        return false;
      }
      if (_semesterFilter != null && entry.semester != _semesterFilter) {
        return false;
      }
      if (_groupFilter != null && entry.group != _groupFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = [
        entry.courseDisplay,
        entry.courseTitle,
        entry.courseCode,
        entry.facultyInitial,
        entry.facultyName,
        entry.room,
        entry.section,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    results.sort((a, b) {
      final dayCompare = _dayIndex(a.day).compareTo(_dayIndex(b.day));
      if (dayCompare != 0) {
        return dayCompare;
      }
      return a.startMinutes.compareTo(b.startMinutes);
    });

    return results;
  }

  int _dayIndex(String value) {
    final index = _dayOptions.indexOf(value);
    return index == -1 ? 999 : index;
  }

  List<int> _availableSemesters() {
    final semesters = _entries
        .map((entry) => entry.semester)
        .whereType<int>()
        .toSet()
        .toList();
    semesters.sort();
    return semesters;
  }

  List<String> _availableGroupsForSemester(int? semester) {
    final groups = _entries
        .where(
          (entry) => semester == null || entry.semester == semester,
        )
        .map((entry) => entry.group)
        .whereType<String>()
        .toSet()
        .toList();
    groups.sort();
    return groups;
  }

  List<ScheduleTimeSlot> _deriveTimeSlots(List<ScheduleEntry> entries) {
    final slots = <String, ScheduleTimeSlot>{};
    for (final entry in entries) {
      slots.putIfAbsent(
        entry.timeRange,
        () => ScheduleTimeSlot(
          label: entry.timeRange,
          startMinutes: entry.startMinutes,
          endMinutes: entry.endMinutes,
        ),
      );
    }
    final values = slots.values.toList();
    values.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    return values;
  }

  String? _extractCourseCode(String value) {
    final match = RegExp(r'([A-Z]{2,4})\s*(\d{4})').firstMatch(value);
    if (match == null) {
      return null;
    }
    return '${match.group(1)} ${match.group(2)}';
  }

  int? _parseSemester(String section) {
    final match = RegExp(r'^(\d+)').firstMatch(section);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  String? _parseGroup(String section) {
    final match = RegExp(r'^\d+\s*([A-Z].*)').firstMatch(section);
    if (match == null) {
      return null;
    }
    return match.group(1)?.trim();
  }

  _TimeRange? _tryParseTimeRange(String value) {
    final parts = value.split('-');
    if (parts.length < 2) {
      return null;
    }
    final start = _parseTime(parts[0]);
    final end = _parseTime(parts[1]);
    if (start == null || end == null) {
      return null;
    }
    return _TimeRange(start, end);
  }

  int? _parseTime(String value) {
    final normalized = value
        .replaceAll('.', ':')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final match = RegExp(r'(\d{1,2})[:](\d{2})\s*(AM|PM)',
            caseSensitive: false)
        .firstMatch(normalized);
    if (match == null) {
      return null;
    }

    var hour = int.tryParse(match.group(1) ?? '') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final meridiem = (match.group(3) ?? '').toUpperCase();

    if (meridiem == 'PM' && hour != 12) {
      hour += 12;
    } else if (meridiem == 'AM' && hour == 12) {
      hour = 0;
    }

    return (hour * 60) + minute;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEntries();
    final semesters = _availableSemesters();
    final groups = _availableGroupsForSemester(_semesterFilter);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Manage Class Scheduler',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _resetSchedule,
            icon: const Icon(Icons.restore_rounded),
            tooltip: 'Reset to bundled schedule',
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFEAF6FF),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4F9EFF).withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Column(
                    children: [
                      _AdminStatusBanner(
                        isOverride: _isOverride,
                        cachedAt: _cachedAt,
                        totalEntries: _entries.length,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _importCsv,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Import CSV'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _addEntry,
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add Entry'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(
                                  color: Color(0xFF2563EB),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by course, faculty, room, or section',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _dayFilter,
                              decoration: _filterDecoration('Day'),
                              items: [
                                const DropdownMenuItem<String>(
                                  value: _allDaysLabel,
                                  child: Text('All Days'),
                                ),
                                ..._dayOptions.map(
                                  (day) => DropdownMenuItem<String>(
                                    value: day,
                                    child: Text(day),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) {
                                  return;
                                }
                                setState(() {
                                  _dayFilter = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              initialValue: _semesterFilter,
                              decoration: _filterDecoration('Semester'),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('All Semesters'),
                                ),
                                ...semesters.map(
                                  (semester) => DropdownMenuItem<int?>(
                                    value: semester,
                                    child: Text('Semester $semester'),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _semesterFilter = value;
                                  _groupFilter = null;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: _groupFilter,
                        decoration: _filterDecoration('Group'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Groups'),
                          ),
                          ...groups.map(
                            (group) => DropdownMenuItem<String?>(
                              value: group,
                              child: Text('Group $group'),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _groupFilter = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? _AdminErrorState(
                              message: _errorMessage!,
                              onRetry: _loadSchedule,
                            )
                          : filtered.isEmpty
                              ? const _AdminEmptyState(
                                  message: 'No schedule entries found.',
                                )
                              : RefreshIndicator(
                                  onRefresh: _loadSchedule,
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 16),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final entry = filtered[index];
                                      return _AdminEntryCard(
                                        entry: entry,
                                        onEdit: () => _editEntry(entry),
                                        onDelete: () => _deleteEntry(entry),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }
}

class _AdminStatusBanner extends StatelessWidget {
  const _AdminStatusBanner({
    required this.isOverride,
    required this.cachedAt,
    required this.totalEntries,
  });

  final bool isOverride;
  final DateTime? cachedAt;
  final int totalEntries;

  @override
  Widget build(BuildContext context) {
    final statusText = isOverride
        ? 'Custom schedule active'
        : 'Bundled schedule active';
    final timestamp = cachedAt == null
        ? ''
        : 'Updated ${_formatTimestamp(cachedAt!)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F9EFF).withOpacity(0.1),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isOverride
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOverride
                  ? Icons.edit_calendar_rounded
                  : Icons.calendar_month_rounded,
              color: isOverride
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (timestamp.isNotEmpty)
                  Text(
                    timestamp,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$totalEntries entries',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.day}/${value.month}/${value.year} $hour:$minute';
  }
}

class _AdminEntryCard extends StatelessWidget {
  const _AdminEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  final ScheduleEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final teacher = entry.facultyName.isNotEmpty
        ? entry.facultyName
        : entry.facultyInitial;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.courseDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_rounded),
                tooltip: 'Delete',
                color: const Color(0xFFEF4444),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _EntryInfoChip(label: entry.day),
              _EntryInfoChip(label: entry.timeRange),
              _EntryInfoChip(
                label: entry.room.isNotEmpty ? entry.room : 'TBA',
              ),
              if (teacher.isNotEmpty) _EntryInfoChip(label: teacher),
              if (entry.section.isNotEmpty)
                _EntryInfoChip(label: 'Section ${entry.section}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EntryInfoChip extends StatelessWidget {
  const _EntryInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF1D4ED8),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AdminErrorState extends StatelessWidget {
  const _AdminErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminEmptyState extends StatelessWidget {
  const _AdminEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TimeRange {
  const _TimeRange(this.startMinutes, this.endMinutes);

  final int startMinutes;
  final int endMinutes;
}

const String _allDaysLabel = 'All';
const String _customTimeLabel = '__custom__';

const List<String> _dayOptions = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];
