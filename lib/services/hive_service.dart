import 'package:hive_flutter/hive_flutter.dart';
import '../models/detection_result.dart';

class HiveService {
  static const _boxName = 'scan_history';

  Box<DetectionResult> get _box => Hive.box<DetectionResult>(_boxName);

  /// Save a new detection result
  Future<void> saveResult(DetectionResult result) async {
    await _box.put(result.id, result);
  }

  /// Get all results sorted newest first
  List<DetectionResult> getAllResults() {
    final results = _box.values.toList();
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return results;
  }

  /// Get only the most recent N results
  List<DetectionResult> getRecentResults({int limit = 5}) {
    return getAllResults().take(limit).toList();
  }

  /// Delete a result by id
  Future<void> deleteResult(String id) async {
    await _box.delete(id);
  }

  /// Clear all history
  Future<void> clearAll() async {
    await _box.clear();
  }

  /// Average safety score (100 - avg confidence of mold detections)
  double getRoomSafetyScore() {
    final results = getAllResults();
    if (results.isEmpty) return 100.0;
    final moldResults = results.where((r) => r.label == 'mold').toList();
    if (moldResults.isEmpty) return 95.0;
    final avgConf = moldResults.map((r) => r.confidence).reduce((a, b) => a + b) / moldResults.length;
    return ((1.0 - avgConf) * 100).clamp(0.0, 100.0);
  }

  /// Get risk label from score
  String getRiskLabel(double score) {
    if (score >= 80) return 'Safe from major spores';
    if (score >= 60) return 'Moderately Safe';
    if (score >= 40) return 'Moderate Risk';
    return 'High Risk – Act Now';
  }
}