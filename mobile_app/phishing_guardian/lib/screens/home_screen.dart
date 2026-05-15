import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../services/storage_service.dart';
import '../widgets/eagle_loader.dart';
import 'sandbox_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/about_app_dialog.dart';
import 'history_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:lottie/lottie.dart';

class HomeScreen extends StatefulWidget {
  static final GlobalKey<_HomeScreenState> scanKey = GlobalKey<_HomeScreenState>();
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  bool _scanning = false;
  bool _serverError = false;
  String _resultLabel = '';
  String _explanation = 'Paste a suspicious message or URL below to analyze it with AI.';
  bool? _isPhishing;
  Map<String, int> _stats = {'total': 0, 'threats': 0, 'safe': 0};
  List<double> _weeklyData = List.filled(7, 0.0);
  List<String> _weeklyLabels = StorageService.getLast7DaysLabels();
  bool _phishtankMatch = false;
  bool _mlMatch = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadNickname();
  }

  Future<void> _loadStats() async {
    final s = await StorageService.getStats();
    final wData = await StorageService.getWeeklyActivity();
    if (mounted) {
      setState(() {
        _stats = s;
        _weeklyData = wData;
      });
    }
  }

  void scanFromCamera() => _pickImageAndExtractText(ImageSource.camera);

  Future<void> _pickImageAndExtractText(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    setState(() => _scanning = true);

    try {
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      setState(() {
        _ctrl.text = recognizedText.text;
      });
      
      if (recognizedText.text.trim().isNotEmpty) {
        await _scan(); // Automatically scan after extraction
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to extract text: $e')),
        );
      }
    } finally {
      if (mounted && !_scanning) {
          setState(() => _scanning = false);
      }
    }
  }

  Future<void> _scan() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _scanning = true; _isPhishing = null; _serverError = false; });

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/scan'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": text}),
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final label = data['status'] as String? ?? '';
        final isThreat = label != 'SECURE';
        final ptMatch = data['phishtank_match'] == true;
        await StorageService.saveScan(
          text: text,
          isPhishing: isThreat,
          explanation: data['explanation'] ?? '',
          source: 'Manual',
          provider: data['provider'] ?? 'Unknown',
          phishtankMatch: ptMatch,
          mlMatch: data['ml_match'] == true,
        );
        setState(() {
          _isPhishing = isThreat;
          _resultLabel = ptMatch ? 'BLACKLISTED PHISHING' : (data['ml_match'] == true ? 'PHISHING DETECTED' : 'SUSPICIOUS THREAT');
          _explanation = data['explanation'] ?? 'No explanation available.';
          _phishtankMatch = ptMatch;
          _mlMatch = data['ml_match'] == true;
          _serverError = false;
        });
        await _loadStats();
      }
    } catch (e) {
      setState(() {
        _serverError = true;
        _explanation = 'Server cannot be reached. Please check your connection or try again later.';
      });
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _sendFeedback(String type) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isPhishing == null) return;
    try {
      await http.post(
        Uri.parse('$kBaseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input_text': text.substring(0, text.length.clamp(0, 500)),
          'ai_verdict_phishing': _isPhishing,
          'feedback_type': type, // 'like', 'dislike', 'block'
          'source': 'manual_scan',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(type == 'like' ? 'Thank you! AI will learn from this.' : 'Feedback received. We will re-analyze.'),
            backgroundColor: kSuccess,
          )
        );
      }
    } catch (e) {
      // Error handled silently
    }
  }

  Future<void> _report(String link) async {
    final subject = Uri.encodeComponent('Phishing Incident Report - Agil');
    final body = Uri.encodeComponent(
      'Dear Authorities,\n\n'
      'I am reporting a suspicious link detected by the Agil AI application.\n\n'
      'Detected Link: $link\n'
      'Analysis Verdict: PHISHING\n\n'
      'Please investigate this incident to protect other users.\n\n'
      'Best regards,\nA concerned citizen'
    );
    final url = Uri.parse('mailto:report@cybercrime.gov.ph?subject=$subject&body=$body');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app'))
        );
      }
    }
  }

  Future<void> _reportToPhishTank(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    final phishTankUrl = Uri.parse('https://phishtank.org/phish_submit.php');
    if (await canLaunchUrl(phishTankUrl)) {
      await launchUrl(phishTankUrl, mode: LaunchMode.externalApplication);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copied! Paste it on PhishTank to protect others worldwide.'),
          backgroundColor: kSuccess,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset('assets/images/app_iconv2.png', width: 28, height: 28),
          ),
          const SizedBox(width: 8),
          const Text('Agil'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadStats,
            tooltip: 'Refresh stats',
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _profileHeader(),
          const SizedBox(height: 24),
          const _DynamicGreeting(),
          const SizedBox(height: 24),

          // ── Stat Cards ───────────────────────────────────────────────
          Row(children: [
            _statCard('Total Scans', _stats['total']!.toString(), Icons.bar_chart_rounded, kPrimary),
            const SizedBox(width: 12),
            _statCard('Threats Found', _stats['threats']!.toString(), Icons.gpp_bad_rounded, const Color(0xFFFF6B35)),
            const SizedBox(width: 12),
            _statCard('Safe URLs', (_stats['total']! - _stats['threats']!).toString(), Icons.verified_user_rounded, kSuccess),
          ]),
          const SizedBox(height: 24),

          // ── Weekly Activity Chart ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Weekly Activity', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(height: 80, child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  return _bar(_weeklyLabels[index], _weeklyData[index]);
                }),
              )),
            ]),
          ),
          const SizedBox(height: 32),

          // ── Analysis Input ──────────────────────────────────────────
          const Text('Analyze Suspicious Content', 
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // ── Scan Card ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI Scan', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Paste text or upload photo', style: TextStyle(color: kTextSub, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : () => _pickImageAndExtractText(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Take Photo', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: BorderSide(color: kPrimary.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _scanning ? null : () => _pickImageAndExtractText(ImageSource.gallery),
                      icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                      label: const Text('Upload', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: BorderSide(color: kPrimary.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _ctrl,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'e.g. "Your account has been suspended. Click here: bit.ly/xXx"',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _scanning ? null : _scan,
                  icon: _scanning
                      ? const EagleLoader(size: 20)
                      : const Icon(Icons.psychology_rounded, size: 20),
                  label: Text(_scanning ? 'Analyzing...' : 'Run AI Analysis'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Result Card ──────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _isPhishing == null
                  ? kCard
                  : _resultLabel == 'SECURE'
                      ? kSuccess.withOpacity(0.10)
                      : (_resultLabel == 'PHISHING DETECTED' || _resultLabel == 'BLACKLISTED PHISHING')
                          ? kPrimary.withOpacity(0.12)
                          : const Color(0xFFFF9800).withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _isPhishing == null
                    ? Colors.white.withOpacity(0.06)
                    : _resultLabel == 'SECURE'
                        ? kSuccess.withOpacity(0.4)
                        : (_resultLabel == 'PHISHING DETECTED' || _resultLabel == 'BLACKLISTED PHISHING')
                            ? kPrimary.withOpacity(0.4)
                            : const Color(0xFFFF9800).withOpacity(0.5),
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_serverError) ...[
                Center(child: Lottie.asset('assets/animations/not found.json', width: 120, height: 120, repeat: true)),
                const SizedBox(height: 8),
                const Center(child: Text('SERVER UNREACHABLE', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13))),
                const SizedBox(height: 12),
              ],
              if (_isPhishing != null) ...[
                Row(children: [
                  Icon(
                    _resultLabel == 'SECURE' ? Icons.verified_rounded :
                    (_resultLabel == 'PHISHING DETECTED' || _resultLabel == 'BLACKLISTED PHISHING') ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
                    color: _resultLabel == 'SECURE' ? kSuccess :
                           (_resultLabel == 'PHISHING DETECTED' || _resultLabel == 'BLACKLISTED PHISHING') ? kPrimary : const Color(0xFFFF9800),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resultLabel,
                      style: TextStyle(
                        color: _resultLabel == 'SECURE' ? kSuccess :
                               (_resultLabel == 'PHISHING DETECTED' || _resultLabel == 'BLACKLISTED PHISHING') ? kPrimary : const Color(0xFFFF9800),
                        fontSize: 14, fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(children: [
                    IconButton(icon: const Icon(Icons.thumb_up_alt_outlined, size: 18, color: kMuted), 
                        onPressed: () => _sendFeedback('like')),
                    IconButton(icon: const Icon(Icons.thumb_down_alt_outlined, size: 18, color: kMuted),
                        onPressed: () => _sendFeedback('dislike')),
                  ]),
                ]),
                if (_phishtankMatch) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kPrimary.withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      Icon(Icons.shield_rounded, color: kPrimary, size: 14),
                      SizedBox(width: 6),
                      Text('PhishTank Blacklisted',
                        style: TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                const Text('Scan Breakdown', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildLayer('PhishTank Global DB', _phishtankMatch ? 'MATCHED' : 'SAFE', _phishtankMatch ? kPrimary : kSuccess),
                _buildLayer('AI Classifier Model', _mlMatch ? 'PHISHING' : 'SECURE', _mlMatch ? kPrimary : kSuccess),
                _buildLayer('Human-like Reasoning (AI)', (_isPhishing ?? false) ? 'PHISHING' : 'SECURE', (_isPhishing ?? false) ? kPrimary : kSuccess),
                const Divider(color: Colors.white12, height: 20),
              ],
              const Text('AI Reasoning',
                  style: TextStyle(color: kTextSub, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_explanation,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5)),
              if (_isPhishing != null && RegExp(r'https?://').hasMatch(_ctrl.text)) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final exp = RegExp(r'https?://[^\s]+');
                      final url = exp.firstMatch(_ctrl.text)?[0] ?? _ctrl.text.trim();
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => SandboxPreviewScreen(url: url)));
                    },
                    icon: const Icon(Icons.security_rounded, size: 16),
                    label: const Text('Open in Sandbox Preview', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kSuccess,
                      side: const BorderSide(color: kSuccess),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                if (_isPhishing == true) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final exp = RegExp(r'https?://[^\s]+');
                        final url = exp.firstMatch(_ctrl.text)?[0] ?? _ctrl.text.trim();
                        _report(url);
                      },
                      icon: const Icon(Icons.report_gmailerrorred_rounded, size: 16),
                      label: const Text('Report to Authorities', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final exp = RegExp(r'https?://[^\s]+');
                        final url = exp.firstMatch(_ctrl.text)?[0] ?? _ctrl.text.trim();
                        _reportToPhishTank(url);
                      },
                      icon: const Icon(Icons.public_rounded, size: 16),
                      label: const Text('Report to Global Community', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF42A5F5),
                        side: const BorderSide(color: Color(0xFF42A5F5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ]),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 40),
        ]),
      ),
          if (_scanning)
            Container(
              color: kBg.withOpacity(0.85),
              child: const Center(
                child: EagleLoader(size: 80, message: 'Analyzing Threat...'),
              ),
            ),
        ],
      ),
    );
  }



  String _nickname = '';
  
  Future<void> _loadNickname() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _nickname = prefs.getString('nickname') ?? '');
  }

  Future<void> _setNickname() async {
    final ctrl = TextEditingController(text: _nickname);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Enter Nickname', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Your nickname'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final n = ctrl.text.trim();
              if (n.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('nickname', n);
                if (mounted) setState(() => _nickname = n);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hr = DateTime.now().hour;
    if (hr < 12) return 'Good Morning';
    if (hr < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _profileHeader() {
    final greeting = _getGreeting();
    final avatarUrl = 'https://api.dicebear.com/7.x/avataaars/svg?seed=${_nickname.isEmpty ? "Guardian" : _nickname}';
    
    return InkWell(
      onTap: _setNickname,
      borderRadius: BorderRadius.circular(12),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: kPrimary.withValues(alpha: 0.2)),
          ),
          child: ClipOval(
            child: SvgPicture.network(avatarUrl, placeholderBuilder: (_) => const Icon(Icons.person_rounded, color: kPrimary)),
          ),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(greeting, style: const TextStyle(color: kTextSub, fontSize: 13)),
          Text(_nickname.isEmpty ? 'Tap to set nickname' : _nickname, 
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              Lottie.network(
                'https://lottie.host/88028782-b13c-48d6-953e-55c3c0a373b9/vA2E2TzK9R.json',
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.person_rounded, color: kMuted),
              ),
              const SizedBox(width: 6),
              const Text('Active Protection Enabled', style: TextStyle(color: kSuccess, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ]),
      ]),
    );
  }

  Widget _bar(String day, double heightFactor) {
    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      Container(
        width: 12,
        height: 60 * heightFactor,
        decoration: BoxDecoration(
          color: heightFactor > 0.6 ? kPrimary : kPrimary.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 8),
      Text(day, style: const TextStyle(color: kMuted, fontSize: 10)),
    ]);
  }



  Widget _buildLayer(String title, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: kTextSub, fontSize: 11)),
          Row(
            children: [
              Icon(status == 'SAFE' || status == 'SECURE' ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 12),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text('$value',
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: kTextSub, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _DynamicGreeting extends StatefulWidget {
  const _DynamicGreeting();
  @override
  State<_DynamicGreeting> createState() => _DynamicGreetingState();
}

class _DynamicGreetingState extends State<_DynamicGreeting> {
  int _idx = 0;
  static const _tips = [
    "Stay alert! Phishing links are everywhere.",
    "Scan every link before you click. Safety first!",
    "Suspect a message? Let me analyze it for you!",
    "Agil AI is here to protect your digital life.",
    "Never share your OTP or password with anyone!",
    "Check the sender's address carefully before replying.",
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), _rotate);
  }

  void _rotate() {
    if (mounted) {
      setState(() => _idx = (_idx + 1) % _tips.length);
      Future.delayed(const Duration(seconds: 5), _rotate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Lottie.asset('assets/animations/sign in red.json', fit: BoxFit.contain),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _tips[_idx],
                key: ValueKey(_idx),
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
