import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

part 'bus_tracker_models.g.dart';

// ── Timetable (Hive-persisted) ───────────────────────────────────────────────

@HiveType(typeId: 10)
class TimetableEntry extends HiveObject {
  TimetableEntry({
    required this.routeName,
    required this.origin,
    required this.departureTime,
    required this.isFromCampus,
  });

  @HiveField(0)
  final String routeName;

  @HiveField(1)
  final String origin;

  @HiveField(2)
  final String departureTime;

  @HiveField(3)
  final bool isFromCampus;
}

// ── Live Bus Location ────────────────────────────────────────────────────────

class BusLocation {
  const BusLocation({
    required this.busId,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    required this.updatedAt,
    this.broadcasterId,
    this.broadcasterName,
    this.sessionToken,
  });

  final String busId;
  final double latitude;
  final double longitude;
  final double? heading;
  final double? speed;
  final DateTime updatedAt;
  final String? broadcasterId;
  final String? broadcasterName;
  final String? sessionToken;

  factory BusLocation.fromMap(Map<String, dynamic> map) => BusLocation(
        busId: map['bus_id'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        heading: (map['heading'] as num?)?.toDouble(),
        speed: (map['speed'] as num?)?.toDouble(),
        updatedAt: DateTime.parse(map['updated_at'] as String).toUtc(),
        broadcasterId: map['driver_id'] as String?,
        broadcasterName: map['broadcaster_name'] as String?,
        sessionToken: map['session_token'] as String?,
      );
}

// ── Route definition ─────────────────────────────────────────────────────────

class BusStop {
  const BusStop({required this.name, required this.position});
  final String name;
  final LatLng position;
}

class BusRoute {
  const BusRoute({
    required this.id,
    required this.name,
    required this.color,
    required this.stops,
  });

  final String id;
  final String name;
  final Color color;
  final List<BusStop> stops;

