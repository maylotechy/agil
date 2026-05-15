import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import '../services/storage_service.dart';

class _Message {
  final String role; // 'user' | 'ai'
  final String content;
  _Message(this.role, this.content);
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  // Static so messages survive tab switches
  static final List<_Message> _messages = [];
  bool _thinking = false;

  static const _suggestions = [
    'What is phishing? 🎣',
    'How do I spot a scam SMS?',
    'What is smishing?',
    'Tips to stay safe online',
  ];

  @override
  void initState() {
    super.initState();
    if (_messages.isEmpty) _loadHistory();
  }

  Future<void> _loadHistory() async {
    final hist = await StorageService.getChatHistory();
    if (hist.isNotEmpty && mounted) {
      setState(() {
        _messages.addAll(hist.map((e) => _Message(e['role'] ?? 'user', e['content'] ?? '')));
      });
      _scrollToBottom();
    }
  }

  Future<void> _saveHistory() async {
    final hist = _messages.map((e) => {'role': e.role, 'content': e.content}).toList();
    await StorageService.saveChatHistory(hist);
  }

  Future<void> _clearChat() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Clear Chat', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to delete the chat history?', style: TextStyle(color: kTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _messages.clear());
      await StorageService.clearChatHistory();
    }
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _thinking) return;
    _ctrl.clear();

    setState(() {
      _messages.add(_Message('user', trimmed));
      _thinking = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m.role != 'ai' || _messages.indexOf(m) < _messages.length - 1)
          .map((m) => {'role': m.role, 'content': m.content})
          .toList();

      final res = await http.post(
        Uri.parse('$kBaseUrl/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'message': trimmed, 'history': history}),
      ).timeout(const Duration(seconds: 15));

      final reply = res.statusCode == 200
          ? (jsonDecode(res.body)['reply'] ?? 'No response.')
          : 'Server cannot be reached. Please try again later.';

      setState(() => _messages.add(_Message('ai', reply)));
      _saveHistory();
    } catch (_) {
      setState(() => _messages.add(
            _Message('ai', 'Server cannot be reached. Please try again later.'),
          ));
    } finally {
      _saveHistory();
      setState(() => _thinking = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // ── Handle / Header ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 8, 12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/images/chatbot.jpg', width: 28, height: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Agil AI', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Security Assistant • Online', style: TextStyle(color: kSuccess, fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: kMuted),
              onPressed: _messages.isEmpty ? null : _clearChat,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: kMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        const Divider(color: Colors.white10, height: 1),
        // ── Suggestion chips (shown when empty) ──────────────────────
        if (_messages.isEmpty)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset('assets/images/chatbot.jpg', width: 120, height: 120),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ask me anything about cybersecurity!',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('I can analyze URLs, explain phishing tactics,\nand help you stay safe online.',
                      style: TextStyle(color: kTextSub, fontSize: 13), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _suggestions
                        .map((s) => GestureDetector(
                              onTap: () => _send(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: kSurface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                                ),
                                child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          )
        else
          // ── Message List ─────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              itemCount: _messages.length + (_thinking ? 1 : 0),
              itemBuilder: (_, i) {
                if (_thinking && i == _messages.length) {
                  return _bubble(_Message('ai', '...'), isTyping: true);
                }
                return _bubble(_messages[i]);
              },
            ),
          ),

        // ── Input Bar ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
          decoration: BoxDecoration(
            color: kBg,
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.07))),
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Ask about phishing, scams, URLs...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: _send,
                textInputAction: TextInputAction.send,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _send(_ctrl.text),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ]),
        ),
        // Keyboard padding for bottom sheet
        SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
      ]),
    );
  }

  Widget _bubble(_Message msg, {bool isTyping = false}) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30, height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/chatbot.jpg', width: 24, height: 24),
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? kPrimary : kSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isTyping
                  ? _TypingDots()
                  : Text(msg.content,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.white.withOpacity(0.9),
                        fontSize: 13, height: 1.5,
                      )),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          final offset = ((_c.value * 3) - i).clamp(0.0, 1.0);
          final opacity = (offset < 0.5 ? offset * 2 : (1 - offset) * 2).clamp(0.3, 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: kTextSub.withOpacity(opacity),
              shape: BoxShape.circle,
            ),
          );
        }));
      },
    );
  }
}
