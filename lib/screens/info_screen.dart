import 'package:flutter/material.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static const _moldTypes = [
    {
      'name': 'Black Mold (Stachybotrys)',
      'risk': 'danger',
      'riskLabel': 'High Risk',
      'description': 'Toxic mold that produces mycotoxins. Found in extremely damp areas.',
      'color': 0xFFFF4444,
    },
    {
      'name': 'Aspergillus (Green)',
      'risk': 'medium',
      'riskLabel': 'Medium Risk',
      'description': 'Common indoor mold. Can cause allergic reactions and respiratory issues.',
      'color': 0xFF00C896,
    },
    {
      'name': 'Cladosporium (Brown)',
      'risk': 'low',
      'riskLabel': 'Low Risk',
      'description': 'Often found on fabrics and walls. Can survive in cool, dry areas.',
      'color': 0xFF8B6914,
    },
  ];

  static const _tips = [
    'Keep humidity below 50%',
    'Ensure good ventilation in bathrooms',
    'Fix water leaks promptly',
    'Clean bathroom tiles weekly',
    'Use mold-resistant paint in damp areas',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Mold Knowledge',
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ..._moldTypes.map((m) => _buildMoldCard(m)),
              const SizedBox(height: 24),
              _buildPreventionTips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoldCard(Map<String, dynamic> mold) {
    final color = Color(mold['color'] as int);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  mold['name'] as String,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mold['riskLabel'] as String,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mold['description'] as String,
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPreventionTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF21262D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Prevention Tips',
            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF00C896), fontSize: 14)),
                  Expanded(
                    child: Text(tip, style: const TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}