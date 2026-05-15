import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../widgets/eagle_loader.dart';
import 'article_viewer_screen.dart';
import '../widgets/youtube_awareness_widget.dart';
import 'package:lottie/lottie.dart';

class _Article {
  final String title, summary, url, published, source, lang;
  _Article({
    required this.title, required this.summary, required this.url,
    required this.published, required this.source, required this.lang,
  });
  factory _Article.fromJson(Map<String, dynamic> j) => _Article(
        title: j['title'] ?? '',
        summary: j['summary'] ?? '',
        url: j['url'] ?? '',
        published: j['published'] ?? '',
        source: j['source'] ?? 'News',
        lang: j['lang'] ?? 'EN',
      );
}

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});
  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<_Article> _articles = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  static const _perPage = 6;
  String _langFilter = 'All'; // All | EN | FIL

  List<_Article> get _filtered {
    if (_langFilter == 'All') return _articles;
    return _articles.where((a) => a.lang == _langFilter).toList();
  }

  List<_Article> get _pageItems {
    final src = _filtered;
    final start = _page * _perPage;
    final end = (start + _perPage).clamp(0, src.length);
    return src.sublist(start, end);
  }

  int get _maxPages => (_filtered.length / _perPage).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; _page = 0; });
    try {
      final res = await http.get(Uri.parse('$kBaseUrl/news')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['articles'] as List)
            .map((a) => _Article.fromJson(a))
            .toList();
        setState(() => _articles = list);
      } else {
        setState(() => _error = 'Server returned ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Server cannot be reached.');
    } finally {
      setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/app_iconv2.png', width: 28, height: 28, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          const Text('Cyber Threat News'),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: EagleLoader(size: 60, message: 'Fetching news...'))
          : _error != null
              ? _errorView()
              : RefreshIndicator(
                  color: kPrimary,
                  backgroundColor: kSurface,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                    children: [
                      const SizedBox(height: 12),
                      Row(
                          children: ['All', 'EN', 'FIL']
                              .map((f) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(f),
                                      selected: _langFilter == f,
                                      onSelected: (_) => setState(() {
                                        _langFilter = f;
                                        _page = 0;
                                      }),
                                      selectedColor: kPrimary,
                                      backgroundColor: kSurface,
                                      labelStyle: TextStyle(
                                          color: _langFilter == f
                                              ? Colors.white
                                              : kTextSub,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                      side: BorderSide(
                                          color: _langFilter == f
                                              ? kPrimary
                                              : kMuted.withValues(alpha: 0.3)),
                                    ),
                                  ))
                              .toList()),
                      const SizedBox(height: 16),
                      if (_filtered.isEmpty)
                        const Column(
                          children: [
                            SizedBox(height: 60),
                            Icon(Icons.article_rounded, color: kMuted, size: 64),
                            SizedBox(height: 16),
                            Text('No news found',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center),
                          ],
                        )
                      else
                        ..._pageItems.map((a) => _card(a)).toList(),
                      _pagination(),
                    ],
                  ),
                ),
    );
  }

  Widget _card(_Article a) {
    final langColor = a.source.contains('FIL') ? const Color(0xFF1565C0) : kPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
              child: Text(a.source, style: const TextStyle(color: kSecondary, fontSize: 10, fontWeight: FontWeight.w600))),
            const SizedBox(width: 6),
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: langColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text(a.source.contains('FIL') ? 'FIL' : 'EN',
                  style: TextStyle(color: langColor, fontSize: 9, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Expanded(child: Text(a.published, style: const TextStyle(color: kMuted, fontSize: 10),
                overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 10),
          Text(a.title, style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
          if (a.summary.isNotEmpty) ...[const SizedBox(height: 6),
            Text(a.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextSub, fontSize: 12, height: 1.5))],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ArticleViewerScreen(url: a.url, title: a.title, source: a.source))),
            child: Row(children: const [
              Text('Read Article', style: TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
              SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, color: kPrimary, size: 13),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 28),
          onPressed: _page > 0
              ? () => setState(() { _page--; })
              : null,
          color: _page > 0 ? kPrimary : kMuted,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimary.withOpacity(0.3)),
          ),
          child: Text(
            'Page ${_page + 1} of $_maxPages',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 28),
          onPressed: _page < _maxPages - 1
              ? () => setState(() { _page++; })
              : null,
          color: _page < _maxPages - 1 ? kPrimary : kMuted,
        ),
      ]),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Lottie.asset('assets/animations/not found.json', width: 150, height: 150),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: kTextSub, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ]),
        ),
      );
}

