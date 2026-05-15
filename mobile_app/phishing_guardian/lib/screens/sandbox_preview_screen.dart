import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';

/// Opens a URL in a sandboxed WebView with JavaScript DISABLED.
/// Shows a prominent warning banner so the user knows this is a safe preview.
class SandboxPreviewScreen extends StatefulWidget {
  final String url;
  const SandboxPreviewScreen({super.key, required this.url});

  @override
  State<SandboxPreviewScreen> createState() => _SandboxPreviewScreenState();
}

class _SandboxPreviewScreenState extends State<SandboxPreviewScreen> {
  late final WebViewController _ctrl;
  double _progress = 0;
  bool _loading = true;
  bool _warningDismissed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      // ── JavaScript OFF for safety ──────────────────────────────────
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(kBg)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => _progress = p / 100),
        onPageFinished: (_) => setState(() => _loading = false),
        onPageStarted: (_) => setState(() => _loading = true),
        // Block navigation away from the original URL
        onNavigationRequest: (req) {
          if (req.url == widget.url) return NavigationDecision.navigate;
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A0A0A),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.lock_rounded, color: kSuccess, size: 12),
            SizedBox(width: 4),
            Text('SANDBOX MODE', style: TextStyle(color: kSuccess, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ]),
          Text(widget.url,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_loading ? 3 : 0),
          child: _loading
              ? LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: kSurface,
                  valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
                  minHeight: 3)
              : const SizedBox.shrink(),
        ),
      ),
      body: Stack(children: [
        WebViewWidget(controller: _ctrl),
        // Warning banner
        if (!_warningDismissed)
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              decoration: const BoxDecoration(
                color: Color(0xCC0F0F1A),
                border: Border(top: BorderSide(color: kPrimary, width: 1)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_rounded, color: kPrimary, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Sandbox Preview — JavaScript is disabled. This page cannot steal data or redirect you.',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _warningDismissed = true),
                  child: const Icon(Icons.close_rounded, color: kMuted, size: 18),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
