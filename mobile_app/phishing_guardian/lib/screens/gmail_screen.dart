import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../widgets/eagle_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/about_app_dialog.dart';
import '../services/storage_service.dart';
import 'sandbox_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/unified_threat_card.dart';

class _ScanResult {
  final String id, subject, sender, explanation, url;
  final bool isPhishing;
  final String label;
  final bool phishtankMatch;
  final bool mlMatch;
  _ScanResult({
    required this.id, required this.subject, required this.sender,
    required this.explanation, required this.isPhishing,
    required this.url,
    this.label = '',
    this.phishtankMatch = false,
    this.mlMatch = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'subject': subject, 'sender': sender, 'explanation': explanation,
    'isPhishing': isPhishing, 'url': url, 'label': label, 
    'phishtankMatch': phishtankMatch, 'mlMatch': mlMatch,
  };

  factory _ScanResult.fromJson(Map<String, dynamic> j) => _ScanResult(
    id: j['id'] ?? '', subject: j['subject'] ?? '', sender: j['sender'] ?? '',
    explanation: j['explanation'] ?? '', isPhishing: j['isPhishing'] ?? false,
    url: j['url'] ?? '',
    label: j['label'] ?? (j['isPhishing'] == true ? 'PHISHING DETECTED' : 'SECURE'),
    phishtankMatch: j['phishtankMatch'] ?? false,
    mlMatch: j['mlMatch'] ?? false,
  );
}

class GmailScreen extends StatefulWidget {
  const GmailScreen({super.key});
  @override
  State<GmailScreen> createState() => _GmailScreenState();
}

class _GmailScreenState extends State<GmailScreen> {
  static final _gsi = GoogleSignIn(scopes: [
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.modify',
  ]);

  GoogleSignInAccount? _account;
  bool _scanning = false;
  List<_ScanResult> _results = [];
  Set<String> _scannedIds = {};
  Set<String> _blockedSenders = {};
  String _status = '';
  int _scanned = 0, _total = 0;
  String _filter = 'All'; // All | Phishing | Suspicious | Safe
  int _page = 0;
  static const _perPage = 5;

