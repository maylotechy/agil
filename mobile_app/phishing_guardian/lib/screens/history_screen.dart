import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import '../main.dart';
import '../widgets/about_app_dialog.dart';
import '../services/storage_service.dart';
import '../widgets/eagle_loader.dart';
import '../widgets/unified_threat_card.dart';
import 'sandbox_preview_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sms_screen.dart';
import 'gmail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  List<ScanRecord> _records = [];
  bool _loading = true;
  String _filter = 'All'; // All | Phishing | Safe | Suspicious
  int _page = 0;
  static const int _perPage = 5;

  List<ScanRecord> get _filteredManualRecords {
    final manual = _records.where((r) => r.source == 'Manual').toList();
    if (_filter == 'All') return manual;
    if (_filter == 'Phishing') return manual.where((r) => r.isPhishing && (r.phishtankMatch || r.mlMatch)).toList();
    if (_filter == 'Suspicious') return manual.where((r) => r.isPhishing && !r.phishtankMatch && !r.mlMatch).toList();
    return manual.where((r) => !r.isPhishing).toList();
  }

  List<ScanRecord> get _pageItems {
    final src = _filteredManualRecords;
    final start = _page * _perPage;
    final end = (start + _perPage).clamp(0, src.length);
    return src.sublist(start, end);
  }

  int get _maxPages => (_filteredManualRecords.length / _perPage).ceil().clamp(1, 999);

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _load();
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await StorageService.getRecords();
    setState(() { 
      _records = r; 
      _loading = false; 
      if (_page >= _maxPages) _page = (_maxPages - 1).clamp(0, 9999);
    });
  }

  Future<void> _delete(int i) async {
    final item = _pageItems[i];
    final realIndex = _records.indexOf(item);
    if (realIndex != -1) {
      await StorageService.deleteRecord(realIndex);
      await _load();
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Record?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text('This will permanently remove this scan from your history.', style: TextStyle(color: kTextSub)),
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

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear History', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete all scan records.',
            style: TextStyle(color: kTextSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: kMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await StorageService.clearHistory();
      _page = 0;
      await _load();
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
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open email app'))
        );
      }
    }
  }

  Future<void> _sendFeedback(String text, bool isPhishing, String type) async {
    try {
      await http.post(
        Uri.parse('$kBaseUrl/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'input_text': text.substring(0, text.length.clamp(0, 500)),
          'ai_verdict_phishing': isPhishing,
          'feedback_type': type,
          'source': 'history_tab',
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Row(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.history_rounded, color: kPrimary, size: 20),
            SizedBox(width: 8),
            Text('Threat Center'),
          ]),
          bottom: const TabBar(
            indicatorColor: kPrimary,
            labelColor: kPrimary,
            unselectedLabelColor: kMuted,
            tabs: [
              Tab(text: 'Manual'),
              Tab(text: 'SMS'),
              Tab(text: 'Gmail'),
            ],
          ),
          actions: [
            if (_records.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, color: kPrimary),
                onPressed: _clearAll,
                tooltip: 'Clear All',
              ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildManualTab(),
            const SmsScreen(),
            const GmailScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildManualTab() {
    final manualRecords = _filteredManualRecords;
    
    if (_loading) {
      return const Center(child: EagleLoader(size: 60, message: 'Loading history...'));
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(
            children: ['All', 'Phishing', 'Suspicious', 'Safe']
                .map((f) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f, style: const TextStyle(fontSize: 11)),
                        selected: _filter == f,
                        onSelected: (_) => setState(() {
                          _filter = f;
                          _page = 0;
                        }),
                        selectedColor: kPrimary,
                        backgroundColor: kSurface,
                        labelStyle: TextStyle(
                            color: _filter == f ? Colors.white : kTextSub,
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
        Expanded(
          child: manualRecords.isEmpty
              ? _emptyView()
              : RefreshIndicator(
                  color: kPrimary,
                  backgroundColor: kSurface,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    itemCount: _pageItems.length + 1,
                    itemBuilder: (_, i) {
                      if (i == _pageItems.length) return _pagination();
                      final r = _pageItems[i];
                      return _dismissible(r, i);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _dismissible(ScanRecord r, int i) {
    return Dismissible(
      key: ValueKey('${r.timestamp}_$i'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: kPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: kPrimary),
      ),
      onDismissed: (_) => _delete(i),
      child: UnifiedThreatCard(
        source: r.source,
        text: r.text,
        explanation: r.explanation,
        isPhishing: r.isPhishing,
        phishtankMatch: r.phishtankMatch,
        mlMatch: r.mlMatch,
        timestamp: r.timestamp,
        url: RegExp(r'https?://[^\s]+').firstMatch(r.text)?[0] ?? '',
        onReport: () => _report(RegExp(r'https?://[^\s]+').firstMatch(r.text)?[0] ?? r.text),
        onFeedback: (type) => _sendFeedback(r.text, r.isPhishing, type),
      ),
    );
  }
  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/animations/nothing.json',
            width: 250,
            height: 250,
            repeat: true,
            frameRate: FrameRate.max,
            errorBuilder: (context, error, stackTrace) => Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.history_rounded, size: 80, color: kMuted),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text('Debug: $error', textAlign: TextAlign.center, style: const TextStyle(color: kMuted, fontSize: 9)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Text('Scan Center is Empty',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Analysis results will appear here.',
              style: TextStyle(color: kTextSub, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
          color: _page > 0 ? kPrimary : kMuted,
        ),
        Text('Page ${_page + 1} of $_maxPages',
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 28),
          onPressed: _page < _maxPages - 1 ? () => setState(() => _page++) : null,
          color: _page < _maxPages - 1 ? kPrimary : kMuted,
        ),
      ]),
    );
  }
}
