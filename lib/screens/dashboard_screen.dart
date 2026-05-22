import 'package:flutter/material.dart';
import '../services/hive_service.dart';
import '../models/detection_result.dart';
import 'package:get_it/get_it.dart';

class DashboardScreen extends StatefulWidget {
  /// Called when user taps "START AI DETECTION" or the scanner shortcut.
  final VoidCallback onGoToScanner;

  /// Called when user taps "HISTORY" label.
  final VoidCallback onGoToHistory;

  const DashboardScreen({
    super.key,
    required this.onGoToScanner,
    required this.onGoToHistory,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _hive = GetIt.I<HiveService>();

  @override
  Widget build(BuildContext context) {
    final score = _hive.getRoomSafetyScore();
    final scoreInt = score.round();
    final riskLabel = _hive.getRiskLabel(score);
    final recent = _hive.getRecentResults(limit: 3);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSafetyCard(scoreInt, riskLabel),
              const SizedBox(height: 20),
              _buildQuickScan(),
              const SizedBox(height: 24),
              _buildRecentFindings(recent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hello, Naira!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Kamar Kos · AS-POLBAN',
              style: TextStyle(color: const Color(0xFF8B949E), fontSize: 13),
            ),
          ],
        ),
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            color: Color(0xFF00C896),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('N',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyCard(int score, String riskLabel) {
    final color = score >= 80
        ? const Color(0xFF00C896)
        : score >= 60
            ? const Color(0xFFFFAA00)
            : const Color(0xFFFF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Room Safety Score',
              style: TextStyle(color: color.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            '$score%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: -2,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(riskLabel, style: TextStyle(color: color, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick scan button — now calls onGoToScanner ───────────────────────────

  Widget _buildQuickScan() {
    return GestureDetector(
      onTap: widget.onGoToScanner, // ← WIRED
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF21262D)),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF00C896), width: 2),
                color: const Color(0xFF00C896).withOpacity(0.1),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Color(0xFF00C896), size: 28),
            ),
            const SizedBox(height: 10),
            const Text(
              'START AI DETECTION',
              style: TextStyle(
                color: Color(0xFF00C896),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent findings — "HISTORY" label now calls onGoToHistory ─────────────

  Widget _buildRecentFindings(List<DetectionResult> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Findings',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            // ── HISTORY tap target ────────────────────────────────────────
            GestureDetector(
              onTap: widget.onGoToHistory, // ← WIRED
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                child: Text('HISTORY',
                    style: TextStyle(
                        color: Color(0xFF00C896), fontSize: 12)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No scans yet.\nTap the scanner to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(color: const Color(0xFF4A5568), fontSize: 14),
              ),
            ),
          )
        else
          ...results.map((r) => _buildResultTile(r)),
      ],
    );
  }

  Widget _buildResultTile(DetectionResult r) {
    final color = r.riskLevel == 'danger'
        ? const Color(0xFFFF4444)
        : r.riskLevel == 'high'
            ? const Color(0xFFFF8C00)
            : const Color(0xFFFFDD00);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.label[0].toUpperCase() + r.label.substring(1),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(r.location,
                    style: const TextStyle(
                        color: Color(0xFF8B949E), fontSize: 12)),
              ],
            ),
          ),
          Text(
            '${r.confidencePercent}%',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}