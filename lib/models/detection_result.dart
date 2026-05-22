import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class DetectionResult extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final double confidence;

  @HiveField(3)
  final String label; // 'mold', 'crack', 'peeling', etc.

  @HiveField(4)
  final String? imagePath;

  @HiveField(5)
  final String location; // e.g. "Kamar Kos", user-input

  @HiveField(6)
  final String riskLevel; // 'low', 'medium', 'high', 'danger'

  DetectionResult({
    required this.id,
    required this.timestamp,
    required this.confidence,
    required this.label,
    this.imagePath,
    required this.location,
    required this.riskLevel,
  });

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  int get confidencePercent => (confidence * 100).round();
}

// ── Manual adapter (avoids build_runner requirement) ──────────────────────────
class DetectionResultAdapter extends TypeAdapter<DetectionResult> {
  @override
  final int typeId = 0;

  @override
  DetectionResult read(BinaryReader reader) {
    return DetectionResult(
      id: reader.readString(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      confidence: reader.readDouble(),
      label: reader.readString(),
      imagePath: reader.read() as String?,
      location: reader.readString(),
      riskLevel: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, DetectionResult obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
    writer.writeDouble(obj.confidence);
    writer.writeString(obj.label);
    writer.write(obj.imagePath);
    writer.writeString(obj.location);
    writer.writeString(obj.riskLevel);
  }
}