import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/events_provider.dart';
import '../../data/models/event_model.dart';

class EventCreateScreen extends ConsumerStatefulWidget {
  final EventModel? eventToEdit;
  const EventCreateScreen({super.key, this.eventToEdit});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  int _currentStep = 0;
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _capacityController = TextEditingController();
  final _feeController = TextEditingController();
  final _instructionsController = TextEditingController();

  String _selectedType = 'workshop';
  bool _isOnline = false;
  bool _isPaid = false;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 7));
  DateTime _deadline = DateTime.now().add(const Duration(days: 5));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 13, minute: 0);
  bool _submitting = false;
  Uint8List? _bannerBytes;
  String? _bannerName;

  @override
  void initState() {
    super.initState();
    if (widget.eventToEdit != null) {
      final evt = widget.eventToEdit!;
      _titleController.text = evt.title;
      _descriptionController.text = evt.description;
      _venueController.text = evt.venue;
      _capacityController.text = evt.seatCapacity.toString();
      _feeController.text = evt.entryFee.toString();
      _instructionsController.text = evt.paymentInstructions ?? '';
      _selectedType = evt.eventType;
      _isOnline = evt.isOnline;
      _isPaid = evt.isPaid;
      _eventDate = evt.eventDate;
      _deadline = evt.registrationDeadline;
      _startTime = TimeOfDay.fromDateTime(evt.eventDate);
      _endTime = TimeOfDay.fromDateTime(evt.eventEndDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _capacityController.dispose();
    _feeController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _submit() async {
    final startDateTime = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      _eventDate.year,
      _eventDate.month,
      _eventDate.day,
      _endTime.hour,
      _endTime.minute,
    );

    if (endDateTime.isBefore(startDateTime) || endDateTime.isAtSameMomentAs(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final data = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'event_type': _selectedType,
      'venue': _venueController.text,
      'is_online': _isOnline,
      'event_date': startDateTime.toIso8601String(),
      'event_end_date': endDateTime.toIso8601String(),
      'registration_deadline': _deadline.toIso8601String(),
      'seat_capacity': int.tryParse(_capacityController.text) ?? 50,
      'requires_registration': true,
      'is_paid': _isPaid,
      'entry_fee_bdt': _isPaid ? (double.tryParse(_feeController.text) ?? 0.0) : 0.0,
      'payment_instructions': _instructionsController.text,
      'status': widget.eventToEdit?.status ?? 'upcoming',
      'time': '',
      'created_by_name': 'Organizer',
    };

    try {
      if (widget.eventToEdit != null) {
        await ref.read(eventsProvider.notifier).updateEvent(widget.eventToEdit!.id, data, _bannerBytes, _bannerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event updated successfully!')));
          Navigator.pop(context);
        }
      } else {
        await ref.read(eventsProvider.notifier).createEvent(data, _bannerBytes, _bannerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event published successfully!')));
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.eventToEdit != null ? 'Edit Event' : 'Create Event'),
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep == 0 && _formKey1.currentState!.validate()) {
            setState(() => _currentStep++);
          } else if (_currentStep == 1 && _formKey2.currentState!.validate()) {
            setState(() => _currentStep++);
          } else if (_currentStep == 2 && _formKey3.currentState!.validate()) {
            _submit();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        steps: [
          Step(
            title: const Text('Basic Information'),
            isActive: _currentStep >= 0,
            content: Form(
              key: _formKey1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Event Cover Image', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _bannerBytes != null
                            ? Image.memory(
                                _bannerBytes!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Image.network(
                                'https://images.unsplash.com/photo-1540575467063-178a50c2df87?w=800',
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                      ),
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.edit_rounded, color: Color(0xFF4F9EFF)),
                            onPressed: () async {
                              final picker = ImagePicker();
                              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                              if (file != null) {
                                final bytes = await file.readAsBytes();
                                setState(() {
                                  _bannerBytes = bytes;
                                  _bannerName = file.name;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      if (_bannerBytes != null)
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _bannerBytes = null;
                                  _bannerName = null;
                                });
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Event Title'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    items: const [
                      DropdownMenuItem(value: 'workshop', child: Text('Workshop')),
                      DropdownMenuItem(value: 'seminar', child: Text('Seminar')),
                      DropdownMenuItem(value: 'hackathon', child: Text('Hackathon')),
                      DropdownMenuItem(value: 'cultural_program', child: Text('Cultural Program')),
                      DropdownMenuItem(value: 'sports_competition', child: Text('Sports Competition')),
                      DropdownMenuItem(value: 'webinar', child: Text('Webinar')),
                      DropdownMenuItem(value: 'fest', child: Text('Fest / Carnival')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) => setState(() => _selectedType = val!),
                    decoration: const InputDecoration(labelText: 'Event Type'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Date, Time & Venue'),
            isActive: _currentStep >= 1,
            content: Form(
              key: _formKey2,
              child: Column(
                children: [
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(labelText: 'Venue / Online Link'),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Is this an online event?'),
                    value: _isOnline,
                    onChanged: (val) => setState(() => _isOnline = val),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Event Date'),
                    subtitle: Text(DateFormat('yyyy-MM-dd').format(_eventDate)),
                    trailing: const Icon(Icons.calendar_month_rounded),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _eventDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (selected != null) {
                        setState(() {
                          _eventDate = DateTime(selected.year, selected.month, selected.day);
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          title: const Text('Start Time'),
                          subtitle: Text(_startTime.format(context)),
                          trailing: const Icon(Icons.access_time_rounded),
                          onTap: () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: _startTime,
                            );
                            if (selected != null) {
                              setState(() {
                                _startTime = selected;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ListTile(
                          title: const Text('End Time'),
                          subtitle: Text(_endTime.format(context)),
                          trailing: const Icon(Icons.access_time_rounded),
                          onTap: () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: _endTime,
                            );
                            if (selected != null) {
                              setState(() {
                                _endTime = selected;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Capacity & Payment'),
            isActive: _currentStep >= 2,
            content: Form(
              key: _formKey3,
              child: Column(
                children: [
                  TextFormField(
                    controller: _capacityController,
                    decoration: const InputDecoration(labelText: 'Seat Capacity'),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || int.tryParse(val) == null ? 'Enter valid number' : null,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Is this a paid event?'),
                    value: _isPaid,
                    onChanged: (val) => setState(() => _isPaid = val),
                  ),
                  if (_isPaid) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _feeController,
                      decoration: const InputDecoration(labelText: 'Entry Fee (BDT)'),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || double.tryParse(val) == null ? 'Enter fee amount' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(labelText: 'Payment Instructions'),
                      maxLines: 2,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_submitting) const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
