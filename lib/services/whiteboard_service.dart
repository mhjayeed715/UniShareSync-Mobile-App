import 'dart:convert';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:unisharesync_mobile_app/data/models/whiteboard_model.dart';
import 'package:uuid/uuid.dart';

class WhiteboardService {
  WhiteboardService({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // Storage bucket constants
  static const String bucketId = 'project-assets';

  Future<WhiteboardCanvasState> loadWhiteboardState(String projectId) async {
    try {
      final String snapshotPath = 'whiteboards/$projectId/snapshot.json';
      
      // Download bytes from Supabase Storage
      final Uint8List fileBytes = await _client.storage.from(bucketId).download(snapshotPath);
      final String jsonStr = utf8.decode(fileBytes);
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      
      return WhiteboardCanvasState.fromMap(map);
    } catch (_) {
      // If snapshot is missing (first time opening), return a clean empty board state
      return WhiteboardCanvasState(
        projectId: projectId,
        lastSavedAt: DateTime.now(),
        canvasWidth: 4000.0,
        canvasHeight: 4000.0,
        zoomLevel: 1.0,
        strokes: const [],
        stickyNotes: const [],
        filePins: const [],
        voicePins: const [],
        textBoxes: const [],
      );
    }
  }

  Future<void> saveWhiteboardState(String projectId, WhiteboardCanvasState state) async {
    final String snapshotPath = 'whiteboards/$projectId/snapshot.json';
    
    final Map<String, dynamic> stateMap = state.toMap();
    stateMap['last_saved_at'] = DateTime.now().toIso8601String();
    
    final String jsonStr = json.encode(stateMap);
    final List<int> bytes = utf8.encode(jsonStr);
    final Uint8List uint8list = Uint8List.fromList(bytes);

    // Upload snapshot to bucket (overwrite if exists)
    await _client.storage.from(bucketId).uploadBinary(
          snapshotPath,
          uint8list,
          fileOptions: const FileOptions(upsert: true, contentType: 'application/json'),
        );

    // Track snapshot logs in table
    try {
      await _client.from('whiteboard_snapshots').insert({
        'project_id': projectId,
        'snapshot_url': snapshotPath,
        'snapshot_size_bytes': uint8list.length,
        'saved_by': currentUserId,
      });
    } catch (_) {
      // Table write failure is non-blocking
    }
  }

  Future<String> exportWhiteboardPng(String projectId, Uint8List imageBytes) async {
    final String uuid = const Uuid().v4();
    final String exportPath = 'whiteboards/$projectId/exports/$uuid.png';

    await _client.storage.from(bucketId).uploadBinary(
          exportPath,
          imageBytes,
          fileOptions: const FileOptions(contentType: 'image/png'),
        );

    return _client.storage.from(bucketId).getPublicUrl(exportPath);
  }

  Future<String> uploadWhiteboardVoice(String projectId, List<int> voiceBytes) async {
    final String uuid = const Uuid().v4();
    final String voicePath = 'voice-notes/$projectId/whiteboard/$uuid.m4a';

    await _client.storage.from(bucketId).uploadBinary(
          voicePath,
          Uint8List.fromList(voiceBytes),
          fileOptions: const FileOptions(contentType: 'audio/m4a'),
        );

    return voicePath;
  }

  Future<String> uploadTaskAttachmentFile(String projectId, String taskId, String filename, List<int> bytes) async {
    final String filePath = 'task-attachments/$projectId/$taskId/$filename';

    await _client.storage.from(bucketId).uploadBinary(
          filePath,
          Uint8List.fromList(bytes),
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from(bucketId).getPublicUrl(filePath);
  }

  Future<String> uploadTaskVoiceNote(String projectId, String taskId, List<int> voiceBytes) async {
    final String uuid = const Uuid().v4();
    final String voicePath = 'voice-notes/$projectId/$taskId/$uuid.m4a';

    await _client.storage.from(bucketId).uploadBinary(
          voicePath,
          Uint8List.fromList(voiceBytes),
          fileOptions: const FileOptions(contentType: 'audio/m4a'),
        );

    return _client.storage.from(bucketId).getPublicUrl(voicePath);
  }
}
