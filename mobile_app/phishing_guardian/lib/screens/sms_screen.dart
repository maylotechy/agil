import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:another_telephony/telephony.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../widgets/eagle_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import 'sandbox_preview_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/unified_threat_card.dart';

class _ScanResult {
  final String sender, body, explanation, url;
  final bool isPhishing;
  final String label;
  final DateTime timestamp;
  final bool phishtankMatch;
  final bool mlMatch;

  _ScanResult({
    required this.sender, required this.body,
    required this.explanation, required this.isPhishing,
    required this.url, required this.timestamp,
    this.label = '',
    this.phishtankMatch = false,
    this.mlMatch = false,
  });

  Map<String, dynamic> toJson() => {
    'sender': sender, 'body': body, 'explanation': explanation,
    'isPhishing': isPhishing, 'url': url, 'timestamp': timestamp.toIso8601String(),
    'label': label, 'phishtankMatch': phishtankMatch, 'mlMatch': mlMatch,
  };

  factory _ScanResult.fromJson(Map<String, dynamic> j) => _ScanResult(
    sender: j['sender'] ?? '', body: j['body'] ?? '',
    explanation: j['explanation'] ?? '', isPhishing: j['isPhishing'] ?? false,
    url: j['url'] ?? '', timestamp: DateTime.parse(j['timestamp'] ?? DateTime.now().toIso8601String()),
    label: j['label'] ?? (j['isPhishing'] == true ? 'PHISHING DETECTED' : 'SECURE'),
    phishtankMatch: j['phishtankMatch'] ?? false,
    mlMatch: j['mlMatch'] ?? false,
  );
}

