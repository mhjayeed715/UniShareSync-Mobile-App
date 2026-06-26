import 'dart:convert';
// dart:io must NOT be imported directly on web – use the conditional shim.
import 'schedule_io.dart' if (dart.library.html) 'schedule_io_web.dart';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'schedule_models.dart';

class ScheduleRepository {
  static const String _routineAssetPath =
      '9A Winter 2026 - Central Routine.csv';
  static const String _courseAssetPath =
      'Course Offer Winter 2026 - Course Distribution.csv';
  static const String _cacheBoxName = 'schedule_cache';
  static const String _cacheKey = 'schedule_snapshot';

  Future<ScheduleSnapshot> loadSchedule({bool preferOverride = true}) async {
    final box = await _openBox();

    if (preferOverride) {
      final cachedOverride = _readCache(box, requireOverride: true);
      if (cachedOverride != null) {
        return cachedOverride;
      }
    }

    try {
      final routineCsv = await rootBundle.loadString(_routineAssetPath);
      final courseCsv = await rootBundle.loadString(_courseAssetPath);
      final parsed = _parseSchedule(routineCsv, courseCsv);
      final cachedAt = DateTime.now();
      final snapshot = ScheduleSnapshot(
        entries: parsed.entries,
        timeSlots: parsed.timeSlots,
        fromCache: false,
        isOverride: false,
        cachedAt: cachedAt,
      );
      await _writeCache(box, snapshot, isOverride: false);
      return snapshot;
    } catch (_) {
      final cached = _readCache(box, requireOverride: false);
      if (cached != null) {
        return cached;
      }
      rethrow;
    }
  }

  Future<ScheduleSnapshot> importFromFiles({
    required String routinePath,
    String? coursePath,
  }) async {
    // readFileAsString() comes from the conditional shim:
    //   schedule_io.dart      (native: dart:io)
    //   schedule_io_web.dart  (web: throws UnsupportedError – never called)
    final routineCsv = await readFileAsString(routinePath);
    final courseCsv = coursePath != null
        ? await readFileAsString(coursePath)
        : await rootBundle.loadString(_courseAssetPath);
    return importFromCsvStrings(
      routineCsv: routineCsv,
      courseCsv: courseCsv,
    );
  }

  Future<ScheduleSnapshot> importFromCsvStrings({
    required String routineCsv,
    required String courseCsv,
  }) async {
    final box = await _openBox();
    final parsed = _parseSchedule(routineCsv, courseCsv);
    final snapshot = ScheduleSnapshot(
      entries: parsed.entries,
      timeSlots: parsed.timeSlots,
      fromCache: true,
      isOverride: true,
      cachedAt: DateTime.now(),
    );
    await _writeCache(box, snapshot, isOverride: true);
    return snapshot;
  }

  Future<ScheduleSnapshot> saveOverrideSchedule({
    required List<ScheduleEntry> entries,
    required List<ScheduleTimeSlot> timeSlots,
  }) async {
    final box = await _openBox();
    final snapshot = ScheduleSnapshot(
      entries: entries,
      timeSlots: timeSlots,
      fromCache: true,
      isOverride: true,
      cachedAt: DateTime.now(),
    );
    await _writeCache(box, snapshot, isOverride: true);
    return snapshot;
  }

  Future<ScheduleSnapshot> resetToAssets() async {
    final box = await _openBox();
    final routineCsv = await rootBundle.loadString(_routineAssetPath);
    final courseCsv = await rootBundle.loadString(_courseAssetPath);
    final parsed = _parseSchedule(routineCsv, courseCsv);
    final snapshot = ScheduleSnapshot(
      entries: parsed.entries,
      timeSlots: parsed.timeSlots,
      fromCache: false,
      isOverride: false,
      cachedAt: DateTime.now(),
    );
    await _writeCache(box, snapshot, isOverride: false);
    return snapshot;
  }

  Future<Box<String>> _openBox() async {
    if (Hive.isBoxOpen(_cacheBoxName)) {
      return Hive.box<String>(_cacheBoxName);
    }
    return Hive.openBox<String>(_cacheBoxName);
  }

