import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unisharesync_mobile_app/services/schedule_service.dart';

import 'schedule_models.dart';
import 'schedule_repository.dart';

class ClassSchedulerScreen extends StatefulWidget {
  const ClassSchedulerScreen({super.key});

  @override
  State<ClassSchedulerScreen> createState() => _ClassSchedulerScreenState();
}

class _ClassSchedulerScreenState extends State<ClassSchedulerScreen> {
  final ScheduleRepository _repository = ScheduleRepository();
  final ScheduleService _scheduleService = ScheduleService();
  final TextEditingController _roomSearchController = TextEditingController();
  final ScrollController _studentGridScrollController = ScrollController();
  final ScrollController _facultyGridScrollController = ScrollController();

  Timer? _clockTicker;
  StreamSubscription<List<ScheduleEntry>>? _scheduleSubscription;
  DateTime _now = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;
  bool _fromCache = false;
  bool _isOverride = false;
  DateTime? _cachedAt;

  bool _useStudentGridView = false;
  bool _useFacultyGridView = false;

  List<ScheduleEntry> _entries = const <ScheduleEntry>[];
  List<ScheduleTimeSlot> _timeSlots = const <ScheduleTimeSlot>[];

  int? _selectedSemester;
  String? _selectedGroup;
  String _studentDayFilter = _allDaysLabel;

  String? _selectedFacultyInitial;
  String _facultyDayFilter = _allDaysLabel;

  String? _selectedRoomDay;
  String? _selectedRoomSlotLabel;

  @override
  void initState() {
    super.initState();
    _loadViewPreference();
    _loadSchedule();
    _startClockTicker();
    _startScheduleStream();
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _scheduleSubscription?.cancel();
    _roomSearchController.dispose();
    _studentGridScrollController.dispose();
    _facultyGridScrollController.dispose();
    super.dispose();
  }

  void _startClockTicker() {
    _clockTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final useStudentGrid =
        prefs.getBool(_studentViewPreferenceKey) ?? false;
    final useFacultyGrid =
        prefs.getBool(_facultyViewPreferenceKey) ?? false;
    if (!mounted) {
      return;
    }
    setState(() {
      _useStudentGridView = useStudentGrid;
      _useFacultyGridView = useFacultyGrid;
    });
  }

