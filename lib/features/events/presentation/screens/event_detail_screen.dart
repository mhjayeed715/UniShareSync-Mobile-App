import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/event_model.dart';
import '../../data/models/event_registration_model.dart';
import '../providers/events_provider.dart';
import '../providers/event_registration_provider.dart';
import 'event_registration_screen.dart';
import 'event_create_screen.dart';
import 'event_organizer_dashboard_screen.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  int _liveRegisteredCount = 0;
  UserRole? _userRole;
  EventRegistrationModel? _userRegistration;
  bool _isLoadingRegistration = false;

  @override
  void initState() {
    super.initState();
    _loadEventDetail();
    _loadUserRole();
  }

  void _loadUserRole() async {
    final role = await AuthService().getCurrentRole();
    if (mounted) {
      setState(() {
        _userRole = role;
      });
    }
  }

  void _fetchUserRegistration() async {
    final uid = ref.read(eventRegistrationProvider.notifier).currentUserId;
    if (uid == null) return;

    if (mounted) {
      setState(() {
        _isLoadingRegistration = true;
      });
    }

    try {
      final response = await Supabase.instance.client
          .from('event_registrations')
          .select()
          .eq('event_id', widget.eventId)
          .eq('user_id', uid)
          .neq('registration_status', 'cancelled')
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (response != null) {
            _userRegistration = EventRegistrationModel.fromMap(response);
          } else {
            _userRegistration = null;
          }
          _isLoadingRegistration = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRegistration = false;
        });
      }
    }
  }

  void _loadEventDetail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eventsProvider.notifier).fetchEventDetail(widget.eventId).then((event) {
        setState(() {
          _liveRegisteredCount = event.registeredCount;
        });
        ref.read(eventsProvider.notifier).subscribeToSeatCount(widget.eventId, (count) {
          if (mounted) {
            setState(() {
              _liveRegisteredCount = count;
            });
          }
        });
      });
      _fetchUserRegistration();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventsProvider);

    return Scaffold(
      body: FutureBuilder<EventModel>(
        future: ref.read(eventsProvider.notifier).fetchEventDetail(widget.eventId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading detail: ${snapshot.error}'));
          }

          final event = snapshot.data!;
          final isOrganizer = event.organizerId == ref.read(eventRegistrationProvider.notifier).currentUserId;
          final canManage = (isOrganizer || _userRole == UserRole.admin) &&
              (_userRole == UserRole.faculty || _userRole == UserRole.admin);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Image.network(
                    event.bannerUrl ?? 'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey),
                  ),
                ),
                actions: [
                  if (canManage) ...[
                    // Edit Event
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => EventCreateScreen(eventToEdit: event),
                            )).then((_) {
                              setState(() {}); // reload details
                            });
                          },
                        ),
                      ),
                    ),
                    // Delete Event
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(Icons.delete_rounded, color: Colors.redAccent, size: 20),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Event'),
                                content: const Text('Are you sure you want to permanently delete this event? This action cannot be undone.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await ref.read(eventsProvider.notifier).deleteEvent(event.id);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event deleted successfully')));
                                Navigator.pop(context);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
                              }
                            }
                          },
                        ),
                      ),
                    ),
                    // Organizer Dashboard Link
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: CircleAvatar(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        child: IconButton(
                          icon: const Icon(Icons.dashboard_rounded, color: Colors.white, size: 20),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => EventOrganizerDashboardScreen(event: event),
                            ));
                          },
                        ),
                      ),
                    ),
                  ]
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F9EFF).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              event.eventType.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(color: Color(0xFF4F9EFF), fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            event.isPaid ? '৳ ${event.entryFee}' : 'FREE',
                            style: TextStyle(
                              color: event.isPaid ? const Color(0xFF4F9EFF) : Colors.green,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        event.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 16),
                      
                      // Seat counter
                      Card(
                        elevation: 0,
                        color: Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    '$_liveRegisteredCount / ${event.seatCapacity}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                  const Text('Seats Filled', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                              const VerticalDivider(),
                              Column(
                                children: [
                                  Text(
                                    '${max(0, event.seatCapacity - _liveRegisteredCount)}',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                  const Text('Available', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy · hh:mm a').format(event.eventDate),
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            event.isOnline ? 'Online Webinar (Link provided below)' : event.venue,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        event.description,
                        style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      if (event.isOnline && event.onlineLink != null && (!event.requiresRegistration || (_userRegistration != null && _userRegistration!.registrationStatus == 'confirmed'))) ...[
                        ElevatedButton.icon(
                          onPressed: () => launchUrl(Uri.parse(event.onlineLink!)),
                          icon: const Icon(Icons.videocam_rounded),
                          label: const Text('Join Online Session'),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Speakers Section
                      if (event.speakers.isNotEmpty) ...[
                        const Text('Guest Speakers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: event.speakers.length,
                            itemBuilder: (context, idx) {
                              final speaker = event.speakers[idx];
                              return Card(
                                margin: const EdgeInsets.only(right: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: speaker.photoUrl != null 
                                            ? NetworkImage(speaker.photoUrl!) 
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(speaker.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(speaker.designation, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(speaker.institution, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Registration CTA (Students only)
                      if (event.canRegister && _userRegistration == null && _userRole == UserRole.student)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => EventRegistrationScreen(event: event),
                              )).then((_) => _fetchUserRegistration());
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F9EFF),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Register Now', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        )
                      else if (_userRegistration != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _userRegistration!.registrationStatus == 'confirmed' ? Colors.green.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _userRegistration!.registrationStatus == 'confirmed' ? Colors.green.shade200 : Colors.amber.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _userRegistration!.registrationStatus == 'confirmed' 
                                        ? Icons.check_circle_rounded 
                                        : Icons.pending_rounded,
                                    color: _userRegistration!.registrationStatus == 'confirmed' ? Colors.green : Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _userRegistration!.registrationStatus == 'confirmed' 
                                        ? 'Registration Confirmed' 
                                        : 'Registration Pending',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _userRegistration!.registrationStatus == 'confirmed' ? Colors.green : Colors.amber.shade800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Attendee: ${_userRegistration!.fullName}',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              const SizedBox(height: 4),
                              Text('Student ID: ${_userRegistration!.studentFacultyId}'),
                              if (event.isPaid) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Payment Status: ${_userRegistration!.paymentStatus.toUpperCase()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _userRegistration!.paymentStatus == 'verified'
                                        ? Colors.green
                                        : _userRegistration!.paymentStatus == 'rejected'
                                            ? Colors.red
                                            : Colors.amber.shade800,
                                  ),
                                ),
                                if (_userRegistration!.paymentStatus == 'pending') ...[
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Waiting for organizer to verify your payment.',
                                    style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _isLoadingRegistration ? null : () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Unregister from Event'),
                                  content: const Text('Are you sure you want to unregister from this event? If paid, refunds are subject to organizer policy.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Unregister'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                setState(() => _isLoadingRegistration = true);
                                try {
                                  await ref.read(eventRegistrationProvider.notifier).cancelRegistration(_userRegistration!.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Successfully unregistered from event.')),
                                  );
                                  _fetchUserRegistration();
                                  _loadEventDetail();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to unregister: $e')),
                                  );
                                } finally {
                                  setState(() => _isLoadingRegistration = false);
                                }
                              }
                            },
                            icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                            label: const Text('Unregister / Cancel Registration', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]
                      else if (event.isUserRegistered)
                        const Center(child: CircularProgressIndicator())
                      else if (event.isFull && event.requiresRegistration && _userRole == UserRole.student)
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () {
                              // Join waitlist flow
                            },
                            child: const Text('Join Waitlist'),
                          ),
                        )
                    ],
                  ),
                ),
              )
            ],
          );
        },
      ),
    );
  }

  int max(int a, int b) => a > b ? a : b;
}