  ScheduleSnapshot? _readCache(
    Box<String> box, {
    required bool requireOverride,
  }) {
    final raw = box.get(_cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final isOverride = decoded['override'] == true;
    if (requireOverride && !isOverride) {
      return null;
    }
    final entries = (decoded['entries'] as List<dynamic>? ?? const [])
        .map((entry) => ScheduleEntry.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
    final timeSlots = (decoded['timeSlots'] as List<dynamic>? ?? const [])
        .map((slot) => ScheduleTimeSlot.fromJson(slot as Map<String, dynamic>))
        .toList(growable: false);
    final cachedAt = DateTime.tryParse(decoded['cachedAt']?.toString() ?? '');

    return ScheduleSnapshot(
      entries: entries,
      timeSlots: timeSlots,
      fromCache: true,
      isOverride: isOverride,
      cachedAt: cachedAt,
    );
  }

  Future<void> _writeCache(
    Box<String> box,
    ScheduleSnapshot snapshot, {
    required bool isOverride,
  }) async {
    final payload = <String, dynamic>{
      'entries': snapshot.entries.map((entry) => entry.toJson()).toList(),
      'timeSlots': snapshot.timeSlots.map((slot) => slot.toJson()).toList(),
      'cachedAt': snapshot.cachedAt?.toIso8601String(),
      'override': isOverride,
    };
    await box.put(_cacheKey, jsonEncode(payload));
  }

  _ParsedSchedule _parseSchedule(String routineCsv, String courseCsv) {
    final directory = _parseCourseDirectory(courseCsv);
    final rows = _csvToRows(routineCsv);

    final entries = <ScheduleEntry>[];
    final timeSlots = <ScheduleTimeSlot>[];
    var index = 0;

    while (index < rows.length) {
      final dayLabel = _readDayLabel(rows[index]);
      if (dayLabel == null) {
        index += 1;
        continue;
      }

      final timeRow = index + 1 < rows.length ? rows[index + 1] : const <String>[];
      final slotColumns = _parseTimeSlots(timeRow);
      if (timeSlots.isEmpty) {
        timeSlots.addAll(slotColumns.map((slot) => slot.slot));
      }

      index += 3;

      while (index < rows.length) {
        final nextDay = _readDayLabel(rows[index]);
        if (nextDay != null) {
          break;
        }

        final row = rows[index];
        final sectionRaw = _normalize(_cell(row, 0));
        final hasCourses = _rowHasCourses(row, slotColumns);
        if (sectionRaw.isEmpty && !hasCourses) {
          index += 1;
          continue;
        }

        final section = sectionRaw.isEmpty ? 'All' : sectionRaw;
        final semester = _parseSemester(section);
        final group = _parseGroup(section);

        for (final slot in slotColumns) {
          final courseRaw = _normalize(_cell(row, slot.courseColumn));
          if (courseRaw.isEmpty) {
            continue;
          }

          final facultyInitial =
              _normalize(_cell(row, slot.courseColumn + 1)).toUpperCase();
          final room = _normalize(_cell(row, slot.courseColumn + 2));
          final courseCode = _extractCourseCode(courseRaw);
          final normalizedCode =
              courseCode == null ? '' : _normalizeCourseCode(courseCode);
          final courseTitle = normalizedCode.isNotEmpty
              ? (directory.courseTitles[normalizedCode] ?? courseRaw)
              : courseRaw;
          final facultyName = facultyInitial.isNotEmpty
              ? (directory.facultyNames[facultyInitial] ?? '')
              : '';

          entries.add(
            ScheduleEntry(
              day: dayLabel,
              section: section,
              semester: semester,
              group: group,
              courseCode:
                  normalizedCode.isNotEmpty ? normalizedCode : courseRaw,
              courseDisplay: courseRaw,
              courseTitle: courseTitle,
              facultyInitial: facultyInitial,
              facultyName: facultyName,
              room: room,
              timeRange: slot.slot.label,
              startMinutes: slot.slot.startMinutes,
              endMinutes: slot.slot.endMinutes,
            ),
          );
        }

        index += 1;
      }
    }

    return _ParsedSchedule(entries: entries, timeSlots: timeSlots);
  }

  _CourseDirectory _parseCourseDirectory(String courseCsv) {
    final rows = _csvToRows(courseCsv);
    final courseTitles = <String, String>{};
    final facultyNames = <String, String>{};

    var codeIndex = -1;
    var titleIndex = -1;
    var initialIndex = -1;
    var nameIndex = -1;

    for (final row in rows) {
      final normalizedRow = row.map(_normalize).toList(growable: false);
      final headerIndex = _findHeaderIndex(normalizedRow, 'course code');
      if (headerIndex != -1) {
        codeIndex = headerIndex;
        titleIndex = _findHeaderIndex(normalizedRow, 'course title');
        initialIndex = _findHeaderIndex(normalizedRow, 'faculty initial');
        nameIndex = _findHeaderIndex(normalizedRow, 'facuty name');
        if (nameIndex == -1) {
          nameIndex = _findHeaderIndex(normalizedRow, 'faculty name');
        }
        continue;
      }

      if (codeIndex == -1) {
        continue;
      }

      final code = _safeCell(normalizedRow, codeIndex);
      final title = _safeCell(normalizedRow, titleIndex);
      final initial = _safeCell(normalizedRow, initialIndex).toUpperCase();
      final name = _safeCell(normalizedRow, nameIndex);

      if (initial.isNotEmpty && name.isNotEmpty) {
        facultyNames.putIfAbsent(initial, () => name);
      }

      if (code.isNotEmpty && title.isNotEmpty) {
        final normalizedCode = _normalizeCourseCode(code);
        courseTitles.putIfAbsent(normalizedCode, () => title);
      }
    }

    return _CourseDirectory(
      courseTitles: courseTitles,
      facultyNames: facultyNames,
    );
  }

  List<List<String>> _csvToRows(String csv) {
    final rows = CsvToListConverter(shouldParseNumbers: false)
        .convert(csv)
        .map(
          (row) => row
              .map((cell) => _normalize(cell?.toString() ?? ''))
              .toList(growable: false),
        )
        .toList(growable: false);
    return rows;
  }

  String? _readDayLabel(List<String> row) {
    final nonEmpty = row.where((value) => value.trim().isNotEmpty).toList();
    if (nonEmpty.length != 1) {
      return null;
    }

    final candidate = nonEmpty.first.trim();
    if (_dayLabels.contains(candidate)) {
      return candidate;
    }

    return null;
  }

  List<_SlotColumn> _parseTimeSlots(List<String> row) {
    final slots = <_SlotColumn>[];
    for (var i = 0; i < row.length; i++) {
      final value = _normalize(row[i]);
      if (_looksLikeTimeRange(value)) {
        final range = _parseTimeRange(value);
        slots.add(
          _SlotColumn(
            courseColumn: i,
            slot: ScheduleTimeSlot(
              label: value,
              startMinutes: range.startMinutes,
              endMinutes: range.endMinutes,
            ),
          ),
        );
      }
    }
    return slots;
  }

  bool _rowHasCourses(List<String> row, List<_SlotColumn> slots) {
    return slots
        .map((slot) => _normalize(_cell(row, slot.courseColumn)))
        .any((value) => value.isNotEmpty);
  }

  String _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index];
  }