  Future<void> _setStudentViewPreference(bool useGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_studentViewPreferenceKey, useGrid);
  }

  Future<void> _setFacultyViewPreference(bool useGrid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_facultyViewPreferenceKey, useGrid);
  }

  void _startScheduleStream() {
    _scheduleSubscription = _scheduleService.watchEntries().listen(
      (entries) async {
        if (!mounted) {
          return;
        }

        final timeSlots = _deriveTimeSlots(entries, fallback: _timeSlots);

        setState(() {
          _entries = entries;
          _timeSlots = timeSlots;
          _fromCache = false;
          _isOverride = true;
          _cachedAt = DateTime.now();
          _errorMessage = null;
        });
        _initFilters();

        await _repository.saveOverrideSchedule(
          entries: entries,
          timeSlots: timeSlots,
        );
      },
      onError: (_) {},
    );
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _repository.loadSchedule();
      if (!mounted) {
        return;
      }

      setState(() {
        _entries = snapshot.entries;
        _timeSlots = snapshot.timeSlots;
        _fromCache = snapshot.fromCache;
        _isOverride = snapshot.isOverride;
        _cachedAt = snapshot.cachedAt;
        _isLoading = false;
        _errorMessage = null;
        _initFilters();
      });
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

  void _initFilters() {
    final semesters = _availableSemesters();
    if (_selectedSemester == null || !semesters.contains(_selectedSemester)) {
      _selectedSemester = semesters.isNotEmpty ? semesters.first : null;
    }

    final groups = _availableGroupsForSemester(_selectedSemester);
    if (_selectedGroup == null || !groups.contains(_selectedGroup)) {
      _selectedGroup = groups.isNotEmpty ? groups.first : null;
    }

    final facultyOptions = _facultyOptions();
    if (_selectedFacultyInitial == null ||
        !facultyOptions
            .map((option) => option.initial)
            .contains(_selectedFacultyInitial)) {
      _selectedFacultyInitial =
          facultyOptions.isNotEmpty ? facultyOptions.first.initial : null;
    }

    final availableDays = _availableDays();
    final today = _currentDayLabel();
    if (_selectedRoomDay == null || !availableDays.contains(_selectedRoomDay)) {
      _selectedRoomDay = (today != null && availableDays.contains(today))
          ? today
          : (availableDays.isNotEmpty ? availableDays.first : null);
    }

    if (_selectedRoomSlotLabel == null ||
        !_timeSlots
            .map((slot) => slot.label)
            .contains(_selectedRoomSlotLabel)) {
      _selectedRoomSlotLabel = _findCurrentSlotLabel();
    }
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
    if (semester == null) {
      return const [];
    }
    final groups = _entries
        .where((entry) => entry.semester == semester)
        .map((entry) => entry.group)
        .whereType<String>()
        .toSet()
        .toList();
    groups.sort();
    return groups;
  }

  List<FacultyOption> _facultyOptions() {
    final map = <String, String>{};
    for (final entry in _entries) {
      final initial = entry.facultyInitial.trim();
      if (initial.isEmpty) {
        continue;
      }
      map.putIfAbsent(initial, () => entry.facultyName.trim());
    }

    final options = map.entries
        .map((entry) => FacultyOption(initial: entry.key, name: entry.value))
        .toList();
    options.sort((a, b) => a.initial.compareTo(b.initial));
    return options;
  }

  List<String> _availableDays() {
    final available = _entries.map((entry) => entry.day).toSet();
    return _dayOrder.where(available.contains).toList(growable: false);
  }

  String? _currentDayLabel() {
    return switch (_now.weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => null,
    };
  }

  int _currentMinutes() => (_now.hour * 60) + _now.minute;

  String? _findCurrentSlotLabel() {
    if (_timeSlots.isEmpty) {
      return null;
    }

    final nowMinutes = _currentMinutes();
    for (final slot in _timeSlots) {
      if (nowMinutes >= slot.startMinutes && nowMinutes < slot.endMinutes) {
        return slot.label;
      }
    }
    return _timeSlots.first.label;
  }

  List<ScheduleEntry> _filterStudentEntries() {
    return _entries.where((entry) {
      if (_selectedSemester != null && entry.semester != _selectedSemester) {
        return false;
      }
      if (_selectedGroup != null && entry.group != _selectedGroup) {
        return false;
      }
      if (_studentDayFilter != _allDaysLabel &&
          entry.day != _studentDayFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  List<ScheduleEntry> _filterFacultyEntries() {
    return _entries.where((entry) {
      if (_selectedFacultyInitial != null &&
          entry.facultyInitial != _selectedFacultyInitial) {
        return false;
      }
      if (_facultyDayFilter != _allDaysLabel &&
          entry.day != _facultyDayFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _isOngoing(ScheduleEntry entry) {
    final today = _currentDayLabel();
    if (today == null || entry.day != today) {
      return false;
    }
    final nowMinutes = _currentMinutes();
    return nowMinutes >= entry.startMinutes && nowMinutes < entry.endMinutes;
  }

  List<String> _allRooms() {
    final rooms = _entries
        .map((entry) => entry.room)
        .where(_isPhysicalRoom)
        .toSet()
        .toList();
    rooms.sort();
    return rooms;
  }

  bool _isPhysicalRoom(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return trimmed.toLowerCase() != 'online';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _EmptyState(
        title: 'Unable to load schedule',
        subtitle: _errorMessage ?? 'Please try again later.',
        onRetry: _loadSchedule,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const _SchedulerHeader(),
        if (_isOverride || _fromCache) ...[
          const SizedBox(height: 8),
          _isOverride
              ? _OverrideIndicator(cachedAt: _cachedAt)
              : _OfflineIndicator(cachedAt: _cachedAt),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _SchedulerTabs(),
                const SizedBox(height: 10),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildStudentTab(),
                      _buildFacultyTab(),
                      _buildRoomAvailabilityTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentTab() {
    final entries = _filterStudentEntries();
    if (_useStudentGridView) {
      return _buildStudentGrid(entries);
    }

    final dayGroups = _groupByDay(entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
      children: [
        _buildStudentFilters(),
        const SizedBox(height: 12),
        _buildStudentViewToggle(),
        const SizedBox(height: 12),
        _buildDayChips(
          selectedDay: _studentDayFilter,
          onSelected: (value) {
            setState(() {
              _studentDayFilter = value;
            });
          },
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const _SectionEmptyState(
            message: 'No classes found for this semester and group.',
          )
        else
          ..._buildDaySections(dayGroups, showSection: false),
      ],
    );
  }

  Widget _buildFacultyTab() {
    final entries = _filterFacultyEntries();
    if (_useFacultyGridView) {
      return _buildFacultyGrid(entries);
    }

    final dayGroups = _groupByDay(entries);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
      children: [
        _buildFacultyFilters(),
        const SizedBox(height: 12),
        _buildFacultyViewToggle(),
        const SizedBox(height: 12),
        _buildDayChips(
          selectedDay: _facultyDayFilter,
          onSelected: (value) {
            setState(() {
              _facultyDayFilter = value;
            });
          },
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          const _SectionEmptyState(
            message: 'No classes found for this faculty selection.',
          )
        else
          ..._buildDaySections(dayGroups, showSection: true),
      ],
    );
  }

  Widget _buildRoomAvailabilityTab() {
    final dayOptions = _availableDays();
    final selectedDay = _selectedRoomDay ??
        (dayOptions.isNotEmpty ? dayOptions.first : null);
    final selectedSlotLabel = _selectedRoomSlotLabel ??
        (_timeSlots.isNotEmpty ? _timeSlots.first.label : null);

    final slotEntries = _entries.where((entry) {
      if (selectedDay != null && entry.day != selectedDay) {
        return false;
      }
      if (selectedSlotLabel != null && entry.timeRange != selectedSlotLabel) {
        return false;
      }
      return true;
    }).toList();

    final occupiedMap = <String, List<ScheduleEntry>>{};
    for (final entry in slotEntries) {
      if (!_isPhysicalRoom(entry.room)) {
        continue;
      }
      occupiedMap.putIfAbsent(entry.room, () => []).add(entry);
    }

    final allRooms = _allRooms();
    final occupiedRooms = occupiedMap.keys.toList()..sort();
    final availableRooms = allRooms
        .where((room) => !occupiedMap.containsKey(room))
        .toList(growable: false);

    final query = _roomSearchController.text.trim().toLowerCase();
    final filteredOccupiedRooms = query.isEmpty
        ? occupiedRooms
        : occupiedRooms
            .where((room) => room.toLowerCase().contains(query))
            .toList();
    final filteredAvailableRooms = query.isEmpty
        ? availableRooms
        : availableRooms
            .where((room) => room.toLowerCase().contains(query))
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
      children: [
        _buildRoomFilters(
          dayOptions: dayOptions,
          selectedDay: selectedDay,
          selectedSlotLabel: selectedSlotLabel,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final occupiedSection = _buildOccupiedRoomsSection(
              rooms: filteredOccupiedRooms,
              occupiedMap: occupiedMap,
            );
            final availableSection = _buildAvailableRoomsSection(
              rooms: filteredAvailableRooms,
            );

            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: occupiedSection),
                  const SizedBox(width: 16),
                  Expanded(child: availableSection),
                ],
              );
            }

            return Column(
              children: [
                occupiedSection,
                const SizedBox(height: 16),
                availableSection,
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildStudentFilters() {
    final semesters = _availableSemesters();
    final groups = _availableGroupsForSemester(_selectedSemester);

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: _selectedSemester,
            decoration: _dropdownDecoration('Semester'),
            items: semesters
                .map(
                  (semester) => DropdownMenuItem<int>(
                    value: semester,
                    child: Text('Semester $semester'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedSemester = value;
                _selectedGroup = _availableGroupsForSemester(value).isNotEmpty
                    ? _availableGroupsForSemester(value).first
                    : null;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGroup,
            decoration: _dropdownDecoration('Group'),
            items: groups
                .map(
                  (group) => DropdownMenuItem<String>(
                    value: group,
                    child: Text('Group $group'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedGroup = value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStudentViewToggle() {
    return Row(
      children: [
        _ViewToggleChip(
          label: 'List',
          selected: !_useStudentGridView,
          onTap: () {
            setState(() {
              _useStudentGridView = false;
            });
            _setStudentViewPreference(false);
          },
        ),
        const SizedBox(width: 8),
        _ViewToggleChip(
          label: 'Grid',
          selected: _useStudentGridView,
          onTap: () {
            setState(() {
              _useStudentGridView = true;
            });
            _setStudentViewPreference(true);
          },
        ),
      ],
    );
  }

  Widget _buildFacultyViewToggle() {
    return Row(
      children: [
        _ViewToggleChip(
          label: 'List',
          selected: !_useFacultyGridView,
          onTap: () {
            setState(() {
              _useFacultyGridView = false;
            });
            _setFacultyViewPreference(false);
          },
        ),
        const SizedBox(width: 8),
        _ViewToggleChip(
          label: 'Grid',
          selected: _useFacultyGridView,
          onTap: () {
            setState(() {
              _useFacultyGridView = true;
            });
            _setFacultyViewPreference(true);
          },
        ),
      ],
    );
  }

  Widget _buildStudentGrid(List<ScheduleEntry> entries) {
    final dayOptions = _studentDayFilter == _allDaysLabel
        ? _dayOrder
        : <String>[_studentDayFilter];
    final timeSlots = _timeSlots;
    final cellMap = _buildGridCellMap(entries);
    final isCompact = MediaQuery.of(context).size.width < 600;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
      children: [
        _buildStudentFilters(),
        const SizedBox(height: 12),
        _buildStudentViewToggle(),
        const SizedBox(height: 12),
        _buildDayChips(
          selectedDay: _studentDayFilter,
          onSelected: (value) {
            setState(() {
              _studentDayFilter = value;
            });
          },
        ),
        const SizedBox(height: 14),
        if (isCompact)
          const _GridHint(text: 'Swipe horizontally to view all time slots.'),
        if (isCompact) const SizedBox(height: 8),
        if (entries.isEmpty || timeSlots.isEmpty)
          const _SectionEmptyState(
            message: 'No classes found for this semester and group.',
          )
        else
          _buildGridTable(
            days: dayOptions,
            slots: timeSlots,
            cellMap: cellMap,
            showSection: false,
            controller: _studentGridScrollController,
          ),
      ],
    );
  }

  Widget _buildFacultyGrid(List<ScheduleEntry> entries) {
    final dayOptions = _facultyDayFilter == _allDaysLabel
        ? _dayOrder
        : <String>[_facultyDayFilter];
    final timeSlots = _timeSlots;
    final cellMap = _buildGridCellMap(entries);
    final isCompact = MediaQuery.of(context).size.width < 600;

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 118),
      children: [
        _buildFacultyFilters(),
        const SizedBox(height: 12),
        _buildFacultyViewToggle(),
        const SizedBox(height: 12),
        _buildDayChips(
          selectedDay: _facultyDayFilter,
          onSelected: (value) {
            setState(() {
              _facultyDayFilter = value;
            });
          },
        ),
        const SizedBox(height: 14),
        if (isCompact)
          const _GridHint(text: 'Swipe horizontally to view all time slots.'),
        if (isCompact) const SizedBox(height: 8),
        if (entries.isEmpty || timeSlots.isEmpty)
          const _SectionEmptyState(
            message: 'No classes found for this faculty selection.',
          )
        else
          _buildGridTable(
            days: dayOptions,
            slots: timeSlots,
            cellMap: cellMap,
            showSection: true,
            controller: _facultyGridScrollController,
          ),
      ],
    );
  }

  Map<String, Map<String, List<ScheduleEntry>>> _buildGridCellMap(
    List<ScheduleEntry> entries,
  ) {
    final map = <String, Map<String, List<ScheduleEntry>>>{};
    for (final entry in entries) {
      map.putIfAbsent(entry.day, () => <String, List<ScheduleEntry>>{});
      map[entry.day]!.putIfAbsent(entry.timeRange, () => []).add(entry);
    }
    return map;
  }

  Widget _buildGridTable({
    required List<String> days,
    required List<ScheduleTimeSlot> slots,
    required Map<String, Map<String, List<ScheduleEntry>>> cellMap,
    required bool showSection,
    required ScrollController controller,
  }) {
    final isCompact = MediaQuery.of(context).size.width < 600;
    final dayWidth = isCompact ? 96.0 : 110.0;
    final slotWidth = isCompact ? 160.0 : 180.0;

    final totalWidth = dayWidth + (slots.length * slotWidth);
    final columnWidths = <int, TableColumnWidth>{
      0: FixedColumnWidth(dayWidth),
    };
    for (var i = 0; i < slots.length; i++) {
      columnWidths[i + 1] = FixedColumnWidth(slotWidth);
    }

    final headerRow = TableRow(
      children: [
        _GridHeaderCell(label: 'Day', compact: isCompact),
        ...slots
            .map((slot) => _GridHeaderCell(label: slot.label, compact: isCompact)),
      ],
    );

    final bodyRows = days.map(
      (day) {
        final rowCells = <Widget>[_GridDayCell(label: day, compact: isCompact)];
        for (final slot in slots) {
          final cellEntries =
              cellMap[day]?[slot.label] ?? const <ScheduleEntry>[];
          final highlight = cellEntries.any(_isOngoing);
          rowCells.add(
            _GridEntryCell(
              entries: cellEntries,
              highlight: highlight,
              showSection: showSection,
              compact: isCompact,
            ),
          );
        }
        return TableRow(children: rowCells);
      },
    );

    return Scrollbar(
      controller: controller,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: controller,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: totalWidth,
          child: Table(
            columnWidths: columnWidths,
            border: TableBorder.all(color: const Color(0xFFE2E8F0)),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              headerRow,
              ...bodyRows,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyFilters() {
    final facultyOptions = _facultyOptions();

    return DropdownButtonFormField<String>(
      initialValue: _selectedFacultyInitial,
      decoration: _dropdownDecoration('Faculty'),
      items: facultyOptions
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.initial,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        setState(() {
          _selectedFacultyInitial = value;
        });
      },
    );
  }

  Widget _buildRoomFilters({
    required List<String> dayOptions,
    required String? selectedDay,
    required String? selectedSlotLabel,
  }) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            final dayField = DropdownButtonFormField<String>(
              initialValue: selectedDay,
              decoration: _dropdownDecoration('Day'),
              items: dayOptions
                  .map(
                    (day) => DropdownMenuItem<String>(
                      value: day,
                      child: Text(day),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _selectedRoomDay = value;
                });
              },
            );
            final slotField = DropdownButtonFormField<String>(
              initialValue: selectedSlotLabel,
              decoration: _dropdownDecoration('All Times'),
              items: _timeSlots
                  .map(
                    (slot) => DropdownMenuItem<String>(
                      value: slot.label,
                      child: Text(slot.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                setState(() {
                  _selectedRoomSlotLabel = value;
                });
              },
            );

            if (isNarrow) {
              return Column(
                children: [
                  dayField,
                  const SizedBox(height: 10),
                  slotField,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: dayField),
                const SizedBox(width: 10),
                Expanded(child: slotField),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _roomSearchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search room',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dropdownDecoration(String label) {
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

  Widget _buildDayChips({
    required String selectedDay,
    required ValueChanged<String> onSelected,
  }) {
    final dayOptions = <String>[_allDaysLabel, ..._availableDays()];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: dayOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = dayOptions[index];
          final isSelected = day == selectedDay;
          return ChoiceChip(
            label: Text(day),
            selected: isSelected,
            selectedColor: _SchedulerPalette.accent,
            backgroundColor: Colors.white.withOpacity(0.9),
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
            onSelected: (_) => onSelected(day),
          );
        },
      ),
    );
  }

  Map<String, List<ScheduleEntry>> _groupByDay(List<ScheduleEntry> entries) {
    final grouped = <String, List<ScheduleEntry>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(entry.day, () => []).add(entry);
    }
    for (final day in grouped.keys) {
      grouped[day]!.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    }
    return grouped;
  }

  List<ScheduleTimeSlot> _deriveTimeSlots(
    List<ScheduleEntry> entries, {
    required List<ScheduleTimeSlot> fallback,
  }) {
    if (entries.isEmpty) {
      return fallback;
    }

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

  List<Widget> _buildDaySections(
    Map<String, List<ScheduleEntry>> groupedEntries, {
    required bool showSection,
  }) {
    final sections = <Widget>[];
    for (final day in _dayOrder) {
      final items = groupedEntries[day] ?? const <ScheduleEntry>[];
      if (items.isEmpty) {
        continue;
      }
      sections.add(_DaySection(
        day: day,
        entries: items,
        showSection: showSection,
        isOngoing: _isOngoing,
      ));
      sections.add(const SizedBox(height: 14));
    }
    if (sections.isNotEmpty) {
      sections.removeLast();
    }
    return sections;
  }

  Widget _buildOccupiedRoomsSection({
    required List<String> rooms,
    required Map<String, List<ScheduleEntry>> occupiedMap,
  }) {
    return _RoomPanel(
      title: 'Occupied (${rooms.length})',
      color: const Color(0xFFFEE2E2),
      child: rooms.isEmpty
          ? const _SectionEmptyState(message: 'No occupied rooms found.')
          : Column(
              children: rooms
                  .map(
                    (room) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OccupiedRoomCard(
                        room: room,
                        entries: occupiedMap[room] ?? const <ScheduleEntry>[],
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildAvailableRoomsSection({required List<String> rooms}) {
    return _RoomPanel(
      title: 'Available (${rooms.length})',
      color: const Color(0xFFDCFCE7),
      child: rooms.isEmpty
          ? const _SectionEmptyState(message: 'No available rooms found.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: rooms
                  .map((room) => _AvailableRoomChip(room: room))
                  .toList(growable: false),
            ),
    );
  }
}

class _SchedulerPalette {
  static const Color accent = Color(0xFF2563EB);
}

class _SchedulerHeader extends StatelessWidget {
  const _SchedulerHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Routine Viewer',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'View schedules by student, faculty, or room availability.',
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OfflineIndicator extends StatelessWidget {
  const _OfflineIndicator({required this.cachedAt});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final cachedText = cachedAt == null
        ? 'Offline mode - cached schedule'
        : 'Offline mode - cached at ${_formatTimestamp(cachedAt!)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFFB91C1C)),
          const SizedBox(width: 6),
          Text(
            cachedText,
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w700,
              fontSize: 12,
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

class _OverrideIndicator extends StatelessWidget {
  const _OverrideIndicator({required this.cachedAt});

  final DateTime? cachedAt;

  @override
  Widget build(BuildContext context) {
    final cachedText = cachedAt == null
        ? 'Custom schedule active'
        : 'Custom schedule updated at ${_OfflineIndicator._formatTimestamp(cachedAt!)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.edit_calendar_rounded,
              size: 16, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 6),
          Text(
            cachedText,
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SchedulerTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      child: const TabBar(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: _SchedulerPalette.accent,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFF475569),
        labelStyle: TextStyle(fontWeight: FontWeight.w700),
        tabs: [
          Tab(text: 'Student'),
          Tab(text: 'Faculty'),
          Tab(text: 'Room Availability'),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.entries,
    required this.showSection,
    required this.isOngoing,
  });

  final String day;
  final List<ScheduleEntry> entries;
  final bool showSection;
  final bool Function(ScheduleEntry) isOngoing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          day,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 8),
        ...entries
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ScheduleCard(
                  entry: entry,
                  showSection: showSection,
                  highlight: isOngoing(entry),
                ),
              ),
            )
            ,
      ],
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.entry,
    required this.highlight,
    required this.showSection,
  });

  final ScheduleEntry entry;
  final bool highlight;
  final bool showSection;

  @override
  Widget build(BuildContext context) {
    final teacher = entry.facultyName.isNotEmpty
        ? entry.facultyName
        : entry.facultyInitial;
    final showTitle =
        entry.courseTitle.isNotEmpty && entry.courseTitle != entry.courseDisplay;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? const Color(0xFFEFF6FF)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? _SchedulerPalette.accent : Colors.white,
        ),
        boxShadow: [
          BoxShadow(
            color: _SchedulerPalette.accent.withOpacity(0.08),
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
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (highlight) _NowChip(),
            ],
          ),
          if (showTitle) ...[
            const SizedBox(height: 4),
            Text(
              entry.courseTitle,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _InfoItem(
                icon: Icons.schedule_rounded,
                label: entry.timeRange,
              ),
              _InfoItem(
                icon: Icons.place_rounded,
                label: entry.room.isNotEmpty ? entry.room : 'TBA',
              ),
              if (teacher.isNotEmpty)
                _InfoItem(
                  icon: Icons.person_rounded,
                  label: teacher,
                ),
              if (showSection)
                _InfoItem(
                  icon: Icons.school_rounded,
                  label: entry.section,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NowChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Now',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _RoomPanel extends StatelessWidget {
  const _RoomPanel({
    required this.title,
    required this.color,
    required this.child,
  });

  final String title;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
            color: _SchedulerPalette.accent.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _OccupiedRoomCard extends StatelessWidget {
  const _OccupiedRoomCard({required this.room, required this.entries});

  final String room;
  final List<ScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2).withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Room $room',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF7F1D1D),
            ),
          ),
          const SizedBox(height: 6),
          ...entries
              .map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${entry.courseDisplay} - ${entry.section} - ${entry.timeRange}',
                    style: const TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
              ,
        ],
      ),
    );
  }
}

class _AvailableRoomChip extends StatelessWidget {
  const _AvailableRoomChip({required this.room});

  final String room;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7).withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Text(
        'Room $room',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF166534),
        ),
      ),
    );
  }
}

class _ViewToggleChip extends StatelessWidget {
  const _ViewToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: _SchedulerPalette.accent,
      backgroundColor: Colors.white.withOpacity(0.9),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF475569),
        fontWeight: FontWeight.w700,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF0F172A),
          fontSize: compact ? 11.5 : 12.5,
        ),
      ),
    );
  }
}

class _GridDayCell extends StatelessWidget {
  const _GridDayCell({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      color: const Color(0xFFBFDBFE),
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E3A8A),
          fontSize: compact ? 12 : 13,
        ),
      ),
    );
  }
}

class _GridEntryCell extends StatelessWidget {
  const _GridEntryCell({
    required this.entries,
    required this.highlight,
    required this.showSection,
    required this.compact,
  });

  final List<ScheduleEntry> entries;
  final bool highlight;
  final bool showSection;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Container(
        height: compact ? 72 : 80,
        color: Colors.white,
      );
    }

    final lines = entries
        .take(2)
        .map(
          (entry) {
            final teacher = entry.facultyInitial.isNotEmpty
                ? entry.facultyInitial
                : entry.facultyName;
            final room = entry.room.isNotEmpty ? entry.room : 'TBA';
            final parts = <String>[entry.courseDisplay];
            if (showSection && entry.section.isNotEmpty) {
              parts.add(entry.section);
            }
            if (teacher.isNotEmpty) {
              parts.add(teacher);
            }
            parts.add(room);
            return parts.join(' | ');
          },
        )
        .toList();
    if (entries.length > 2) {
      lines.add('+${entries.length - 2} more');
    }

    return Container(
      padding: EdgeInsets.all(compact ? 6 : 8),
      constraints: BoxConstraints(minHeight: compact ? 72 : 80),
      color: highlight ? const Color(0xFFEFF6FF) : Colors.white,
      child: Text(
        lines.join('\n'),
        style: TextStyle(
          fontSize: compact ? 11 : 11.5,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        softWrap: true,
        maxLines: compact ? 5 : 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _GridHint extends StatelessWidget {
  const _GridHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.swipe, size: 16, color: Color(0xFF64748B)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionEmptyState extends StatelessWidget {
  const _SectionEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: _SchedulerPalette.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

const List<String> _dayOrder = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
];

const String _allDaysLabel = 'All';
const String _studentViewPreferenceKey = 'schedule_view_grid_student';
const String _facultyViewPreferenceKey = 'schedule_view_grid_faculty';