  List<LatLng> get polylinePoints => stops.map((s) => s.position).toList();
}

// ── SMUCT Campus + all routes ─────────────────────────────────────────────────
// Campus: Plot# 06, Avenue# 06, Sector# 17/H-1, Uttara, Dhaka-1230

const LatLng kCampusLatLng = LatLng(23.8759, 90.3795); // SMUCT Uttara campus

final List<BusRoute> kBusRoutes = [
  BusRoute(
    id: 'route-azimpur',
    name: 'Campus ↔ Azimpur (Newmarket)',
    color: const Color(0xFF2563EB),
    stops: [
      BusStop(name: 'Azimpur / Newmarket', position: LatLng(23.7279, 90.3875)),
      BusStop(name: 'Dhanmondi', position: LatLng(23.7461, 90.3742)),
      BusStop(name: 'Mirpur Road', position: LatLng(23.7798, 90.3667)),
      BusStop(name: 'Uttara Sector 7', position: LatLng(23.8620, 90.3783)),
      BusStop(name: 'SMUCT Campus', position: kCampusLatLng),
    ],
  ),
  BusRoute(
    id: 'route-savar',
    name: 'Campus ↔ Savar',
    color: const Color(0xFF16A34A),
    stops: [
      BusStop(name: 'Nobinagar, Savar', position: LatLng(23.8614, 90.2606)),
      BusStop(name: 'Savar Bus Stand', position: LatLng(23.8567, 90.2669)),
      BusStop(name: 'Hemayetpur', position: LatLng(23.8656, 90.2974)),
      BusStop(name: 'Bypass Road', position: LatLng(23.8703, 90.3388)),
      BusStop(name: 'SMUCT Campus', position: kCampusLatLng),
    ],
  ),
  BusRoute(
    id: 'route-gazipur',
    name: 'Campus ↔ Gazipur',
    color: const Color(0xFFDC2626),
    stops: [
      BusStop(name: 'Gazipur Chowrasta', position: LatLng(23.9999, 90.4178)),
      BusStop(name: 'Board Bazar', position: LatLng(23.9834, 90.4123)),
      BusStop(name: 'Tongi', position: LatLng(23.9311, 90.4021)),
      BusStop(name: 'Uttara Sector 17', position: LatLng(23.8834, 90.3801)),
      BusStop(name: 'SMUCT Campus', position: kCampusLatLng),
    ],
  ),
  BusRoute(
    id: 'route-mirpur',
    name: 'Mirpur-10 Shuttle',
    color: const Color(0xFF7C3AED),
    stops: [
      BusStop(name: 'Indoor Stadium, Mirpur-10', position: LatLng(23.8074, 90.3651)),
      BusStop(name: 'Mirpur-12', position: LatLng(23.8219, 90.3662)),
      BusStop(name: 'Mirpur-13', position: LatLng(23.8348, 90.3680)),
      BusStop(name: 'Uttara Sector 13', position: LatLng(23.8634, 90.3768)),
      BusStop(name: 'SMUCT Campus', position: kCampusLatLng),
    ],
  ),
  BusRoute(
    id: 'route-rampura',
    name: 'Campus ↔ Rampura',
    color: const Color(0xFFD97706),
    stops: [
      BusStop(name: 'Rampura Bridge', position: LatLng(23.7640, 90.4126)),
      BusStop(name: 'Badda', position: LatLng(23.7803, 90.4273)),
      BusStop(name: 'Airport Road', position: LatLng(23.8284, 90.4020)),
      BusStop(name: 'Uttara Sector 17', position: LatLng(23.8834, 90.3801)),
      BusStop(name: 'SMUCT Campus', position: kCampusLatLng),
    ],
  ),
];

// ── Offline timetable seed data ───────────────────────────────────────────────

final List<TimetableEntry> kTimetableSeed = [
  // Azimpur route
  TimetableEntry(routeName: 'Campus ↔ Azimpur', origin: 'Azimpur', departureTime: '07:00', isFromCampus: false),
  TimetableEntry(routeName: 'Campus ↔ Azimpur', origin: 'Campus', departureTime: '17:40', isFromCampus: true),
  // Savar route
  TimetableEntry(routeName: 'Campus ↔ Savar', origin: 'Nobinagar', departureTime: '07:00', isFromCampus: false),
  TimetableEntry(routeName: 'Campus ↔ Savar', origin: 'Campus', departureTime: '17:40', isFromCampus: true),
  // Gazipur route
  TimetableEntry(routeName: 'Campus ↔ Gazipur', origin: 'Gazipur', departureTime: '07:00', isFromCampus: false),
  TimetableEntry(routeName: 'Campus ↔ Gazipur', origin: 'Gazipur', departureTime: '07:10', isFromCampus: false),
  TimetableEntry(routeName: 'Campus ↔ Gazipur', origin: 'Gazipur', departureTime: '10:00', isFromCampus: false),
  TimetableEntry(routeName: 'Campus ↔ Gazipur', origin: 'Campus', departureTime: '13:45', isFromCampus: true),
  TimetableEntry(routeName: 'Campus ↔ Gazipur', origin: 'Campus', departureTime: '16:40', isFromCampus: true),
  TimetableEntry(routeName: 'Campus ↔ Gazipur', origin: 'Campus', departureTime: '17:40', isFromCampus: true),
  // Mirpur-10 Shuttle
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Indoor Stadium', departureTime: '08:00', isFromCampus: false),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Indoor Stadium', departureTime: '09:00', isFromCampus: false),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Indoor Stadium', departureTime: '11:30', isFromCampus: false),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Indoor Stadium', departureTime: '14:15', isFromCampus: false),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Campus', departureTime: '11:30', isFromCampus: true),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Campus', departureTime: '13:45', isFromCampus: true),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Campus', departureTime: '16:45', isFromCampus: true),
  TimetableEntry(routeName: 'Mirpur-10 Shuttle', origin: 'Campus', departureTime: '17:45', isFromCampus: true),
  // Rampura route
  TimetableEntry(routeName: 'Campus ↔ Rampura', origin: 'Rampura', departureTime: '07:00', isFromCampus: false),
  TimetableEntry(routeName: 'Campus ↔ Rampura', origin: 'Campus', departureTime: '17:40', isFromCampus: true),
];