  String _safeCell(List<String> row, int index) {
    if (index < 0 || index >= row.length) {
      return '';
    }
    return row[index];
  }

  String _normalize(String value) {
    return value
        .replaceAll('\ufeff', '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  int _findHeaderIndex(List<String> row, String header) {
    for (var i = 0; i < row.length; i++) {
      if (row[i].toLowerCase() == header) {
        return i;
      }
    }
    return -1;
  }

  String? _extractCourseCode(String value) {
    final match = RegExp(r'([A-Z]{2,4})\s*(\d{4})').firstMatch(value);
    if (match == null) {
      return null;
    }
    return '${match.group(1)} ${match.group(2)}';
  }

  String _normalizeCourseCode(String value) {
    final match =
        RegExp(r'([A-Z]{2,4})\s*(\d{4})', caseSensitive: false)
            .firstMatch(value);
    if (match == null) {
      return _normalize(value).toUpperCase();
    }
    return '${match.group(1)!.toUpperCase()} ${match.group(2)}';
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

  bool _looksLikeTimeRange(String value) {
    return RegExp(r'\d{1,2}[:\.]\d{2}\s*(AM|PM)\s*-',
            caseSensitive: false)
        .hasMatch(value);
  }

  _TimeRange _parseTimeRange(String value) {
    final parts = value.split('-');
    if (parts.length < 2) {
      return const _TimeRange(0, 0);
    }

    final startMinutes = _parseTime(parts[0]);
    final endMinutes = _parseTime(parts[1]);
    return _TimeRange(startMinutes, endMinutes);
  }

  int _parseTime(String value) {
    final normalized = value
        .replaceAll('.', ':')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final match = RegExp(r'(\d{1,2})[:](\d{2})\s*(AM|PM)',
            caseSensitive: false)
        .firstMatch(normalized);
    if (match == null) {
      return 0;
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
}

class _ParsedSchedule {
  const _ParsedSchedule({required this.entries, required this.timeSlots});

  final List<ScheduleEntry> entries;
  final List<ScheduleTimeSlot> timeSlots;
}

class _CourseDirectory {
  const _CourseDirectory({
    required this.courseTitles,
    required this.facultyNames,
  });

  final Map<String, String> courseTitles;
  final Map<String, String> facultyNames;
}

class _SlotColumn {
  const _SlotColumn({required this.courseColumn, required this.slot});

  final int courseColumn;
  final ScheduleTimeSlot slot;
}

class _TimeRange {
  const _TimeRange(this.startMinutes, this.endMinutes);

  final int startMinutes;
  final int endMinutes;
}

const List<String> _dayLabels = [
  'Saturday',
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
];
