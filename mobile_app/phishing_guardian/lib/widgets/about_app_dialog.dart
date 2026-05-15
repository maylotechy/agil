import 'package:flutter/material.dart';
import '../main.dart';

class AboutAppDialog extends StatelessWidget {
  const AboutAppDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('About This App', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: kMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // App name + version
              Row(children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: kPrimary.withValues(alpha: 0.12),
                      border: Border.all(color: kPrimary.withValues(alpha: 0.3))),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Image.asset('assets/images/app_iconv2.png'),
                    ),
                  )),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Agil', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Version 1.0.0', style: TextStyle(color: kTextSub, fontSize: 12)),
                ]),
              ]),
              const Divider(color: Colors.white12, height: 24),
              _aboutRow(Icons.school_rounded, 'Subject', 'Intelligent Systems'),
              const SizedBox(height: 10),
              _aboutRow(Icons.assignment_rounded, 'Type', 'Final Project'),
              const SizedBox(height: 10),
              _aboutRow(Icons.flag_rounded, 'Purpose',
                  'An AI-powered mobile application that detects phishing URLs and scam messages in real time using machine learning and Gemini AI.'),
              const Divider(color: Colors.white12, height: 24),
              const Text('Developers', style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _devCard('Tommie Tabol', 'Lead Developer'),
              const SizedBox(height: 8),
              _devCard('Carl Johnson Flores', 'ML Engineer'),
              const SizedBox(height: 8),
              _devCard('Ali Amir Omar', 'Project Planner'),
              const Divider(color: Colors.white12, height: 24),
              const Text('Support', style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _aboutRow(Icons.bug_report_rounded, 'Encountered a Problem?', 'phishing.guard@developer.com'),
              const Divider(color: Colors.white12, height: 24),
              const Text('Technologies Used', style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _techChip('Flutter'),
                _techChip('Flask (Python)'),
                _techChip('Gemini AI'),
                _techChip('Machine Learning'),
                _techChip('Google News RSS'),
                _techChip('Gmail API'),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: kPrimary, size: 16),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: kMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
      ])),
    ],
  );

  Widget _devCard(String name, String role) => Row(children: [
    CircleAvatar(radius: 18, backgroundColor: kPrimary.withValues(alpha: 0.15),
      child: Text(name[0], style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold))),
    const SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      Text(role, style: const TextStyle(color: kTextSub, fontSize: 11)),
    ]),
  ]);

  Widget _techChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: kPrimary.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
    ),
    child: Text(label, style: const TextStyle(color: kSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}
