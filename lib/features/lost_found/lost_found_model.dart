import 'package:flutter/foundation.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

enum LostFoundReportType { lost, found }

extension LostFoundReportTypeX on LostFoundReportType {
  String get label => switch (this) {
        LostFoundReportType.lost => 'Lost',
        LostFoundReportType.found => 'Found',
      };

  String get storageValue => name;

  static LostFoundReportType fromString(String? value) => switch (value) {
        'found' => LostFoundReportType.found,
        'lost' => LostFoundReportType.lost,
        _ => LostFoundReportType.lost,
      };
}

enum LostFoundStatus { open, matched, resolved }

extension LostFoundStatusX on LostFoundStatus {
  String get label => switch (this) {
        LostFoundStatus.open => 'Open',
        LostFoundStatus.matched => 'Matched',
        LostFoundStatus.resolved => 'Resolved',
      };

  String get storageValue => name;

  static LostFoundStatus fromString(String? value) => switch (value) {
        'matched' => LostFoundStatus.matched,
        'resolved' => LostFoundStatus.resolved,
        'open' => LostFoundStatus.open,
        _ => LostFoundStatus.open,
      };
}

class LostFoundReportDraft {
  const LostFoundReportDraft({
    required this.reportType,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.contactInfo,
    required this.reportDate,
    this.photoBytes = const <Uint8List>[],
    this.photoFileNames = const <String>[],
  });

  final LostFoundReportType reportType;
  final String title;
  final String category;
  final String description;
  final String location;
  final String contactInfo;
  final DateTime reportDate;
  final List<Uint8List> photoBytes;
  final List<String> photoFileNames;
}

class LostFoundReport {
  const LostFoundReport({
    required this.id,
    required this.reportType,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.contactInfo,
    required this.reportDate,
    required this.status,
    required this.photoUrls,
    required this.reporterId,
    required this.reporterName,
    required this.reporterRole,
    required this.createdAt,
    required this.updatedAt,
    this.reporterAvatarUrl,
  });

  final String id;
  final LostFoundReportType reportType;
  final String title;
  final String category;
  final String description;
  final String location;
  final String contactInfo;
  final DateTime reportDate;
  final LostFoundStatus status;
  final List<String> photoUrls;
  final String reporterId;
  final String reporterName;
  final String? reporterAvatarUrl;
  final UserRole reporterRole;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasPhotos => photoUrls.isNotEmpty;

  factory LostFoundReport.fromMap(Map<String, dynamic> map) {
    return LostFoundReport(
      id: map['id']?.toString() ?? '',
      reportType:
          LostFoundReportTypeX.fromString(map['report_type']?.toString()),
      title: map['title']?.toString() ?? 'Untitled',
      category: map['category']?.toString() ?? 'Other',
      description: map['description']?.toString() ?? '',
      location: map['location']?.toString() ?? '',
      contactInfo: map['contact_info']?.toString() ?? '',
      reportDate: _toDate(map['report_date']),
      status: LostFoundStatusX.fromString(map['status']?.toString()),
      photoUrls: _toStringList(map['photo_urls']),
      reporterId: map['reporter_id']?.toString() ?? '',
      reporterName: map['reporter_name']?.toString() ?? 'Anonymous',
      reporterAvatarUrl: map['reporter_avatar_url']?.toString(),
      reporterRole: UserRole.fromString(map['reporter_role']?.toString()),
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

DateTime _toDate(dynamic value) {
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return DateTime.now();
}

DateTime _toDateTime(dynamic value) {
  if (value is DateTime) {
    return value.toLocal();
  }
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed.toLocal();
    }
  }
  return DateTime.now();
}
