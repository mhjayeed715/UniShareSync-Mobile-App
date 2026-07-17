import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:unisharesync_mobile_app/features/ai_chat/chat_models.dart';
import 'package:unisharesync_mobile_app/data/models/profile_model.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

/// Service that gathers live campus context from Supabase,
/// invokes the `ai-chat` Edge Function, and streams back tokens.
class AiChatService {
  AiChatService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final String _sessionId = const Uuid().v4();

  final SupabaseClient _client;

  // ──────────────────────────────────────────────
  //  Context gathering (FR39)
  // ──────────────────────────────────────────────

  /// Fetches live campus context from multiple Supabase tables and
  /// returns a formatted string to inject into the AI prompt.
  Future<String> gatherCampusContext({String? userGroupName}) async {
    final parts = <String>[];

    // Fetch logged-in user profile to customize schedule
    ProfileModel? profile;
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final data = await _client.from('profiles').select().eq('id', userId).maybeSingle();
        if (data != null) {
          profile = ProfileModel.fromMap(data);
        }
      }
    } catch (e) {
      debugPrint('Context loading profile error: $e');
    }

    try {
      // 1. Today's schedule
      final now = DateTime.now();
      final dayIndex = now.weekday; // 1=Monday … 7=Sunday

      final rawRoutines = await _client
          .from('routines')
          .select('course_display, course_title, faculty_name, faculty_initial, room, start_minutes, end_minutes, semester, section, group_name')
          .eq('day', _dayName(dayIndex))
          .order('start_minutes', ascending: true);

      final routines = <Map<String, dynamic>>[];
      if (profile != null) {
        if (profile.role == UserRole.student) {
          final semStr = profile.semester ?? '';
          final userSem = int.tryParse(semStr.replaceAll(RegExp(r'[^0-9]'), ''));

          for (final r in rawRoutines as List) {
            final rSem = r['semester'] as int?;
            final rGroup = (r['group_name'] as String?)?.toLowerCase() ?? '';
            final rSection = (r['section'] as String?)?.toLowerCase() ?? '';

            // Filter by semester if profile has one
            if (userSem != null && rSem != null && rSem != userSem) continue;

            // Filter by group name if user provided one
            if (userGroupName != null && userGroupName.trim().isNotEmpty) {
              final groupClean = userGroupName.trim().toLowerCase();
              if (rGroup != groupClean && rSection != groupClean) continue;
            }
            routines.add(Map<String, dynamic>.from(r as Map));
          }
        } else if (profile.role == UserRole.faculty) {
          final userFullName = profile.fullName.toLowerCase();
          final initials = userFullName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).join('');

          for (final r in rawRoutines as List) {
            final rFacName = (r['faculty_name'] as String?)?.toLowerCase() ?? '';
            final rFacInit = (r['faculty_initial'] as String?)?.toLowerCase() ?? '';

            if (rFacName.contains(userFullName) || 
                userFullName.contains(rFacName) ||
                (rFacInit.isNotEmpty && (rFacInit == initials || userFullName.contains(rFacInit)))) {
              routines.add(Map<String, dynamic>.from(r as Map));
            }
          }
        } else {
          // Admin or other roles: include all routines for today (limit to 6)
          routines.addAll((rawRoutines as List).take(6).map((e) => Map<String, dynamic>.from(e as Map)));
        }
      } else {
        // No logged-in profile found: include all routines for today (limit to 6)
        routines.addAll((rawRoutines as List).take(6).map((e) => Map<String, dynamic>.from(e as Map)));
      }

      if (routines.isNotEmpty) {
        final buf = StringBuffer("TODAY'S CLASS SCHEDULE (${_dayName(dayIndex)}):\n");
        for (final r in routines) {
          final start = _minutesToTime(r['start_minutes'] as int? ?? 0);
          final end = _minutesToTime(r['end_minutes'] as int? ?? 0);
          final faculty = r['faculty_name'] ?? r['faculty_initial'] ?? 'Staff';
          final course = r['course_title'] ?? r['course_display'] ?? 'Class';
          buf.writeln(
            '• $start–$end | $course | $faculty | Room: ${r['room']}',
          );
        }
        parts.add(buf.toString());
      } else {
        parts.add("TODAY'S CLASS SCHEDULE: No classes scheduled today (${_dayName(dayIndex)}).");
      }
    } catch (e) {
      debugPrint('Context: routines error: $e');
    }

    try {
      // 2. Upcoming events (next 7 days)
      final upcoming = DateTime.now().toIso8601String();
      final events = await _client
          .from('events')
          .select('title, event_date, venue, status')
          .gte('event_date', upcoming)
          .order('event_date', ascending: true)
          .limit(4);

      if ((events as List).isNotEmpty) {
        final buf = StringBuffer('UPCOMING EVENTS:\n');
        for (final e in events) {
          buf.writeln(
            '• ${e['title']} | ${e['event_date']} | Venue: ${e['venue']} | Status: ${e['status']}',
          );
        }
        parts.add(buf.toString());
      }
    } catch (e) {
      debugPrint('Context: events error: $e');
    }

    try {
      // 3. Active projects (recruiting)
      final projects = await _client
          .from('projects')
          .select('title, description, status, required_skills, current_members, max_members')
          .eq('status', 'recruiting')
          .order('created_at', ascending: false)
          .limit(3);

      if ((projects as List).isNotEmpty) {
        final buf = StringBuffer('ACTIVE PROJECTS (open for collaboration):\n');
        for (final p in projects) {
          final skillsList = p['required_skills'] as List? ?? [];
          final skills = skillsList.take(3).join(', ') + (skillsList.length > 3 ? '...' : '');
          final desc = p['description']?.toString() ?? '';
          final shortDesc = desc.substring(0, desc.length.clamp(0, 50)) + (desc.length > 50 ? '...' : '');
          buf.writeln(
            '• ${p['title']} — $shortDesc | Skills: $skills | Team: ${p['current_members']}/${p['max_members']}',
          );
        }
        parts.add(buf.toString());
      }
    } catch (e) {
      debugPrint('Context: projects error: $e');
    }

    try {
      // 4. Recent notices (last 3)
      final notices = await _client
          .from('notices')
          .select('title, body, priority, created_at')
          .order('created_at', ascending: false)
          .limit(3);

      if ((notices as List).isNotEmpty) {
        final buf = StringBuffer('RECENT NOTICES:\n');
        for (final n in notices) {
          final priorityTag = (n['priority'] ?? 'general').toString().toUpperCase();
          final body = n['body']?.toString() ?? '';
          final shortBody = body.substring(0, body.length.clamp(0, 50)) + (body.length > 50 ? '...' : '');
          buf.writeln(
            '• [$priorityTag] ${n['title']} — $shortBody',
          );
        }
        parts.add(buf.toString());
      }
    } catch (e) {
      debugPrint('Context: notices error: $e');
    }

    try {
      // 5. Open lost & found items
      final lostFound = await _client
          .from('lost_found_reports')
          .select('title, description, report_type, location, status, created_at')
          .eq('status', 'open')
          .order('created_at', ascending: false)
          .limit(3);

      if ((lostFound as List).isNotEmpty) {
        final buf = StringBuffer('OPEN LOST & FOUND ITEMS:\n');
        for (final item in lostFound) {
          final desc = item['description']?.toString() ?? '';
          final shortDesc = desc.substring(0, desc.length.clamp(0, 50)) + (desc.length > 50 ? '...' : '');
          buf.writeln(
            '• [${(item['report_type'] ?? 'unknown').toString().toUpperCase()}] ${item['title']} — $shortDesc | Location: ${item['location']}',
          );
        }
        parts.add(buf.toString());
      }
    } catch (e) {
      debugPrint('Context: lost_found error: $e');
    }

    try {
      // 6. Recent notices from user's joined communities
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final joinedComms = await _client
            .from('community_members')
            .select('community_id, communities(name)')
            .eq('user_id', userId)
            .eq('is_active', true);

        if ((joinedComms as List).isNotEmpty) {
          final commIds = joinedComms.map((c) => c['community_id'].toString()).toList();
          final commNotices = await _client
              .from('community_notices')
              .select('title, body, community_id, communities(name)')
              .inFilter('community_id', commIds)
              .order('created_at', ascending: false)
              .limit(3);

          if ((commNotices as List).isNotEmpty) {
            final buf = StringBuffer('RECENT COMMUNITY ANNOUNCEMENTS:\n');
            for (final cn in commNotices) {
              final commName = cn['communities']?['name'] ?? 'Community';
              final body = cn['body']?.toString() ?? '';
              final shortBody = body.substring(0, body.length.clamp(0, 50)) + (body.length > 50 ? '...' : '');
              buf.writeln('• [$commName] ${cn['title']} — $shortBody');
            }
            parts.add(buf.toString());
          }
        }
      }
    } catch (e) {
      debugPrint('Context: community notices error: $e');
    }

    try {
      final alumni = await _client
          .from('alumni_profiles')
          .select('id, full_name, batch_year, current_job_title, current_company, current_location, is_open_to_mentor')
          .eq('is_verified', true)
          .eq('is_published', true)
          .limit(8);

      if ((alumni as List).isNotEmpty) {
        final buf = StringBuffer('SMUCT ALUMNI NETWORK & MENTORS (Share unisharesync://alumni/detail/{id} for clicks):\n');
        for (final al in alumni) {
          final role = al['current_job_title'] ?? 'Alumnus';
          final company = al['current_company'] ?? 'SMUCT';
          final loc = al['current_location'] ?? 'Dhaka, Bangladesh';
          final mentorStatus = al['is_open_to_mentor'] == true ? '[Mentor - Available]' : '';
          buf.writeln(
            '• ${al['full_name']} (Batch ${al['batch_year']}) | Role: $role at $company | Location: $loc $mentorStatus | Profile Link: unisharesync://alumni/detail/${al['id']}',
          );
        }
        parts.add(buf.toString());
      }
    } catch (e) {
      debugPrint('Context: alumni error: $e');
    }

    try {
      // 7. Campus Share active listings
      final listings = await _client
          .from('campus_share_listings')
          .select('title, description, category, condition')
          .eq('status', 'available')
          .eq('admin_approved', true)
          .eq('is_draft', false)
          .order('created_at', ascending: false)
          .limit(4);

      if ((listings as List).isNotEmpty) {
        final buf = StringBuffer('CAMPUS SHARE — AVAILABLE ITEMS TO BORROW:\n');
        for (final l in listings) {
          final desc = l['description']?.toString() ?? '';
          final shortDesc = desc.substring(0, desc.length.clamp(0, 50)) + (desc.length > 50 ? '...' : '');
          buf.writeln('• ${l['title']} | Category: ${l['category']} | Condition: ${l['condition']} — $shortDesc');
        }
        parts.add(buf.toString());
      }
    } catch (e) {
      debugPrint('Context: campus share error: $e');
    }

    try {
      // 8. User's joined communities
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final communities = await _client
            .from('community_members')
            .select('communities(name, description, member_count)')
            .eq('user_id', userId)
            .eq('is_active', true)
            .limit(5);

        if ((communities as List).isNotEmpty) {
          final buf = StringBuffer('YOUR COMMUNITIES / CLUBS:\n');
          for (final c in communities) {
            final comm = c['communities'] as Map?;
            if (comm != null) {
              buf.writeln('• ${comm['name']} — ${comm['description']?.toString().substring(0, (comm['description']?.toString().length ?? 0).clamp(0, 60)) ?? ''} | Members: ${comm['member_count']}');
            }
          }
          parts.add(buf.toString());
        }
      }
    } catch (e) {
      debugPrint('Context: communities error: $e');
    }

    if (parts.isEmpty) {
      return 'No live campus data could be fetched at this time.';
    }

    return parts.join('\n\n');
  }

  // ──────────────────────────────────────────────
  //  Edge Function streaming call (FR40 + FR41)
  // ──────────────────────────────────────────────

  /// Sends the user prompt + context to the `ai-chat` Edge Function
  /// and yields a stream of [AiChatEvent] (tokens and suggestions).
  Stream<AiChatEvent> streamResponse(
    String prompt, {
    String? userApiKey,
    String? userGroupName,
    String? courseCode,
    int? semester,
  }) async* {
    final context = await gatherCampusContext(userGroupName: userGroupName);

    final url = Uri.parse(
      '${_client.rest.url.replaceAll('/rest/v1', '')}/functions/v1/ai-chat',
    );

    final request = http.Request('POST', url);
    request.headers.addAll({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${_client.auth.currentSession?.accessToken ?? ''}',
      'apikey': _client.rest.headers['apikey'] ?? '',
      // Legacy: pass key via header for users who haven't migrated to server-stored key
      if (userApiKey != null && userApiKey.trim().isNotEmpty && userApiKey.startsWith('gsk_'))
        'x-user-groq-key': userApiKey,
    });
    request.body = jsonEncode({
      'prompt': prompt,
      'context': context,
      'session_id': _sessionId,
      if (courseCode != null) 'course_code': courseCode,
      if (semester != null) 'semester': semester,
    });

    final httpClient = http.Client();

    try {
      final streamedResponse = await httpClient.send(request);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed.containsKey('message')) {
            yield AiChatEvent.error(parsed['message'] as String);
            return;
          }
        } catch (_) {}
        yield AiChatEvent.error('Server error (${streamedResponse.statusCode}): $body');
        return;
      }

      // Parse SSE stream
      String buffer = '';
      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        // Keep the last potentially-incomplete line in the buffer
        buffer = lines.removeLast();

        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;

          final jsonStr = line.substring(6).trim();
          if (jsonStr.isEmpty || jsonStr == '[DONE]') continue;

          try {
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;

            if (parsed.containsKey('error')) {
              yield AiChatEvent.error(parsed['error'] as String);
              return;
            }

            if (parsed.containsKey('token')) {
              yield AiChatEvent.token(parsed['token'] as String);
            }

            if (parsed['done'] == true) {
              final rawSuggestions = (parsed['suggestions'] as List<dynamic>?) ?? [];
              final chips = rawSuggestions
                  .map((s) => SuggestionChip.fromMap(
                        Map<String, dynamic>.from(s as Map),
                      ))
                  .toList(growable: false);

              // Parse new metadata fields
              AiCitation? citation;
              final rawCitation = parsed['citation'];
              if (rawCitation is Map) {
                citation = AiCitation.fromMap(Map<String, dynamic>.from(rawCitation));
              }

              yield AiChatEvent.done(
                chips,
                citation: citation,
                usedRag: parsed['used_rag'] as bool? ?? false,
                fromCache: parsed['from_cache'] as bool? ?? false,
                questionsUsed: parsed['questions_used'] as int?,
                questionsLimit: parsed['questions_limit'] as int?,
                usingOwnKey: parsed['using_own_key'] as bool? ?? false,
              );
            }

            // Handle quota exceeded error returned inside SSE stream
            if (parsed.containsKey('error') && parsed['error'] == 'quota_exceeded') {
              yield AiChatEvent.quotaExceeded(
                questionsUsed: parsed['questions_used'] as int? ?? 5,
                questionsLimit: parsed['questions_limit'] as int? ?? 5,
              );
            }
          } catch (_) {
            // Skip malformed JSON
          }
        }
      }

      // Process any remaining buffer
      if (buffer.trim().startsWith('data: ')) {
        final jsonStr = buffer.trim().substring(6).trim();
        if (jsonStr.isNotEmpty && jsonStr != '[DONE]') {
          try {
            final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
            if (parsed.containsKey('token')) {
              yield AiChatEvent.token(parsed['token'] as String);
            }
            if (parsed['done'] == true) {
              final rawSuggestions = (parsed['suggestions'] as List<dynamic>?) ?? [];
              final chips = rawSuggestions
                  .map((s) => SuggestionChip.fromMap(
                        Map<String, dynamic>.from(s as Map),
                      ))
                  .toList(growable: false);
              AiCitation? citation;
              final rawCitation = parsed['citation'];
              if (rawCitation is Map) {
                citation = AiCitation.fromMap(Map<String, dynamic>.from(rawCitation));
              }
              yield AiChatEvent.done(
                chips,
                citation: citation,
                usedRag: parsed['used_rag'] as bool? ?? false,
                fromCache: parsed['from_cache'] as bool? ?? false,
                questionsUsed: parsed['questions_used'] as int?,
                questionsLimit: parsed['questions_limit'] as int?,
                usingOwnKey: parsed['using_own_key'] as bool? ?? false,
              );
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      yield AiChatEvent.error('Connection error: $e');
    } finally {
      httpClient.close();
    }
  }

  // ──────────────────────────────────────────────
  //  Helpers
  // ──────────────────────────────────────────────

  String _dayName(int weekday) {
    const names = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return (weekday >= 1 && weekday <= 7) ? names[weekday] : 'Unknown';
  }

  String _minutesToTime(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }
}

/// Discriminated union for SSE events from the AI chat stream.
sealed class AiChatEvent {
  const AiChatEvent();

  factory AiChatEvent.token(String text) = AiTokenEvent;
  factory AiChatEvent.done(
    List<SuggestionChip> suggestions, {
    AiCitation? citation,
    bool usedRag,
    bool fromCache,
    int? questionsUsed,
    int? questionsLimit,
    bool usingOwnKey,
  }) = AiDoneEvent;
  factory AiChatEvent.error(String message) = AiErrorEvent;
  factory AiChatEvent.quotaExceeded({
    required int questionsUsed,
    required int questionsLimit,
  }) = AiQuotaExceededEvent;
}

class AiTokenEvent extends AiChatEvent {
  const AiTokenEvent(this.text);
  final String text;
}

class AiDoneEvent extends AiChatEvent {
  const AiDoneEvent(
    this.suggestions, {
    this.citation,
    this.usedRag = false,
    this.fromCache = false,
    this.questionsUsed,
    this.questionsLimit,
    this.usingOwnKey = false,
  });
  final List<SuggestionChip> suggestions;
  final AiCitation? citation;
  final bool usedRag;
  final bool fromCache;
  final int? questionsUsed;
  final int? questionsLimit;
  final bool usingOwnKey;
}

class AiErrorEvent extends AiChatEvent {
  const AiErrorEvent(this.message);
  final String message;
}

class AiQuotaExceededEvent extends AiChatEvent {
  const AiQuotaExceededEvent({
    required this.questionsUsed,
    required this.questionsLimit,
  });
  final int questionsUsed;
  final int questionsLimit;
}
