import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../widgets/youtube_awareness_widget.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _videoIndex = 0;
  
  final List<Map<String, String>> _awarenessVideos = [
    {'id': 'Y7zNlEMDmI4', 'title': 'Social Engineering Explained', 'creator': 'Cyber Security'},
    {'id': 'iHetr8xTWIU', 'title': 'How Phishing Works', 'creator': 'Global Awareness'},
    {'id': 'NJxJYBAjkJU', 'title': 'Spotting Suspicious Links', 'creator': 'Tech Safety'},
    {'id': 'fZc2oXfz9Qs', 'title': 'Protecting Your Identity', 'creator': 'Identity Guard'},
    {'id': 'Vo1urF6S4u0', 'title': 'Cybersecurity Best Practices', 'creator': 'Security First'},
  ];

  @override
  void initState() {
    super.initState();
    _loadVideoIndex();
  }

  Future<void> _loadVideoIndex() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final savedIndex = prefs.getInt('current_video_index') ?? 0;
        _videoIndex = savedIndex.clamp(0, _awarenessVideos.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.library_books_rounded, color: kPrimary, size: 20),
            SizedBox(width: 8),
            Text('Safety Library'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Video Awareness', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          YouTubeAwarenessWidget(
            key: ValueKey(_awarenessVideos[_videoIndex]['id']),
            videoId: _awarenessVideos[_videoIndex]['id']!,
            title: _awarenessVideos[_videoIndex]['title']!,
            creator: _awarenessVideos[_videoIndex]['creator']!,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${_videoIndex + 1} of ${_awarenessVideos.length}', style: const TextStyle(color: kMuted, fontSize: 11)),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _videoIndex = (_videoIndex + 1) % _awarenessVideos.length;
                  });
                },
                icon: const Icon(Icons.skip_next_rounded, size: 16),
                label: const Text('Next Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  side: BorderSide(color: kPrimary.withOpacity(0.3)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Phishing Encyclopedia', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildScamCard('Smishing (SMS)', 'Text messages that use urgent language to trick you into clicking malicious links.', Icons.sms_failed_rounded),
          _buildScamCard('Spear Phishing', 'Highly personalized attacks targeting a specific person or organization.', Icons.person_search_rounded),
          _buildScamCard('Vishing (Voice)', 'Phone calls using social engineering to steal personal or financial information.', Icons.phone_callback_rounded),
          _buildScamCard('Pharming', 'Redirecting website traffic to a fake site even if you typed the correct URL.', Icons.web_asset_off_rounded),
          const SizedBox(height: 24),
          _buildSafetyTips(),
        ],
      ),
    );
  }

  Widget _buildScamCard(String title, String desc, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: kPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: kTextSub, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [kPrimary.withOpacity(0.1), Colors.transparent], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Text('Quick Safety Tips', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _tip('Enable 2-Factor Authentication (2FA) on all accounts.'),
          _tip('Never share your OTP or password via phone or text.'),
          _tip('Hover over links to see the real URL before clicking.'),
          _tip('Be wary of messages creating "False Urgency" or "Fear".'),
        ],
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, color: kSuccess, size: 14),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: kTextSub, fontSize: 12))),
        ],
      ),
    );
  }
}
