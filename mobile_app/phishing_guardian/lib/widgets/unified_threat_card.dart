import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../screens/sandbox_preview_screen.dart';

class UnifiedThreatCard extends StatelessWidget {
  final String source;
  final String text;
  final String explanation;
  final bool isPhishing;
  final bool phishtankMatch;
  final bool mlMatch;
  final DateTime timestamp;
  final String? sender;
  final String? subject;
  final String url;
  
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final Function(String)? onFeedback; // 'like' or 'dislike'

  const UnifiedThreatCard({
    super.key,
    required this.source,
    required this.text,
    required this.explanation,
    required this.isPhishing,
    required this.phishtankMatch,
    required this.mlMatch,
    required this.timestamp,
    required this.url,
    this.sender,
    this.subject,
    this.onDelete,
    this.onReport,
    this.onFeedback,
  });

  void _showFullMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kSurface,
        title: Row(
          children: [
            const Icon(Icons.message_rounded, color: kPrimary),
            const SizedBox(width: 8),
            const Text('Full Message', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sender != null && sender!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('From: $sender', style: const TextStyle(color: kMuted, fontSize: 13)),
                ),
              if (subject != null && subject!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text('Subject: $subject', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy • h:mm a');
    final label = isPhishing 
      ? (phishtankMatch ? 'BLACKLISTED' : (mlMatch ? 'PHISHING' : 'SUSPICIOUS'))
      : 'SECURE';
    final labelColor = isPhishing 
      ? (phishtankMatch || mlMatch ? kPrimary : const Color(0xFFFF9800))
      : kSuccess;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: labelColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(
                isPhishing ? Icons.dangerous_rounded : Icons.check_circle_rounded,
                color: labelColor, size: 20,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: labelColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  label,
                  style: TextStyle(color: labelColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  fmt.format(timestamp),
                  style: const TextStyle(color: kMuted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onFeedback != null) ...[
                GestureDetector(
                  onTap: () => onFeedback!('like'),
                  child: const Icon(Icons.thumb_up_alt_outlined, size: 16, color: kMuted),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => onFeedback!('dislike'),
                  child: const Icon(Icons.thumb_down_alt_outlined, size: 16, color: kMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Message Preview
          if (subject != null && subject!.isNotEmpty)
            Text(subject!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (sender != null && sender!.isNotEmpty)
            Text(sender!, style: const TextStyle(color: kTextSub, fontSize: 11)),
          
          const SizedBox(height: 8),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showFullMessage(context),
            child: const Text('View Full Message', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 12, fontWeight: FontWeight.w600)),
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 12),

          // Layering Breakdown
          const Text('Scan Breakdown', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _buildLayer('PhishTank Global DB', phishtankMatch ? 'MATCHED' : 'SAFE', phishtankMatch ? kPrimary : kSuccess),
          _buildLayer('AI Classifier Model', mlMatch ? 'PHISHING' : 'SECURE', mlMatch ? kPrimary : kSuccess),
          _buildLayer('Human-like Reasoning (AI)', isPhishing ? 'PHISHING' : 'SECURE', isPhishing ? kPrimary : kSuccess),
          
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: labelColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: labelColor.withOpacity(0.1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: labelColor, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation,
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          if (url.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SandboxPreviewScreen(url: url))),
                    child: Row(
                      children: const [
                        Icon(Icons.security_rounded, color: kSuccess, size: 14),
                        SizedBox(width: 6),
                        Text('Sandbox Preview', style: TextStyle(color: kSuccess, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                if (isPhishing)
                  GestureDetector(
                    onTap: () {
                      if (onReport != null) {
                        onReport!();
                      } else {
                        Clipboard.setData(ClipboardData(text: url));
                        launchUrl(Uri.parse('https://phishtank.org/phish_submit.php'), mode: LaunchMode.externalApplication);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL copied! Paste it on PhishTank.')));
                      }
                    },
                    child: Row(
                      children: const [
                        Icon(Icons.public_rounded, color: Color(0xFF42A5F5), size: 14),
                        SizedBox(width: 4),
                        Text('Report to PhishTank', style: TextStyle(color: Color(0xFF42A5F5), fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLayer(String title, String status, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
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
}