  List<_ScanResult> get _filteredResults {
    var src = _results.where((r) => !_blockedSenders.contains(r.sender)).toList();
    if (_filter == 'All') return src;
    if (_filter == 'Phishing') return src.where((r) => r.isPhishing && (r.phishtankMatch || r.mlMatch)).toList();
    if (_filter == 'Suspicious') return src.where((r) => r.isPhishing && !r.phishtankMatch && !r.mlMatch).toList();
    return src.where((r) => !r.isPhishing).toList();
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
    _gsi.signInSilently().then((a) { if (mounted) setState(() => _account = a); });
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRes = prefs.getString('gmail_scans');
    final rawIds = prefs.getStringList('gmail_scanned_ids');
    final rawBlocked = prefs.getStringList('gmail_blocked_senders');
    if (mounted) setState(() {
      if (rawRes != null) {
        try {
          final list = jsonDecode(rawRes) as List;
          _results = list.map((e) => _ScanResult.fromJson(e)).toList();
        } catch (_) {}
      }
      if (rawIds != null) _scannedIds = rawIds.toSet();
      if (rawBlocked != null) _blockedSenders = rawBlocked.toSet();
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gmail_scans', jsonEncode(_results.map((e) => e.toJson()).toList()));
    await prefs.setStringList('gmail_scanned_ids', _scannedIds.toList());
    await prefs.setStringList('gmail_blocked_senders', _blockedSenders.toList());
  }

  Future<void> _delete(_ScanResult r) async {
    setState(() {
      _results.remove(r);
      _scannedIds.remove(r.id);
    });
    await _save();
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear All Gmail Scans?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('This will remove all Gmail scan history from this app. This cannot be undone.', style: TextStyle(color: kTextSub)),
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
        _scannedIds.clear();
        _page = 0;
      });
      await _save();
      _snack('Gmail History cleared.');
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Gmail Record?', style: TextStyle(color: Colors.white, fontSize: 18)),
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

  Future<void> _signIn() async {
    try {
      final a = await _gsi.signIn();
      if (mounted) setState(() => _account = a);
    } catch (e) {
      _snack('Sign-in failed: $e');
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out of Google?',
            style: TextStyle(color: kTextSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _gsi.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('gmail_scans');
      await prefs.remove('gmail_scanned_ids');
      if (mounted) setState(() { _account = null; _results = []; _scannedIds = {}; _status = ''; _page = 0; });
    }
  }

  Future<void> _sendFeedback(String subject, String sender, String explanation, String type, bool isPhishing) async {
    try {
      await http.post(
        Uri.parse('$kBaseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input_text': '[$subject] from $sender: $explanation'.substring(0, 500),
          'ai_verdict_phishing': isPhishing,
          'feedback_type': type,
          'source': 'gmail_tab',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
      _snack(type == 'like' ? 'Thank you! AI will learn from this.' : 'Feedback received. We will re-analyze.');
    } catch (e) {
      // Error handled silently
    }
  }

  Future<void> _scan() async {
    if (_account == null) return;
    setState(() { _scanning = true; _results = []; _scanned = 0; _status = 'Fetching emails from inbox & spam...'; });
    try {
      final headers = await _account!.authHeaders;
      final listRes = await http.get(
        Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=50&q=in:inbox+OR+in:spam'),
        headers: headers,
      );
      if (listRes.statusCode != 200) { _snack('Gmail API error ${listRes.statusCode}'); return; }

      final messages = (jsonDecode(listRes.body)['messages'] as List?) ?? [];
      setState(() { _total = messages.length; _status = 'Found $_total emails. Checking for new ones...'; });

      final results = List<_ScanResult>.from(_results);
      int newFound = 0;
      for (int i = 0; i < messages.length; i++) {
        final id = messages[i]['id'] as String;
        if (_scannedIds.contains(id)) continue;

        setState(() { _scanned = i + 1; _status = 'Analyzing new email ${++newFound}...'; });
        try {
          final msgRes = await http.get(
            Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=full'),
            headers: headers,
          );
          if (msgRes.statusCode != 200) continue;
          final msgData = jsonDecode(msgRes.body);

          final hdrs = msgData['payload']['headers'] as List? ?? [];
          String subject = '', sender = '';
          for (final h in hdrs) {
            if (h['name'] == 'Subject') subject = h['value'] ?? '';
            if (h['name'] == 'From') sender = h['value'] ?? '';
          }

          final body = _extractBody(msgData['payload']);
          if (body.isEmpty) continue;

          final hasUrl = RegExp(r'https?://').hasMatch(body);
          if (!hasUrl) continue;

          final scanRes = await http.post(
            Uri.parse('$kBaseUrl/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': body.substring(0, body.length.clamp(0, 600))}),
          ).timeout(const Duration(seconds: 15));
          if (scanRes.statusCode != 200) continue;
          final sd = jsonDecode(scanRes.body);
          
          final urlExp = RegExp(r'https?://[^\s]+');
          final foundUrl = urlExp.firstMatch(body)?[0] ?? 
                          urlExp.firstMatch(subject)?[0] ?? '';

          results.add(_ScanResult(
            id: id,
            subject: subject.isEmpty ? '(No subject)' : subject,
            sender: sender,
            isPhishing: sd['status'] != 'SECURE',
            label: sd['status'] ?? '',
            explanation: sd['explanation'] ?? '',
            url: foundUrl,
            phishtankMatch: sd['phishtank_match'] == true,
            mlMatch: sd['ml_match'] == true,
          ));
          _scannedIds.add(id);

          await StorageService.saveScan(
            text: body.substring(0, body.length.clamp(0, 600)),
            isPhishing: sd['status'] != 'SECURE',
            explanation: sd['explanation'] ?? '',
            source: 'Gmail',
            provider: sender,
            phishtankMatch: sd['phishtank_match'] == true,
            mlMatch: sd['ml_match'] == true,
          );
        } catch (_) { continue; }
      }
      results.sort((a, b) => (b.isPhishing ? 1 : 0).compareTo(a.isPhishing ? 1 : 0));
      
      setState(() { 
        _results = results; 
        _status = newFound > 0 ? 'Done — found $newFound new emails.' : 'No new emails to scan.';
        _page = 0; 
      });
      _save();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      setState(() => _scanning = false);
    }
  }

  String _extractBody(Map<String, dynamic> payload) {
    if (payload['parts'] != null) {
      for (final part in payload['parts'] as List) {
        final mime = part['mimeType'] ?? '';
        if (mime == 'text/plain' || mime == 'text/html') {
          final data = part['body']?['data'];
          if (data != null) {
            try { return utf8.decode(base64Url.decode((data as String).replaceAll('-', '+').replaceAll('_', '/'))); }
            catch (_) {}
          }
        }
        if (part['parts'] != null) {
          final nested = _extractBody(Map<String, dynamic>.from(part));
          if (nested.isNotEmpty) return nested;
        }
      }
    }
    final data = payload['body']?['data'];
    if (data != null) {
      try { return utf8.decode(base64Url.decode((data as String).replaceAll('-', '+').replaceAll('_', '/'))); }
      catch (_) {}
    }
    return '';
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? kPrimary : kSuccess)
    );
    setState(() => _scanning = false);
  }

  Future<void> _reportToPhishTank(String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    final phishTankUrl = Uri.parse('https://phishtank.org/phish_submit.php');
    try {
      await launchUrl(phishTankUrl, mode: LaunchMode.externalApplication);
    } catch (_) {}
    _snack('URL copied! Paste it on PhishTank to protect others.');
  }

  @override
  Widget build(BuildContext context) {
    return _account == null ? _loginView() : _scanView();
  }

  Widget _loginView() => Center(
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 100, height: 100,
        decoration: BoxDecoration(shape: BoxShape.circle, color: kSurface,
            border: Border.all(color: kPrimary.withValues(alpha: 0.35), width: 2)),
        child: const Icon(Icons.mail_outline_rounded, color: kPrimary, size: 52)),
      const SizedBox(height: 22),
      const Text('Connect Your Gmail', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      const Text('Sign in so we can automatically scan every email that contains a link for phishing threats.',
          textAlign: TextAlign.center, style: TextStyle(color: kTextSub, fontSize: 13, height: 1.5)),
      const SizedBox(height: 18),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(
          color: kSurface, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
        child: Column(children: [
          _row(Icons.lock_rounded, 'Read-only — we never modify your emails'),
          const SizedBox(height: 8),
          _row(Icons.phonelink_lock_rounded, 'Scan results stay local on your device'),
          const SizedBox(height: 8),
          _row(Icons.link_rounded, 'Only emails containing links are scanned'),
        ])),
      const SizedBox(height: 26),
      SizedBox(width: double.infinity, height: 52,
        child: ElevatedButton.icon(onPressed: _signIn,
            icon: const Icon(Icons.login_rounded),
            label: const Text('Sign in with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)))),
    ])),
  );

  Widget _row(IconData icon, String text) => Row(children: [
    Icon(icon, color: kSuccess, size: 16), const SizedBox(width: 10),
    Expanded(child: Text(text, style: const TextStyle(color: kTextSub, fontSize: 12))),
  ]);

  Widget _scanView() => Column(children: [
    Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Row(children: [
        CircleAvatar(radius: 22, backgroundColor: kPrimary.withValues(alpha: 0.15),
          child: Text((_account?.displayName ?? 'U')[0].toUpperCase(),
              style: const TextStyle(color: kPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_account?.displayName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text(_account?.email ?? '', style: const TextStyle(color: kTextSub, fontSize: 12)),
        ])),
        if (!_scanning)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: kMuted),
                onPressed: _signOut,
                tooltip: 'Sign out',
              ),
              ElevatedButton.icon(
                onPressed: _scan,
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Scan'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              ),
            ],
          ),
      ])),
    if (_scanning)
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: Column(children: [
        Row(children: [
          const EagleLoader(size: 24),
          const SizedBox(width: 14),
          Expanded(child: Text(_status, style: const TextStyle(color: kTextSub, fontSize: 13))),
        ]),
        if (_total > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _total > 0 ? _scanned / _total : null,
              backgroundColor: kSurface, valueColor: const AlwaysStoppedAnimation(kPrimary)),
        ],
      ])),
    if (!_scanning && _status.isNotEmpty)
      Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Text(_status, style: const TextStyle(color: kTextSub, fontSize: 12))),
    
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
                        .toList()),
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
      Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.inbox_rounded, color: kMuted, size: 64),
        SizedBox(height: 16),
        Text('Inbox not scanned yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Text('Tap "Scan Inbox" to check your emails', style: TextStyle(color: kTextSub, fontSize: 13)),
      ])))
    else
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        itemCount: _pageItems.length + 1,
        itemBuilder: (_, i) {
          if (i == _pageItems.length) return _pagination();
          final r = _pageItems[i];
          return Dismissible(
            key: ValueKey(r.id),
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
              source: 'Gmail: ${r.sender}',
              text: '[${r.subject}]\nSender: ${r.sender}',
              explanation: r.explanation,
              isPhishing: r.isPhishing,
              phishtankMatch: r.phishtankMatch,
              mlMatch: r.mlMatch,
              timestamp: DateTime.now(),
              url: r.url,
              onReport: () => _reportToPhishTank(r.url),
              onFeedback: (type) => _sendFeedback(r.subject, r.sender, r.explanation, type, r.isPhishing),
            ),
          );
        },
      )),
  ]);

  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
          color: _page > 0 ? kPrimary : kMuted,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimary.withOpacity(0.3)),
          ),
          child: Text('Page ${_page + 1} of $_maxPages',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 28),
          onPressed: _page < _maxPages - 1 ? () => setState(() => _page++) : null,
          color: _page < _maxPages - 1 ? kPrimary : kMuted,
        ),
      ]),
    );
  }
}
