import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'bus_tracker_models.dart';
import 'bus_tracker_service.dart';

class BusTrackerScreen extends StatefulWidget {
  const BusTrackerScreen({
    super.key,
    required this.currentUserName,
    this.initialRouteId,
    this.isDriver = false,
  });

  final String currentUserName;
  final String? initialRouteId;
  final bool isDriver;

  @override
  State<BusTrackerScreen> createState() => _BusTrackerScreenState();
}

class _BusTrackerScreenState extends State<BusTrackerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = BusTrackerService.instance;
  final _mapController = MapController();

  StreamSubscription<Map<String, BusLocation>>? _locationSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _staleMapTimer;

  Map<String, BusLocation> _liveLocations = {};
  bool _isOnline = true;
  late String _selectedRouteId;

  String? get _myUserId => Supabase.instance.client.auth.currentUser?.id;
  String? get _myBroadcastingRouteId =>
      _service.isBroadcasting ? _service.activeBusId : null;

  @override
  void initState() {
    super.initState();
    _selectedRouteId = widget.initialRouteId ?? kBusRoutes.first.id;
    _tabController = TabController(length: 2, vsync: this);
    _service.initTimetable().then((_) => setState(() {}));
    _subscribeLocations();
    _watchConnectivity();
    _staleMapTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationSub?.cancel();
    _connectivitySub?.cancel();
    _staleMapTimer?.cancel();
    _service.stopBroadcasting();
    super.dispose();
  }

  void _subscribeLocations() {
    _locationSub = _service.watchLocations().listen((locs) {
      if (mounted) setState(() => _liveLocations = locs);
    });
  }

  void _watchConnectivity() {
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (mounted) setState(() => _isOnline = online);
    });
  }

  BusRoute get _selectedRoute =>
      kBusRoutes.firstWhere((r) => r.id == _selectedRouteId);

  Future<void> _onShareTap(String routeId) async {
    if (_myBroadcastingRouteId == routeId) {
      await _service.stopBroadcasting();
      if (mounted) setState(() {});
      return;
    }
    if (_service.isBroadcasting) await _service.stopBroadcasting();

    final granted = await _service.requestPermission();
    if (!granted) {
      if (mounted) _showSnack('Location permission is required to share GPS.');
      return;
    }

    final name = widget.currentUserName.trim().isEmpty
        ? 'A fellow passenger'
        : widget.currentUserName;
    final error = await _service.startBroadcasting(routeId, name);
    if (!mounted) return;
    if (error != null) {
      _showSnack(error);
    } else {
      setState(() {});
      _showSnack('📍 Your live location is now visible to everyone.');
    }
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Map builders ──────────────────────────────────────────────────────────

  List<Polyline> _buildPolylines() => kBusRoutes
      .map((r) => Polyline(
            points: r.polylinePoints,
            color: r.id == _selectedRouteId
                ? r.color
                : r.color.withOpacity(0.25),
            strokeWidth: r.id == _selectedRouteId ? 4.0 : 2.0,
          ))
      .toList();

  List<Marker> _buildStopMarkers() => _selectedRoute.stops
      .map((stop) => Marker(
            point: stop.position,
            width: 140,
            height: 44,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.12), blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    stop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _selectedRoute.color),
                  ),
                ),
                Icon(Icons.location_on, color: _selectedRoute.color, size: 20),
              ],
            ),
          ))
      .toList();

  List<Marker> _buildBusMarkers() {
    final now = DateTime.now();
    return _liveLocations.values
        .where((loc) => now.toUtc().difference(loc.updatedAt).inSeconds < BusTrackerService.staleSeconds)
        .where((loc) => loc.busId == _selectedRouteId)
        .map((loc) {
      final route = kBusRoutes.firstWhere((r) => r.id == loc.busId,
          orElse: () => kBusRoutes.first);
      final busPos = LatLng(loc.latitude, loc.longitude);
      final nextStop = _nextStop(busPos, route);
      final eta = nextStop != null
          ? _service.estimateMinutes(busPos, nextStop.position)
          : null;
      final isMe = loc.broadcasterId == _myUserId;

      return Marker(
        point: busPos,
        width: 80,
        height: 80,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (eta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                    color: route.color,
                    borderRadius: BorderRadius.circular(6)),
                child: Text('~$eta min',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF14B8A6) : route.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: route.color.withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 2)
                ],
              ),
              child: Icon(
                  isMe ? Icons.person_pin_circle : Icons.directions_bus,
                  color: Colors.white,
                  size: 20),
            ),
            if (loc.broadcasterName != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  isMe ? 'You' : loc.broadcasterName!,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: route.color),
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  BusStop? _nextStop(LatLng busPos, BusRoute route) {
    if (route.stops.isEmpty) return null;
    BusStop? closest;
    double minDist = double.infinity;
    const dist = Distance();
    for (final stop in route.stops) {
      final d = dist(busPos, stop.position);
      if (d < minDist) {
        minDist = d;
        closest = stop;
      }
    }
    final idx = route.stops.indexOf(closest!);
    return idx < route.stops.length - 1 ? route.stops[idx + 1] : closest;
  }

  // ── Map tab ───────────────────────────────────────────────────────────────

  Widget _buildMapTab() {
    // Drivers only see their assigned route chip; others see all
    final visibleRoutes = widget.isDriver
        ? kBusRoutes.where((r) => r.id == _selectedRouteId).toList()
        : kBusRoutes;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: kCampusLatLng,
            initialZoom: 12.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.unisharesync.app',
            ),
            PolylineLayer(polylines: _buildPolylines()),
            MarkerLayer(markers: [
              ..._buildStopMarkers(),
              ..._buildBusMarkers(),
            ]),
          ],
        ),

        // ── Route chips — wrapped in Material so scroll gestures aren't
        //    swallowed by FlutterMap's gesture detector underneath
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: _RouteChips(
              routes: visibleRoutes,
              selectedId: _selectedRouteId,
              onSelected: widget.isDriver
                  ? (_) {} // driver is locked to assigned route
                  : (id) {
                      setState(() => _selectedRouteId = id);
                      final r = kBusRoutes.firstWhere((r) => r.id == id);
                      if (r.stops.isNotEmpty) {
                        _mapController.move(r.stops.last.position, 12);
                      }
                    },
            ),
          ),
        ),

        // Share GPS panel
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: _ShareGpsPanel(
              selectedRoute: _selectedRoute,
              liveLocation: _liveLocations[_selectedRouteId],
              myUserId: _myUserId,
              isBroadcastingThisRoute:
                  _myBroadcastingRouteId == _selectedRouteId,
              onTap: () => _onShareTap(_selectedRouteId),
            ),
          ),
        ),

        if (!_isOnline)
          Positioned(
            top: 70,
            left: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 13),
                  SizedBox(width: 4),
                  Text('Offline',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Timetable tab ─────────────────────────────────────────────────────────

  Widget _buildTimetableTab() {
    final entries = _service.getTimetable();
    final grouped = <String, List<TimetableEntry>>{};
    for (final e in entries) {
      grouped.putIfAbsent(e.routeName, () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (!_isOnline)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.wifi_off, color: Color(0xFFE65100), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Offline — showing cached timetable',
                      style: TextStyle(
                          color: Color(0xFFE65100),
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ...grouped.entries.map((entry) {
          final route = kBusRoutes.firstWhere(
            (r) =>
                r.name.contains(entry.key.split(' ').last) ||
                r.name.contains(entry.key),
            orElse: () => kBusRoutes.first,
          );
          return _TimetableCard(
              routeName: entry.key, color: route.color, entries: entry.value);
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: widget.isDriver
          ? null // DriverHomeScreen provides its own AppBar
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              title: const Text('Campus Bus Tracker',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A))),
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF14B8A6),
                labelColor: const Color(0xFF14B8A6),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(icon: Icon(Icons.map_outlined), text: 'Live Map'),
                  Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
                ],
              ),
            ),
      body: widget.isDriver
          ? Column(
              children: [
                _tabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [_buildMapTab(), _buildTimetableTab()],
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              physics: const NeverScrollableScrollPhysics(),
              children: [_buildMapTab(), _buildTimetableTab()],
            ),
    );
  }

  Widget _tabBar() => TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xFF14B8A6),
        labelColor: const Color(0xFF14B8A6),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        tabs: const [
          Tab(icon: Icon(Icons.map_outlined), text: 'Live Map'),
          Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
        ],
      );
}

