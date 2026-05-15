import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';

class ArticleViewerScreen extends StatefulWidget {
  final String url;
  final String title;
  final String source;

  const ArticleViewerScreen({
    super.key,
    required this.url,
    required this.title,
    required this.source,
  });

  @override
  State<ArticleViewerScreen> createState() => _ArticleViewerScreenState();
}

class _ArticleViewerScreenState extends State<ArticleViewerScreen> {
  late final WebViewController _ctrl;
  double _progress = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(kBg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageFinished: (_) => setState(() => _loading = false),
        onPageStarted: (_) => setState(() => _loading = true),
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.source,
              style: const TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
          Text(widget.title,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: () => _ctrl.reload(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_loading ? 3 : 0),
          child: _loading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: kSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                  minHeight: 3,
                )
              : const SizedBox.shrink(),
        ),
      ),
      body: WebViewWidget(controller: _ctrl),
    );
  }
}
