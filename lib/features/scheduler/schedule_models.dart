class ScheduleEntry {
  const ScheduleEntry({
    this.id,
    required this.day,
    required this.section,
    required this.semester,
    required this.group,
    required this.courseCode,
    required this.courseDisplay,
    required this.courseTitle,
    required this.facultyInitial,
    required this.facultyName,
    required this.room,
    required this.timeRange,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String? id;
  final String day;
  final String section;
  final int? semester;
  final String? group;
  final String courseCode;
  final String courseDisplay;
  final String courseTitle;
  final String facultyInitial;
  final String facultyName;
  final String room;
  final String timeRange;
  final int startMinutes;
  final int endMinutes;

    Map<String, dynamic> toJson() => {
      'id': id,
        'day': day,
        'section': section,
        'semester': semester,
        'group': group,
        'courseCode': courseCode,
        'courseDisplay': courseDisplay,
        'courseTitle': courseTitle,
        'facultyInitial': facultyInitial,
        'facultyName': facultyName,
        'room': room,
        'timeRange': timeRange,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    final semesterValue = json['semester'];
    final startValue = json['startMinutes'];
    final endValue = json['endMinutes'];
    return ScheduleEntry(
      id: json['id']?.toString(),
      day: (json['day'] ?? '').toString(),
      section: (json['section'] ?? '').toString(),
      semester: semesterValue is int
          ? semesterValue
          : int.tryParse(semesterValue?.toString() ?? ''),
      group: json['group']?.toString(),
      courseCode: (json['courseCode'] ?? '').toString(),
      courseDisplay: (json['courseDisplay'] ?? '').toString(),
      courseTitle: (json['courseTitle'] ?? '').toString(),
      facultyInitial: (json['facultyInitial'] ?? '').toString(),
      facultyName: (json['facultyName'] ?? '').toString(),
      room: (json['room'] ?? '').toString(),
      timeRange: (json['timeRange'] ?? '').toString(),
      startMinutes: startValue is num ? startValue.toInt() : 0,
      endMinutes: endValue is num ? endValue.toInt() : 0,
    );
  }

  factory ScheduleEntry.fromSupabaseMap(Map<String, dynamic> map) {
    return ScheduleEntry(
      id: map['id']?.toString(),
      day: (map['day'] ?? '').toString(),
      section: (map['section'] ?? '').toString(),
      semester: map['semester'] is int
          ? map['semester'] as int
          : int.tryParse(map['semester']?.toString() ?? ''),
      group: map['group_name']?.toString(),
      courseCode: (map['course_code'] ?? '').toString(),
      courseDisplay: (map['course_display'] ?? '').toString(),
      courseTitle: (map['course_title'] ?? '').toString(),
      facultyInitial: (map['faculty_initial'] ?? '').toString(),
      facultyName: (map['faculty_name'] ?? '').toString(),
      room: (map['room'] ?? '').toString(),
      timeRange: (map['time_range'] ?? '').toString(),
      startMinutes: (map['start_minutes'] ?? 0) is num
          ? (map['start_minutes'] as num).toInt()
          : 0,
      endMinutes: (map['end_minutes'] ?? 0) is num
          ? (map['end_minutes'] as num).toInt()
          : 0,
    );
  }

  Map<String, dynamic> toSupabasePayload({bool includeId = false}) {
    final payload = <String, dynamic>{
      'day': day,
      'section': section,
      'semester': semester,
      'group_name': group,
      'course_code': courseCode,
      'course_display': courseDisplay,
      'course_title': courseTitle,
      'faculty_initial': facultyInitial,
      'faculty_name': facultyName,
      'room': room,
      'time_range': timeRange,
      'start_minutes': startMinutes,
      'end_minutes': endMinutes,
    };

    if (includeId && id != null) {
      payload['id'] = id;
    }

    return payload;
  }
}

class ScheduleTimeSlot {
  const ScheduleTimeSlot({
    required this.label,
    required this.startMinutes,
    required this.endMinutes,
  });

  final String label;
  final int startMinutes;
  final int endMinutes;

  Map<String, dynamic> toJson() => {
        'label': label,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
      };

  factory ScheduleTimeSlot.fromJson(Map<String, dynamic> json) {
    final startValue = json['startMinutes'];
    final endValue = json['endMinutes'];
    return ScheduleTimeSlot(
      label: (json['label'] ?? '').toString(),
      startMinutes: startValue is num ? startValue.toInt() : 0,
      endMinutes: endValue is num ? endValue.toInt() : 0,
    );
  }
}

class FacultyOption {
  const FacultyOption({required this.initial, required this.name});

  final String initial;
  final String name;

  String get label {
    if (name.trim().isEmpty) {
      return initial;
    }
    return '$initial - $name';
  }
}

class ScheduleSnapshot {
  const ScheduleSnapshot({
    required this.entries,
    required this.timeSlots,
    required this.fromCache,
    required this.isOverride,
    required this.cachedAt,
  });

  final List<ScheduleEntry> entries;
  final List<ScheduleTimeSlot> timeSlots;
  final bool fromCache;
  final bool isOverride;
  final DateTime? cachedAt;
}