// ── Share GPS Panel ───────────────────────────────────────────────────────────

class _ShareGpsPanel extends StatelessWidget {
  const _ShareGpsPanel({
    required this.selectedRoute,
    required this.liveLocation,
    required this.myUserId,
    required this.isBroadcastingThisRoute,
    required this.onTap,
  });

  final BusRoute selectedRoute;
  final BusLocation? liveLocation;
  final String? myUserId;
  final bool isBroadcastingThisRoute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isStale = liveLocation == null ||
        DateTime.now().toUtc().difference(liveLocation!.updatedAt).inSeconds >=
            BusTrackerService.staleSeconds;
    final someoneElseLive =
        !isStale && !isBroadcastingThisRoute;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: selectedRoute.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.directions_bus_rounded,
                color: selectedRoute.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedRoute.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 2),
                if (isBroadcastingThisRoute)
                  const Text('📍 Broadcasting your live location',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF14B8A6),
                          fontWeight: FontWeight.w600))
                else if (someoneElseLive)
                  Text(
                      '🔴 Live by ${liveLocation!.broadcasterName ?? 'a passenger'}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w600))
                else
                  const Text('No live location — tap to share yours',
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isBroadcastingThisRoute)
            _PanelButton(
                label: 'Stop',
                color: Colors.red,
                icon: Icons.stop_circle_outlined,
                onTap: onTap)
          else if (someoneElseLive)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Live',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8))),
            )
          else
            _PanelButton(
                label: 'Share GPS',
                color: const Color(0xFF14B8A6),
                icon: Icons.share_location_rounded,
                onTap: onTap),
        ],
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton(
      {required this.label,
      required this.color,
      required this.icon,
      required this.onTap});
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration:
            BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── Route Chips ───────────────────────────────────────────────────────────────

