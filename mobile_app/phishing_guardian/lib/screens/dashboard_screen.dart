import 'package:flutter/material.dart';
import '../main.dart';
import '../services/storage_service.dart';
import '../widgets/eagle_loader.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _totalScans = 0;
  int _threatsBlocked = 0;
  double _safetyScore = 0.85;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final records = await StorageService.getRecords();
    int threats = records.where((r) => r.isPhishing).length;
    
    if (mounted) {
      setState(() {
        _totalScans = records.length;
        _threatsBlocked = threats;
        // Simple safety score logic: 1.0 - (threats / total) if total > 0
        if (_totalScans > 0) {
          _safetyScore = (1.0 - (threats / _totalScans)).clamp(0.1, 1.0);
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: const [
          Icon(Icons.dashboard_rounded, color: kPrimary, size: 20),
          SizedBox(width: 8),
          Text('Security Dashboard'),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStats,
        color: kPrimary,
        backgroundColor: kSurface,
        child: _loading 
          ? const Center(child: EagleLoader(size: 60, message: 'Calculating security status...'))
          : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildScoreCard(),
              const SizedBox(height: 20),
              _buildStatsRow(),
              const SizedBox(height: 24),
              const Text('Active Protection', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildProtectionItem(Icons.sms_rounded, 'SMS Guardian', 'Monitoring incoming messages', true),
              _buildProtectionItem(Icons.mail_rounded, 'Gmail Shield', 'Scanning inbox for malicious links', true),
              _buildProtectionItem(Icons.public_rounded, 'Real-time DB', 'Connected to PhishTank Global', true),
              const SizedBox(height: 24),
              _buildQuickActions(),
            ],
          ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final color = _safetyScore > 0.8 ? kSuccess : (_safetyScore > 0.5 ? Colors.orange : kPrimary);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kSurface, kSurface.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Safety Score', style: TextStyle(color: kTextSub, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${(_safetyScore * 100).toInt()}%', 
                    style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
              Icon(Icons.shield_rounded, color: color, size: 48),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: _safetyScore,
              backgroundColor: Colors.white.withOpacity(0.05),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _safetyScore > 0.8 ? 'Your device is highly protected' : 'Critical threats detected recently',
            style: const TextStyle(color: kTextSub, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _statCard('Total Scans', _totalScans.toString(), Icons.search_rounded, kPrimary)),
        const SizedBox(width: 12),
        Expanded(child: _statCard('Threats Blocked', _threatsBlocked.toString(), Icons.block_rounded, kSuccess)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: kTextSub, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildProtectionItem(IconData icon, String title, String subtitle, bool active) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Icon(icon, color: kPrimary, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(color: kTextSub, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: kSuccess.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('ACTIVE', style: TextStyle(color: kSuccess, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {}, // Handled by MainShell
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: const Text('Manual Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