class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});
  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  final Telephony _telephony = Telephony.instance;
  bool _scanning = false;
  List<_ScanResult> _results = [];
  Set<String> _scannedHashes = {}; // We'll use a hash of sender+body as ID for SMS
  String _status = '';
  int _scanned = 0, _total = 0;
  String _filter = 'All'; // All | Phishing | Suspicious | Safe
  int _page = 0;
  static const _perPage = 5;

  List<_ScanResult> get _filteredResults {
    if (_filter == 'All') return _results;
    if (_filter == 'Phishing') return _results.where((r) => r.isPhishing && (r.phishtankMatch || r.mlMatch)).toList();
    if (_filter == 'Suspicious') return _results.where((r) => r.isPhishing && !r.phishtankMatch && !r.mlMatch).toList();
    return _results.where((r) => !r.isPhishing).toList();
  }

  List<_ScanResult> get _pageItems {
    final src = _filteredResults;
    final start = _page * _perPage;
    final end = (start + _perPage).clamp(0, src.length);
    return src.sublist(start, end);
  }

  int get _maxPages => (_filteredResults.length / _perPage).ceil().clamp(1, 999);

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRes = prefs.getString('sms_scans');
    final rawHashes = prefs.getStringList('sms_scanned_hashes');
    if (mounted) setState(() {
      if (rawRes != null) {
        try {
          final list = jsonDecode(rawRes) as List;
          _results = list.map((e) => _ScanResult.fromJson(e)).toList();
        } catch (_) {}
      }
      if (rawHashes != null) _scannedHashes = rawHashes.toSet();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sms_scans', jsonEncode(_results.map((e) => e.toJson()).toList()));
    await prefs.setStringList('sms_scanned_hashes', _scannedHashes.toList());
  }

  Future<void> _delete(_ScanResult r) async {
    setState(() {
      _results.remove(r);
      _scannedHashes.remove(_getHash(r.sender, r.body));
    });
    await _save();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All History?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('This will remove all SMS scan results. This cannot be undone.', style: TextStyle(color: kTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Clear All', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _results.clear();
        _scannedHashes.clear();
        _page = 0;
      });
      await _save();
      _snack('SMS History cleared.');
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete SMS Record?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('This will permanently remove this scan result.', style: TextStyle(color: kTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: kMuted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Delete', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  String _getHash(String sender, String body) => "$sender|${body.hashCode}";

  Future<void> _scan() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      _snack('SMS Permissions denied', isError: true);
      return;
    }

    setState(() { _scanning = true; _status = 'Fetching messages from inbox...'; });
    
    try {
      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      // Filter for messages with URLs
      final filtered = messages.where((m) => 
        m.body != null && RegExp(r'https?://').hasMatch(m.body!)
      ).toList();

      setState(() { _total = filtered.length; _status = 'Found $_total messages with links. Analyzing...'; });

      final results = List<_ScanResult>.from(_results);
      int newFound = 0;

      for (int i = 0; i < filtered.length; i++) {
        final m = filtered[i];
        final hash = _getHash(m.address ?? 'Unknown', m.body ?? '');
        if (_scannedHashes.contains(hash)) continue;

        setState(() { _scanned = i + 1; _status = 'Analyzing message ${++newFound}...'; });

        try {
          final res = await http.post(
            Uri.parse('$kBaseUrl/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': m.body}),
          ).timeout(const Duration(seconds: 15));

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final urlExp = RegExp(r'https?://[^\s]+');
            final foundUrl = urlExp.firstMatch(m.body!)?[0] ?? '';

            results.add(_ScanResult(
              sender: m.address ?? 'Unknown',
              body: m.body!,
              explanation: data['explanation'] ?? '',
              isPhishing: data['status'] != 'SECURE',
              label: data['status'] ?? '',
              url: foundUrl,
              timestamp: DateTime.now(),
              phishtankMatch: data['phishtank_match'] == true,
              mlMatch: data['ml_match'] == true,
            ));
            _scannedHashes.add(hash);
            
            await StorageService.saveScan(
              text: m.body!,
              isPhishing: data['status'] != 'SECURE',
              explanation: data['explanation'] ?? '',
              source: 'SMS',
              provider: m.address ?? 'Unknown',
              phishtankMatch: data['phishtank_match'] == true,
              mlMatch: data['ml_match'] == true,
            );
          }
        } catch (_) {}
      }

      results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      results.sort((a, b) => (b.isPhishing ? 1 : 0).compareTo(a.isPhishing ? 1 : 0));

      setState(() {
        _results = results;
        _status = newFound > 0 ? 'Done — found $newFound new suspicious messages.' : 'No new messages to scan.';
        _page = 0;
      });
      _save();
    } catch (e) {
      _snack('Error: $e', isError: true);
    } finally {
      setState(() => _scanning = false);
    }
  }

  Future<void> _sendFeedback(String type, _ScanResult r) async {
    try {
      await http.post(
        Uri.parse('$kBaseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input_text': r.body,
          'ai_verdict_phishing': r.isPhishing,
          'feedback_type': type,
          'source': 'sms_scan',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      _snack(type == 'like'
          ? 'Thank you! AI will learn from this.'
          : 'Feedback received. We will re-analyze.');
    } catch (e) {
      // Error handled silently
    }
  }

  Future<void> _reportToPhishTank(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    final phishTankUrl = Uri.parse('https://phishtank.org/phish_submit.php');
    try {
      // ignore: unused_import
      await launchUrl(phishTankUrl, mode: LaunchMode.externalApplication);
    } catch (_) {}
    _snack('URL copied! Paste it on PhishTank to protect others.');
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? kPrimary : kSuccess)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
        Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06))),
          child: Row(children: [
            const Icon(Icons.security_rounded, color: kPrimary, size: 32),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
              Text('SMS Inbox Scanner', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Scan your messages for malicious links.', style: TextStyle(color: kTextSub, fontSize: 12)),
            ])),
            if (!_scanning)
              ElevatedButton(onPressed: _scan, child: const Text('Scan Now')),
          ])),
        
        if (_scanning)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Column(children: [
            Row(children: [
              const EagleLoader(size: 24),
              const SizedBox(width: 14),
              Expanded(child: Text(_status, style: const TextStyle(color: kTextSub, fontSize: 13))),
            ]),
            const SizedBox(height: 12),
            if (_total > 0)
              LinearProgressIndicator(value: _scanned / _total, backgroundColor: kSurface, valueColor: const AlwaysStoppedAnimation(kPrimary)),
          ])),
          
        if (!_scanning && _status.isNotEmpty)
          Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_status, style: const TextStyle(color: kTextSub, fontSize: 12))),

        if (_results.isNotEmpty && !_scanning)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Phishing', 'Suspicious', 'Safe']
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(f),
                                  selected: _filter == f,
                                  onSelected: (_) => setState(() {
                                    _filter = f;
                                    _page = 0;
                                  }),
                                  selectedColor: kPrimary,
                                  backgroundColor: kSurface,
                                  labelStyle: TextStyle(
                                      color: _filter == f ? Colors.white : kTextSub,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  side: BorderSide(
                                      color: _filter == f
                                          ? kPrimary
                                          : kMuted.withValues(alpha: 0.3)),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: kPrimary, size: 22),
                  onPressed: _clearAll,
                  tooltip: 'Clear All',
                ),
              ],
            ),
          ),

        if (_results.isEmpty && !_scanning)
          const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.textsms_rounded, color: kMuted, size: 64),
            SizedBox(height: 16),
            Text('No SMS scanned yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Tap "Scan Now" to check your messages', style: TextStyle(color: kTextSub, fontSize: 13)),
          ])))
        else
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            itemCount: _pageItems.length + 1,
            itemBuilder: (_, i) {
              if (i == _pageItems.length) return _pagination();
              final r = _pageItems[i];
              return Dismissible(
                key: ValueKey('${r.timestamp}_${r.body.hashCode}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _confirmDelete(context),
                onDismissed: (_) => _delete(r),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.delete_rounded, color: kPrimary),
                ),
                child: UnifiedThreatCard(
                  source: 'SMS: ${r.sender}',
                  text: r.body,
                  explanation: r.explanation,
                  isPhishing: r.isPhishing,
                  phishtankMatch: r.phishtankMatch,
                  mlMatch: r.mlMatch,
                  timestamp: r.timestamp,
                  url: r.url,
                  onReport: () => _reportToPhishTank(r.url),
                  onFeedback: (type) => _sendFeedback(type, r),
                ),
              );
            },
          )),
      ]);
  }

  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: _page > 0 ? () => setState(() => _page--) : null),
        Text('Page ${_page + 1} of $_maxPages', style: const TextStyle(color: Colors.white, fontSize: 12)),
        IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _page < _maxPages - 1 ? () => setState(() => _page++) : null),
      ]),
    );
  }
}
