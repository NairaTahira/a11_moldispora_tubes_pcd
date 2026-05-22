import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../services/hive_service.dart';
import '../models/detection_result.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _hive = GetIt.I<HiveService>();
  String _filter = 'All Items';

  final _filters = ['All Items', 'Danger Only', 'Warnings', 'Cleared'];

  List<DetectionResult> get _filtered {
    final all = _hive.getAllResults();
    switch (_filter) {
      case 'Danger Only':
        return all.where((r) => r.riskLevel == 'danger').toList();
      case 'Warnings':
        return all.where((r) => r.riskLevel == 'high' || r.riskLevel == 'medium').toList();
      case 'Cleared':
        return all.where((r) => r.riskLevel == 'low').toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            Expanded(
              child: results.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: results.length,
                      itemBuilder: (_, i) => _buildTile(results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Scan History',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8B949E)),
            onPressed: () async {
              await _hive.clearAll();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        children: _filters.map((f) {
          final isActive = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF00C896) : const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? const Color(0xFF00C896) : const Color(0xFF21262D),
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF8B949E),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 56, color: const Color(0xFF21262D)),
          const SizedBox(height: 12),
          Text('No scans in this category', style: TextStyle(color: const Color(0xFF4A5568))),
        ],
      ),
    );
  }

  Widget _buildTile(DetectionResult r) {
    final color = r.riskLevel == 'danger'
        ? const Color(0xFFFF4444)
        : r.riskLevel == 'high'
            ? const Color(0xFFFF8C00)
            : r.riskLevel == 'medium'
                ? const Color(0xFFFFDD00)
                : const Color(0xFF00C896);

    return Dismissible(
      key: Key(r.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Colors.red.withOpacity(0.2),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) async {
        await _hive.deleteResult(r.id);
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF21262D)),
        ),
        child: Row(
          children: [
            // Thumbnail placeholder
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.biotech_rounded, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label[0].toUpperCase() + r.label.substring(1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${r.location} · ${r.formattedDate}',
                    style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  // Confidence bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: r.confidence,
                      backgroundColor: Colors.white.withOpacity(0.05),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${r.confidencePercent}%',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}