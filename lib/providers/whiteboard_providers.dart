import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:unisharesync_mobile_app/data/models/whiteboard_model.dart';
import 'package:unisharesync_mobile_app/services/whiteboard_service.dart';

final whiteboardServiceProvider = Provider<WhiteboardService>((ref) {
  return WhiteboardService();
});

class PresenceUser {
  const PresenceUser({
    required this.sessionId,
    required this.userId,
    required this.displayName,
    required this.avatarColor,
    required this.cursorX,
    required this.cursorY,
    required this.lastSeen,
  });

  final String sessionId;
  final String userId;
  final String displayName;
  final String avatarColor;
  final double cursorX;
  final double cursorY;
  final DateTime lastSeen;

  factory PresenceUser.fromMap(Map<String, dynamic> map) {
    return PresenceUser(
      sessionId: map['session_id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      displayName: map['display_name'] as String? ?? 'Teammate',
      avatarColor: map['avatar_color'] as String? ?? '#2563EB',
      cursorX: (map['cursor_x'] as num? ?? 0.0).toDouble(),
      cursorY: (map['cursor_y'] as num? ?? 0.0).toDouble(),
      lastSeen: DateTime.parse(map['last_seen'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

class WhiteboardBoardState {
  const WhiteboardBoardState({
    required this.canvasState,
    required this.activeUsers,
    this.isLoading = false,
    this.isReady = false,
    this.errorMessage,
    this.selectedTool = 'pen',
    this.selectedColor = '#2563EB',
    this.selectedWidth = 3.0,
  });

  final WhiteboardCanvasState canvasState;
  final Map<String, PresenceUser> activeUsers;
  final bool isLoading;
  final bool isReady;
  final String? errorMessage;
  final String selectedTool;
  final String selectedColor;
  final double selectedWidth;

  WhiteboardBoardState copyWith({
    WhiteboardCanvasState? canvasState,
    Map<String, PresenceUser>? activeUsers,
    bool? isLoading,
    bool? isReady,
    String? errorMessage,
    String? selectedTool,
    String? selectedColor,
    double? selectedWidth,
  }) {
    return WhiteboardBoardState(
      canvasState: canvasState ?? this.canvasState,
      activeUsers: activeUsers ?? this.activeUsers,
      isLoading: isLoading ?? this.isLoading,
      isReady: isReady ?? this.isReady,
      errorMessage: errorMessage ?? this.errorMessage,
      selectedTool: selectedTool ?? this.selectedTool,
      selectedColor: selectedColor ?? this.selectedColor,
      selectedWidth: selectedWidth ?? this.selectedWidth,
    );
  }
}

class WhiteboardNotifier extends StateNotifier<WhiteboardBoardState> {
  WhiteboardNotifier(this._service, String projectId)
      : _projectId = projectId,
        _sessionId = Uuid().v4(),
        super(WhiteboardBoardState(
          canvasState: WhiteboardCanvasState(
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
          ),
          activeUsers: const {},
          isLoading: true,
        )) {
    _init();
  }

  final WhiteboardService _service;
  final String _projectId;
  final String _sessionId;
  RealtimeChannel? _broadcastChannel;
  RealtimeChannel? _presenceChannel;
  Timer? _saveTimer;
  final List<WhiteboardStroke> _undoStack = [];
  final List<WhiteboardStroke> _redoStack = [];

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final initialCanvas = await _service.loadWhiteboardState(_projectId);
      state = state.copyWith(canvasState: initialCanvas, isLoading: false);
      
      _connectRealtime();
      _startAutoSaveTimer();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void _connectRealtime() {
    final client = Supabase.instance.client;
    final currentUserId = _service.currentUserId ?? 'anonymous';

    // 1. Broadcast sync channel
    _broadcastChannel = client.channel('whiteboard_broadcast_$_projectId');
    
    _broadcastChannel?.onBroadcast(
      event: 'stroke_start',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final stroke = WhiteboardStroke.fromMap(data);
        _addStrokeLocally(stroke);
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'stroke_point',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final strokeId = data['stroke_id'] as String;
        final point = StrokePoint.fromMap(data['point']);
        _appendPointLocally(strokeId, point);
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'sticky_note_add',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final note = StickyNote.fromMap(data);
        _addStickyNoteLocally(note);
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'sticky_note_move',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        _moveStickyNoteLocally(data['note_id'], (data['x'] as num).toDouble(), (data['y'] as num).toDouble());
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'file_pin_add',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final pin = FilePin.fromMap(data);
        _addFilePinLocally(pin);
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'voice_pin_add',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final pin = VoicePin.fromMap(data);
        _addVoicePinLocally(pin);
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'canvas_clear',
      callback: (payload) {
        _clearLocally();
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'stroke_undo',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final strokeId = data['stroke_id'] as String;
        _removeStrokeLocally(strokeId);
      },
    );

    _broadcastChannel?.onBroadcast(
      event: 'stroke_redo',
      callback: (payload) {
        final data = payload['payload'] as Map<String, dynamic>? ?? payload;
        final stroke = WhiteboardStroke.fromMap(data);
        _addStrokeLocally(stroke);
      },
    );

    _broadcastChannel?.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        state = state.copyWith(isReady: true);
      }
    });

    // Presence tracking features removed based on touchscreen user preference
  }

  void _startAutoSaveTimer() {
    _saveTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (state.canvasState.strokes.isNotEmpty || state.canvasState.stickyNotes.isNotEmpty) {
        try {
          await _service.saveWhiteboardState(_projectId, state.canvasState);
        } catch (_) {}
      }
    });
  }

  // --- Local modifications & Broadcast emitters ---

  void selectTool(String tool) {
    state = state.copyWith(selectedTool: tool);
  }

  void selectColor(String hexColor) {
    state = state.copyWith(selectedColor: hexColor);
  }

  void selectWidth(double width) {
    state = state.copyWith(selectedWidth: width);
  }

  void drawStrokeStart(String strokeId, StrokePoint startPoint) {
    final stroke = WhiteboardStroke(
      id: strokeId,
      toolType: state.selectedTool,
      color: state.selectedColor,
      width: state.selectedWidth,
      points: [startPoint],
      createdBy: _service.currentUserId ?? 'unknown',
      createdAt: DateTime.now(),
    );

    _addStrokeLocally(stroke);
    _undoStack.add(stroke);
    _redoStack.clear();

    _broadcastChannel?.sendBroadcastMessage(
      event: 'stroke_start',
      payload: stroke.toMap(),
    );
  }

  void drawStrokePoint(String strokeId, StrokePoint point) {
    _appendPointLocally(strokeId, point);

    _broadcastChannel?.sendBroadcastMessage(
      event: 'stroke_point',
      payload: {
        'stroke_id': strokeId,
        'point': point.toMap(),
      },
    );
  }

  void addStickyNote(StickyNote note) {
    _addStickyNoteLocally(note);
    _broadcastChannel?.sendBroadcastMessage(
      event: 'sticky_note_add',
      payload: note.toMap(),
    );
  }

  void moveStickyNote(String noteId, double x, double y) {
    _moveStickyNoteLocally(noteId, x, y);
    _broadcastChannel?.sendBroadcastMessage(
      event: 'sticky_note_move',
      payload: {'note_id': noteId, 'x': x, 'y': y},
    );
  }

  void addFilePin(FilePin pin) {
    _addFilePinLocally(pin);
    _broadcastChannel?.sendBroadcastMessage(
      event: 'file_pin_add',
      payload: pin.toMap(),
    );
  }

  void addVoicePin(VoicePin pin) {
    _addVoicePinLocally(pin);
    _broadcastChannel?.sendBroadcastMessage(
      event: 'voice_pin_add',
      payload: pin.toMap(),
    );
  }

  void broadcastCursor(double x, double y) {
    final currentUserId = _service.currentUserId ?? 'anonymous';
    _presenceChannel?.track({
      'user_id': currentUserId,
      'display_name': 'Teammate',
      'avatar_color': state.selectedColor,
      'cursor_x': x,
      'cursor_y': y,
      'last_seen': DateTime.now().toIso8601String(),
    });
  }

  void clearCanvas() {
    _clearLocally();
    _broadcastChannel?.sendBroadcastMessage(
      event: 'canvas_clear',
      payload: {},
    );
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    final last = _undoStack.removeLast();
    _redoStack.add(last);

    _removeStrokeLocally(last.id);

    _broadcastChannel?.sendBroadcastMessage(
      event: 'stroke_undo',
      payload: {'stroke_id': last.id},
    );
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    final stroke = _redoStack.removeLast();
    _undoStack.add(stroke);
    _addStrokeLocally(stroke);

    _broadcastChannel?.sendBroadcastMessage(
      event: 'stroke_redo',
      payload: stroke.toMap(),
    );
  }

  void _removeStrokeLocally(String strokeId) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: state.canvasState.strokes.where((s) => s.id != strokeId).toList(),
        stickyNotes: state.canvasState.stickyNotes,
        filePins: state.canvasState.filePins,
        voicePins: state.canvasState.voicePins,
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  // --- Local Vector Mutators ---

  void _addStrokeLocally(WhiteboardStroke stroke) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: [...state.canvasState.strokes, stroke],
        stickyNotes: state.canvasState.stickyNotes,
        filePins: state.canvasState.filePins,
        voicePins: state.canvasState.voicePins,
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  void _appendPointLocally(String strokeId, StrokePoint point) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: state.canvasState.strokes.map((s) {
          if (s.id == strokeId) {
            return WhiteboardStroke(
              id: s.id,
              toolType: s.toolType,
              color: s.color,
              width: s.width,
              points: [...s.points, point],
              createdBy: s.createdBy,
              createdAt: s.createdAt,
            );
          }
          return s;
        }).toList(),
        stickyNotes: state.canvasState.stickyNotes,
        filePins: state.canvasState.filePins,
        voicePins: state.canvasState.voicePins,
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  void _addStickyNoteLocally(StickyNote note) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: state.canvasState.strokes,
        stickyNotes: [...state.canvasState.stickyNotes, note],
        filePins: state.canvasState.filePins,
        voicePins: state.canvasState.voicePins,
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  void _moveStickyNoteLocally(String noteId, double x, double y) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: state.canvasState.strokes,
        stickyNotes: state.canvasState.stickyNotes.map((n) {
          if (n.id == noteId) {
            return n.copyWith(x: x, y: y);
          }
          return n;
        }).toList(),
        filePins: state.canvasState.filePins,
        voicePins: state.canvasState.voicePins,
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  void _addFilePinLocally(FilePin pin) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: state.canvasState.strokes,
        stickyNotes: state.canvasState.stickyNotes,
        filePins: [...state.canvasState.filePins, pin],
        voicePins: state.canvasState.voicePins,
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  void _addVoicePinLocally(VoicePin pin) {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: state.canvasState.lastSavedAt,
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: state.canvasState.strokes,
        stickyNotes: state.canvasState.stickyNotes,
        filePins: state.canvasState.filePins,
        voicePins: [...state.canvasState.voicePins, pin],
        textBoxes: state.canvasState.textBoxes,
      ),
    );
  }

  void _clearLocally() {
    state = state.copyWith(
      canvasState: WhiteboardCanvasState(
        projectId: _projectId,
        lastSavedAt: DateTime.now(),
        canvasWidth: state.canvasState.canvasWidth,
        canvasHeight: state.canvasState.canvasHeight,
        zoomLevel: state.canvasState.zoomLevel,
        strokes: const [],
        stickyNotes: const [],
        filePins: const [],
        voicePins: const [],
        textBoxes: const [],
      ),
    );
    _undoStack.clear();
    _redoStack.clear();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _broadcastChannel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    super.dispose();
  }
}

final whiteboardBoardProvider = StateNotifierProvider.family<WhiteboardNotifier, WhiteboardBoardState, String>((ref, projectId) {
  final service = ref.watch(whiteboardServiceProvider);
  return WhiteboardNotifier(service, projectId);
});
