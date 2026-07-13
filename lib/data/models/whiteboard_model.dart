class StrokePoint {
  const StrokePoint({
    required this.x,
    required this.y,
    this.pressure = 1.0,
  });

  final double x;
  final double y;
  final double pressure;

  factory StrokePoint.fromMap(Map<String, dynamic> map) {
    return StrokePoint(
      x: (map['x'] as num? ?? 0.0).toDouble(),
      y: (map['y'] as num? ?? 0.0).toDouble(),
      pressure: (map['pressure'] as num? ?? 1.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'x': x,
        'y': y,
        'pressure': pressure,
      };
}

class WhiteboardStroke {
  const WhiteboardStroke({
    required this.id,
    required this.toolType,
    required this.color,
    required this.width,
    required this.points,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String toolType;
  final String color;
  final double width;
  final List<StrokePoint> points;
  final String createdBy;
  final DateTime createdAt;

  factory WhiteboardStroke.fromMap(Map<String, dynamic> map) {
    final rawPoints = map['points'] as List?;
    final points = rawPoints != null
        ? rawPoints.map((p) => StrokePoint.fromMap(Map<String, dynamic>.from(p))).toList()
        : const <StrokePoint>[];

    return WhiteboardStroke(
      id: map['id'] as String? ?? '',
      toolType: map['tool_type'] as String? ?? 'pen',
      color: map['color'] as String? ?? '#2563EB',
      width: (map['width'] as num? ?? 3.0).toDouble(),
      points: points,
      createdBy: map['created_by'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'tool_type': toolType,
        'color': color,
        'width': width,
        'points': points.map((p) => p.toMap()).toList(),
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };
}

class StickyNote {
  const StickyNote({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
    required this.text,
    required this.fontSize,
    required this.createdBy,
  });

  final String id;
  final double x;
  final double y;
  final double width;
  final double height;
  final String color;
  final String text;
  final double fontSize;
  final String createdBy;

  factory StickyNote.fromMap(Map<String, dynamic> map) {
    return StickyNote(
      id: map['id'] as String? ?? '',
      x: (map['x'] as num? ?? 0.0).toDouble(),
      y: (map['y'] as num? ?? 0.0).toDouble(),
      width: (map['width'] as num? ?? 150.0).toDouble(),
      height: (map['height'] as num? ?? 150.0).toDouble(),
      color: map['color'] as String? ?? '#FEF08A',
      text: map['text'] as String? ?? '',
      fontSize: (map['font_size'] as num? ?? 14.0).toDouble(),
      createdBy: map['created_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'color': color,
        'text': text,
        'font_size': fontSize,
        'created_by': createdBy,
      };

  StickyNote copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    double? height,
    String? color,
    String? text,
    double? fontSize,
    String? createdBy,
  }) {
    return StickyNote(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      color: color ?? this.color,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class FilePin {
  const FilePin({
    required this.id,
    required this.x,
    required this.y,
    required this.resourceId,
    required this.resourceName,
    required this.thumbnailUrl,
    required this.pinnedBy,
  });

  final String id;
  final double x;
  final double y;
  final String resourceId;
  final String resourceName;
  final String thumbnailUrl;
  final String pinnedBy;

  factory FilePin.fromMap(Map<String, dynamic> map) {
    return FilePin(
      id: map['id'] as String? ?? '',
      x: (map['x'] as num? ?? 0.0).toDouble(),
      y: (map['y'] as num? ?? 0.0).toDouble(),
      resourceId: map['resource_id'] as String? ?? '',
      resourceName: map['resource_name'] as String? ?? 'file',
      thumbnailUrl: map['thumbnail_url'] as String? ?? '',
      pinnedBy: map['pinned_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'resource_id': resourceId,
        'resource_name': resourceName,
        'thumbnail_url': thumbnailUrl,
        'pinned_by': pinnedBy,
      };

  FilePin copyWith({
    String? id,
    double? x,
    double? y,
    String? resourceId,
    String? resourceName,
    String? thumbnailUrl,
    String? pinnedBy,
  }) {
    return FilePin(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      resourceId: resourceId ?? this.resourceId,
      resourceName: resourceName ?? this.resourceName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      pinnedBy: pinnedBy ?? this.pinnedBy,
    );
  }
}

class VoicePin {
  const VoicePin({
    required this.id,
    required this.x,
    required this.y,
    required this.storagePath,
    required this.durationSeconds,
    required this.pinnedBy,
    required this.label,
  });

  final String id;
  final double x;
  final double y;
  final String storagePath;
  final int durationSeconds;
  final String pinnedBy;
  final String label;

  factory VoicePin.fromMap(Map<String, dynamic> map) {
    return VoicePin(
      id: map['id'] as String? ?? '',
      x: (map['x'] as num? ?? 0.0).toDouble(),
      y: (map['y'] as num? ?? 0.0).toDouble(),
      storagePath: map['storage_path'] as String? ?? '',
      durationSeconds: map['duration_seconds'] as int? ?? 0,
      pinnedBy: map['pinned_by'] as String? ?? '',
      label: map['label'] as String? ?? 'Audio Clip',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'storage_path': storagePath,
        'duration_seconds': durationSeconds,
        'pinned_by': pinnedBy,
        'label': label,
      };

  VoicePin copyWith({
    String? id,
    double? x,
    double? y,
    String? storagePath,
    int? durationSeconds,
    String? pinnedBy,
    String? label,
  }) {
    return VoicePin(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      storagePath: storagePath ?? this.storagePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      label: label ?? this.label,
    );
  }
}

class TextBox {
  const TextBox({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.text,
    required this.fontSize,
    required this.color,
    required this.createdBy,
  });

  final String id;
  final double x;
  final double y;
  final double width;
  final String text;
  final double fontSize;
  final String color;
  final String createdBy;

  factory TextBox.fromMap(Map<String, dynamic> map) {
    return TextBox(
      id: map['id'] as String? ?? '',
      x: (map['x'] as num? ?? 0.0).toDouble(),
      y: (map['y'] as num? ?? 0.0).toDouble(),
      width: (map['width'] as num? ?? 200.0).toDouble(),
      text: map['text'] as String? ?? '',
      fontSize: (map['font_size'] as num? ?? 14.0).toDouble(),
      color: map['color'] as String? ?? '#2563EB',
      createdBy: map['created_by'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'width': width,
        'text': text,
        'font_size': fontSize,
        'color': color,
        'created_by': createdBy,
      };

  TextBox copyWith({
    String? id,
    double? x,
    double? y,
    double? width,
    String? text,
    double? fontSize,
    String? color,
    String? createdBy,
  }) {
    return TextBox(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      createdBy: createdBy ?? this.createdBy,
    );
  }
}

class WhiteboardCanvasState {
  const WhiteboardCanvasState({
    required this.projectId,
    required this.lastSavedAt,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.zoomLevel,
    required this.strokes,
    required this.stickyNotes,
    required this.filePins,
    required this.voicePins,
    required this.textBoxes,
  });

  final String projectId;
  final DateTime lastSavedAt;
  final double canvasWidth;
  final double canvasHeight;
  final double zoomLevel;
  final List<WhiteboardStroke> strokes;
  final List<StickyNote> stickyNotes;
  final List<FilePin> filePins;
  final List<VoicePin> voicePins;
  final List<TextBox> textBoxes;

  factory WhiteboardCanvasState.fromMap(Map<String, dynamic> map) {
    return WhiteboardCanvasState(
      projectId: map['project_id'] as String? ?? '',
      lastSavedAt: DateTime.parse(map['last_saved_at'] as String? ?? DateTime.now().toIso8601String()),
      canvasWidth: (map['canvas_width'] as num? ?? 4000.0).toDouble(),
      canvasHeight: (map['canvas_height'] as num? ?? 4000.0).toDouble(),
      zoomLevel: (map['zoom_level'] as num? ?? 1.0).toDouble(),
      strokes: (map['strokes'] as List?)?.map((x) => WhiteboardStroke.fromMap(Map<String, dynamic>.from(x))).toList() ?? const [],
      stickyNotes: (map['sticky_notes'] as List?)?.map((x) => StickyNote.fromMap(Map<String, dynamic>.from(x))).toList() ?? const [],
      filePins: (map['file_pins'] as List?)?.map((x) => FilePin.fromMap(Map<String, dynamic>.from(x))).toList() ?? const [],
      voicePins: (map['voice_pins'] as List?)?.map((x) => VoicePin.fromMap(Map<String, dynamic>.from(x))).toList() ?? const [],
      textBoxes: (map['text_boxes'] as List?)?.map((x) => TextBox.fromMap(Map<String, dynamic>.from(x))).toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'project_id': projectId,
        'last_saved_at': lastSavedAt.toIso8601String(),
        'canvas_width': canvasWidth,
        'canvas_height': canvasHeight,
        'zoom_level': zoomLevel,
        'strokes': strokes.map((s) => s.toMap()).toList(),
        'sticky_notes': stickyNotes.map((n) => n.toMap()).toList(),
        'file_pins': filePins.map((f) => f.toMap()).toList(),
        'voice_pins': voicePins.map((v) => v.toMap()).toList(),
        'text_boxes': textBoxes.map((t) => t.toMap()).toList(),
      };
}
