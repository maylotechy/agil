import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../widgets/about_app_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/eagle_loader.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _isSimulating = false;

  final List<Map<String, dynamic>> _portals = [
    {'name': 'GCash', 'url': 'https://www.gcash.com', 'icon': Icons.account_balance_wallet_rounded, 'color': Color(0xFF007DFE)},
    {'name': 'Maya', 'url': 'https://www.maya.ph', 'icon': Icons.wallet_rounded, 'color': Color(0xFF00C32C)},
    {'name': 'BDO Online', 'url': 'https://www.bdo.com.ph', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF004C97)},
    {'name': 'BPI', 'url': 'https://www.bpi.com.ph', 'icon': Icons.account_balance_rounded, 'color': Color(0xFFD0021B)},
    {'name': 'Metrobank', 'url': 'https://www.metrobank.com.ph', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF003893)},
    {'name': 'Landbank', 'url': 'https://www.landbank.com', 'icon': Icons.account_balance_rounded, 'color': Color(0xFF006400)},
    {'name': 'SSS Portal', 'url': 'https://www.sss.gov.ph', 'icon': Icons.security_rounded, 'color': Color(0xFF0D47A1)},
    {'name': 'Pag-IBIG', 'url': 'https://www.pagibigfund.gov.ph', 'icon': Icons.home_work_rounded, 'color': Color(0xFF1565C0)},
  ];

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.vpn_key_rounded, color: kPrimary, size: 20),
          SizedBox(width: 8),
          Text('Safe Vault'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: kPrimary),
            onPressed: () => showDialog(context: context, builder: (_) => const AboutAppDialog()),
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.verified_user_rounded, color: kPrimary, size: 32),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                Text('Verified Portals', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Always use these official links to avoid phishing ads on search engines.',
                    style: TextStyle(color: kTextSub, fontSize: 12, height: 1.4)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
            ),
            itemCount: _portals.length,
            itemBuilder: (_, i) {
              final p = _portals[i];
              return InkWell(
                onTap: () => _open(p['url']),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (p['color'] as Color).withOpacity(0.3)),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(p['icon'], color: p['color'], size: 28),
                    const SizedBox(height: 8),
                    Text(p['name'], style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 30),
          _authoritiesSection(),
          const SizedBox(height: 40),
          _testSection(),
        ],
      ),
      if (_isSimulating)
        Container(
          color: kBg.withOpacity(0.85),
          child: const Center(
            child: EagleLoader(size: 80, message: 'Simulating Attack...'),
          ),
        ),
      ],
    ),
  );
}

  Widget _testSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimary.withOpacity(0.05), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.security_update_warning_rounded, color: kPrimary, size: 20),
          SizedBox(width: 10),
          Text('Security Simulator',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        const Text(
          'Test how Agil reacts to a real-time phishing attack. This bypasses carrier blocks for testing.',
          style: TextStyle(color: kTextSub, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _simulateAttack(
              'GCASH: Your account has been temporarily restricted. Verify here: http://bit.ly/secure-gcash-verify',
              'GCash Phishing SMS',
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Simulate GCash Phishing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary.withOpacity(0.15),
              foregroundColor: kPrimary,
              elevation: 0,
              side: const BorderSide(color: kPrimary, width: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => _simulateAttack(
              'URGENT: Your BDO Online Banking has been restricted. Please re-verify your account details now to avoid permanent closure: https://bdo-online-banking-security.com/verify',
              'BDO Phishing SMS',
            ),
            icon: const Icon(Icons.bolt_rounded, size: 18),
            label: const Text('Simulate BDO Phishing'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF004C97).withOpacity(0.15),
              foregroundColor: const Color(0xFF42A5F5),
              elevation: 0,
              side: const BorderSide(color: Color(0xFF42A5F5), width: 1.2),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _simulateAttack(String testMsg, String label) async {
    setState(() => _isSimulating = true);

    await Future.delayed(const Duration(seconds: 2));

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/scan'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": testMsg}),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final isBlacklisted = data['phishtank_match'] == true;
        final status = data['status'] ?? 'Unknown';
        final isThreat = status != 'SECURE';

        final title = isThreat
            ? (isBlacklisted ? 'BLACKLISTED PHISHING (TEST)' : 'PHISHING DETECTED (TEST)')
            : 'URL IS SECURE (TEST)';

        final notifColor = isThreat ? kPrimary : kSuccess;

        AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'scam_alerts',
          'Scam Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: notifColor,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(
            'Source: $label\nVerdict: $status\nProvider: ${data['provider'] ?? 'N/A'}\n\n${data['explanation'] ?? ''}',
          ),
        );

        NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );

        await agilNotifications.show(99, title,
          'Verdict: $status — $label', notificationDetails);
      }
    } catch (e) {
      if (mounted) {
        _snack('Simulation failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _authoritiesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Emergency Reporting', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _authCard('DICT Cybercrime', 'Report online threats', 'https://dict.gov.ph', Icons.computer_rounded),
      _authCard('PNP ACG', 'File a police complaint', 'https://acg.pnp.gov.ph', Icons.local_police_rounded),
    ]);
  }

  Widget _authCard(String name, String sub, String url, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _open(url),
        tileColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon, color: kPrimary),
        title: Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        subtitle: Text(sub, style: const TextStyle(color: kTextSub, fontSize: 12)),
        trailing: const Icon(Icons.open_in_new_rounded, color: kMuted, size: 16),
      ),
    );
  }
}
