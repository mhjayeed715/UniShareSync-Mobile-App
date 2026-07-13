import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:unisharesync_mobile_app/data/models/whiteboard_model.dart';
import 'package:unisharesync_mobile_app/providers/whiteboard_providers.dart';
import 'package:unisharesync_mobile_app/services/auth_service.dart';
import 'package:unisharesync_mobile_app/data/models/user_role.dart';

class ProjectWhiteboardScreen extends ConsumerStatefulWidget {
  const ProjectWhiteboardScreen({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectWhiteboardScreen> createState() => _ProjectWhiteboardScreenState();
}

class _ProjectWhiteboardScreenState extends ConsumerState<ProjectWhiteboardScreen> {
  final TransformationController _transformationController = TransformationController();
  final String _currentSessionStrokeId = const Uuid().v4();
  bool _isReadOnly = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final role = await AuthService().getCurrentRole();
    if (role == UserRole.faculty) {
      setState(() => _isReadOnly = true);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardState = ref.watch(whiteboardBoardProvider(widget.projectId));
    final notifier = ref.read(whiteboardBoardProvider(widget.projectId).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isReadOnly ? 'Whiteboard (Read Only)' : 'Brainstorm Board',
          style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          // Active cursors count
          Row(
            children: [
              const Icon(Icons.people, color: Colors.green),
              const SizedBox(width: 4),
              Text(
                '${boardState.activeUsers.length + 1}',
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
            ],
          ),
          if (!_isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: () => notifier.clearCanvas(),
            ),
        ],
      ),
      body: boardState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Zoomable/Pannable Whiteboard area
                InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.5,
                  maxScale: 3.0,
                  constrained: false, // Allows the 4000x4000 virtual canvas
                  child: Container(
                    width: 4000,
                    height: 4000,
                    color: Colors.white,
                    child: Stack(
                      children: [
                        // Background coordinate grid lines
                        const Positioned.fill(
                          child: CustomPaint(
                            painter: GridLinesPainter(),
                          ),
                        ),

                        // Draw Vectors Painter
                        Positioned.fill(
                          child: GestureDetector(
                            onPanStart: _isReadOnly
                                ? null
                                : (details) {
                                    final renderBox = context.findRenderObject() as RenderBox;
                                    final localPos = renderBox.globalToLocal(details.globalPosition);
                                    
                                    // Translate position based on zoom scale Matrix4
                                    final offset = _transformationController.toScene(localPos);

                                    final strokeId = const Uuid().v4();
                                    notifier.drawStrokeStart(
                                      strokeId,
                                      StrokePoint(x: offset.dx, y: offset.dy),
                                    );
                                  },
                            onPanUpdate: _isReadOnly
                                ? null
                                : (details) {
                                    final renderBox = context.findRenderObject() as RenderBox;
                                    final localPos = renderBox.globalToLocal(details.globalPosition);
                                    final offset = _transformationController.toScene(localPos);

                                    final strokesList = ref.read(whiteboardBoardProvider(widget.projectId)).canvasState.strokes;
                                    if (strokesList.isNotEmpty) {
                                      final lastStrokeId = strokesList.last.id;
                                      notifier.drawStrokePoint(
                                        lastStrokeId,
                                        StrokePoint(x: offset.dx, y: offset.dy),
                                      );
                                    }
                                    
                                    notifier.broadcastCursor(offset.dx, offset.dy);
                                  },
                            child: CustomPaint(
                              painter: WhiteboardPainter(strokes: boardState.canvasState.strokes),
                            ),
                          ),
                        ),

                        // Sticky Notes Layout
                        ...boardState.canvasState.stickyNotes.map((note) {
                          return Positioned(
                            left: note.x,
                            top: note.y,
                            child: _buildStickyNoteWidget(note, notifier),
                          );
                        }),

                        // Users Presence Cursors
                        ...boardState.activeUsers.values.map((user) {
                          return Positioned(
                            left: user.cursorX,
                            top: user.cursorY,
                            child: _buildPresenceCursorWidget(user),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Pen tools bottom deck (only visible to student drawers)
                if (!_isReadOnly)
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: _buildDrawingToolbox(notifier, boardState),
                  ),
              ],
            ),
    );
  }

  Widget _buildStickyNoteWidget(StickyNote note, WhiteboardNotifier notifier) {
    return GestureDetector(
      onPanUpdate: _isReadOnly
          ? null
          : (details) {
               notifier.moveStickyNote(
                 note.id,
                 note.x + details.delta.dx,
                 note.y + details.delta.dy,
               );
             },
      child: Card(
        color: Color(int.parse(note.color.replaceFirst('#', '0xFF'))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Container(
          width: note.width,
          height: note.height,
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Text(
              note.text,
              style: TextStyle(
                color: Colors.black87,
                fontFamily: 'Outfit',
                fontSize: note.fontSize,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresenceCursorWidget(PresenceUser user) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.navigation,
          color: Color(int.parse(user.avatarColor.replaceFirst('#', '0xFF'))),
          size: 20,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Color(int.parse(user.avatarColor.replaceFirst('#', '0xFF'))),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            user.displayName,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawingToolbox(WhiteboardNotifier notifier, WhiteboardBoardState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85),
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: state.selectedTool == 'pen' ? const Color(0xFF2563EB) : Colors.grey.shade700),
                  onPressed: () => notifier.selectTool('pen'),
                ),
                IconButton(
                  icon: Icon(Icons.highlight, color: state.selectedTool == 'highlighter' ? const Color(0xFF2563EB) : Colors.grey.shade700),
                  onPressed: () => notifier.selectTool('highlighter'),
                ),
                IconButton(
                  icon: Icon(Icons.note_add_outlined, color: Colors.grey.shade700),
                  onPressed: () => _showAddStickyNoteDialog(notifier),
                ),
                IconButton(
                  icon: Icon(Icons.undo, color: Colors.grey.shade700),
                  onPressed: () => notifier.undo(),
                ),
                IconButton(
                  icon: Icon(Icons.redo, color: Colors.grey.shade700),
                  onPressed: () => notifier.redo(),
                ),
                const SizedBox(width: 8),
                // Quick colors
                _buildColorSelector('#2563EB', state, notifier),
                const SizedBox(width: 8),
                _buildColorSelector('#EF4444', state, notifier),
                const SizedBox(width: 8),
                _buildColorSelector('#10B981', state, notifier),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorSelector(String hex, WhiteboardBoardState state, WhiteboardNotifier notifier) {
    final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
    final isSelected = state.selectedColor == hex;
    return GestureDetector(
      onTap: () => notifier.selectColor(hex),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.grey.shade800 : Colors.transparent,
            width: 2.0,
          ),
        ),
      ),
    );
  }

  void _showAddStickyNoteDialog(WhiteboardNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Sticky Note'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Note details...'),
        ),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('Add'),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                notifier.addStickyNote(
                  StickyNote(
                    id: const Uuid().v4(),
                    x: 200,
                    y: 200,
                    width: 150,
                    height: 150,
                    color: '#FEF08A',
                    text: text,
                    fontSize: 14,
                    createdBy: Supabase.instance.client.auth.currentUser?.id ?? '',
                  ),
                );
                Navigator.pop(context);
              }
            },
          )
        ],
      ),
    );
  }
}

class GridLinesPainter extends CustomPainter {
  const GridLinesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 1.0;

    const step = 40.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WhiteboardPainter extends CustomPainter {
  const WhiteboardPainter({required this.strokes});

  final List<WhiteboardStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;

      final paint = Paint()
        ..color = Color(int.parse(stroke.color.replaceFirst('#', '0xFF'))).withOpacity(
          stroke.toolType == 'highlighter' ? 0.4 : 1.0,
        )
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.width;

      final path = Path();
      path.moveTo(stroke.points.first.x, stroke.points.first.y);

      for (int i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].x, stroke.points[i].y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WhiteboardPainter oldDelegate) => true;
}