class _RouteChips extends StatelessWidget {
  const _RouteChips(
      {required this.routes,
      required this.selectedId,
      required this.onSelected});
  final List<BusRoute> routes;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // padding ensures the last chip shadow is not clipped
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: routes.map((route) {
          final sel = route.id == selectedId;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onSelected(route.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? route.color : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? route.color : const Color(0xFFE2E8F0),
                      width: 1.5),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.10), blurRadius: 6)
                  ],
                ),
                child: Text(
                  route.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : route.color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Timetable Card ────────────────────────────────────────────────────────────

class _TimetableCard extends StatelessWidget {
  const _TimetableCard(
      {required this.routeName, required this.color, required this.entries});
  final String routeName;
  final Color color;
  final List<TimetableEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fromOrigin = entries.where((e) => !e.isFromCampus).toList();
    final fromCampus = entries.where((e) => e.isFromCampus).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.directions_bus_rounded, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(routeName,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 13)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    child: _TimeColumn(
                        label: '🚏 From Origin',
                        entries: fromOrigin,
                        color: color)),
                const SizedBox(width: 12),
                Expanded(
                    child: _TimeColumn(
                        label: '🏫 From Campus',
                        entries: fromCampus,
                        color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn extends StatelessWidget {
  const _TimeColumn(
      {required this.label, required this.entries, required this.color});
  final String label;
  final List<TimetableEntry> entries;
  final Color color;

  String _toAmPm(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h < 12 ? 'AM' : 'PM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: Color(0xFF64748B))),
        const SizedBox(height: 6),
        ...entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(_toAmPm(e.departureTime),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            )),
        if (entries.isEmpty)
          Text('—',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ],
    );
  }
}
