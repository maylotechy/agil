import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/storage_service.dart';
import 'main_shell.dart';
import '../main.dart';

class AgreementScreen extends StatefulWidget {
  const AgreementScreen({super.key});
  @override
  State<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends State<AgreementScreen> {
  bool _agreed = false;
  bool _loading = false;

  Future<void> _accept() async {
    if (!_agreed) return;
    setState(() => _loading = true);

    // Request permissions sequentially
    await Permission.sms.request();
    await Permission.notification.request();
    await Permission.phone.request();

    await StorageService.setUserAgreed();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainShell(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 20),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/images/app_iconv2.png', width: 84, height: 84),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Agil',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'AI-powered protection against scams & phishing',
                  style: TextStyle(color: kTextSub, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),

            // ── Agreement Card ────────────────────────────────────────
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                    child: Row(children: const [
                      Icon(Icons.description_outlined, color: kPrimary, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'User Agreement & Privacy Notice',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ]),
                  ),
                  Divider(color: Colors.white.withOpacity(0.06), height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _section('1. Purpose of This Application',
                              'Agil is a cybersecurity tool that uses machine learning and Gemini AI to detect phishing URLs and scam messages. It monitors incoming SMS messages to identify potential threats and alerts you in real time.'),
                          _section('2. SMS Access',
                              'This app requires access to incoming SMS messages solely to scan for phishing URLs. Message content is sent to our AI analysis server only for threat detection and is never stored externally beyond what is needed for analysis.'),
                          _section('3. Network Access',
                              'The app connects to a backend server to perform AI-powered URL analysis. An active internet connection is required for full functionality. Your personal data is never shared with third parties.'),
                          _section('4. Notifications',
                              'Notification permission is required to alert you immediately when a phishing threat is detected. You may disable notifications in your device settings at any time.'),
                          _section('5. Local Data Storage',
                              'Scan history and statistics are stored locally on your device and are never uploaded to any server. This data remains entirely private to you.'),
                          _section('6. Limitation of Liability',
                              'While Agil uses advanced AI, no system is 100% accurate. The app is provided "as is" without warranty. Exercise your own judgment when evaluating suspicious messages.'),
                          _section('7. Applicable Law',
                              'This application complies with the Republic of the Philippines\' Data Privacy Act of 2012 (R.A. 10173) and the Cybercrime Prevention Act of 2012 (R.A. 10175).'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: kPrimary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kPrimary.withOpacity(0.2)),
                            ),
                            child: const Text(
                              'By continuing, you acknowledge that you have read, understood, and agree to this User Agreement and Privacy Notice.',
                              style: TextStyle(color: kSecondary, fontSize: 12, height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),

            // ── Checkbox + Button ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(children: [
                GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Row(children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _agreed ? kPrimary : Colors.transparent,
                        border: Border.all(
                          color: _agreed ? kPrimary : kMuted, width: 2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: _agreed
                          ? const Icon(Icons.check, color: Colors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'I have read and agree to the User Agreement and Privacy Notice',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (_agreed && !_loading) ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _agreed ? kPrimary : kSurface,
                      disabledBackgroundColor: kSurface,
                      disabledForegroundColor: kMuted,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Accept & Continue',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(color: kTextSub, fontSize: 12, height: 1.6)),
        ]),
      );
}
