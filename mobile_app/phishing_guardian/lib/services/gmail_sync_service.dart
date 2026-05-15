import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/storage_service.dart';
import '../main.dart';

class GmailSyncService {
  static final _gsi = GoogleSignIn(scopes: ['https://www.googleapis.com/auth/gmail.readonly']);

  static Future<void> syncAndNotify(FlutterLocalNotificationsPlugin notify) async {
    try {
      final account = await _gsi.signInSilently();
      if (account == null) return;

      final headers = await account.authHeaders;
      final prefs = await SharedPreferences.getInstance();
      
      final scannedIds = (prefs.getStringList('gmail_scanned_ids') ?? []).toSet();
      final resultsRaw = prefs.getString('gmail_scans');
      final currentResults = resultsRaw != null ? jsonDecode(resultsRaw) as List : [];

      // Fetch latest 10 messages
      final res = await http.get(
        Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=10&q=in:inbox+OR+in:spam'),
        headers: headers,
      );
      if (res.statusCode != 200) return;
      final messages = (jsonDecode(res.body)['messages'] as List?) ?? [];

      bool foundNewPhishing = false;
      int newCount = 0;

      for (final m in messages) {
        final id = m['id'] as String;
        if (scannedIds.contains(id)) continue;

        final msgRes = await http.get(
          Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=full'),
          headers: headers,
        );
        if (msgRes.statusCode != 200) continue;
        final msgData = jsonDecode(msgRes.body);

        final body = _extractText(msgData['payload']);
        if (body.contains('http://') || body.contains('https://')) {
          final scanRes = await http.post(
            Uri.parse('$kBaseUrl/scan'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'message': body.substring(0, body.length.clamp(0, 600))}),
          ).timeout(const Duration(seconds: 15));

          if (scanRes.statusCode == 200) {
            final sd = jsonDecode(scanRes.body);
            final isPhishing = sd['status'] != 'SECURE';
            
            // Extract headers for storage
            final hdrs = msgData['payload']['headers'] as List? ?? [];
            String subject = '', sender = '';
            for (final h in hdrs) {
              if (h['name'] == 'Subject') subject = h['value'] ?? '';
              if (h['name'] == 'From') sender = h['value'] ?? '';
            }

            currentResults.insert(0, {
              'subject': subject.isEmpty ? '(No subject)' : subject,
              'sender': sender,
              'isPhishing': isPhishing,
              'label': sd['status'] ?? '',
              'explanation': sd['explanation'] ?? '',
              'url': _findUrl(body) ?? '',
            });

            await StorageService.saveScan(
              text: body.substring(0, body.length.clamp(0, 600)),
              isPhishing: isPhishing,
              explanation: sd['explanation'] ?? '',
              source: 'Gmail',
              provider: sd['provider'] ?? 'Unknown',
              phishtankMatch: sd['phishtank_match'] == true,
              mlMatch: sd['ml_match'] == true,
            );

            if (isPhishing) foundNewPhishing = true;
            newCount++;
          }
        }
        scannedIds.add(id);
      }

      if (newCount > 0) {
        await prefs.setString('gmail_scans', jsonEncode(currentResults));
        await prefs.setStringList('gmail_scanned_ids', scannedIds.toList());
        
        if (foundNewPhishing) {
          AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
            'gmail_alerts', 
            'Gmail Alerts',
            importance: Importance.max,
            priority: Priority.high,
            color: Color(0xFFE53935), // kPrimary equivalent if kPrimary isn't imported
          );
          
          NotificationDetails notificationDetails = NotificationDetails(
            android: androidDetails,
          );

          await notify.show(
            99,
            '🚨 GMAIL THREAT DETECTED',
            'New phishing emails were found and blocked in your inbox.',
            notificationDetails,
          );
        }
      }
    } catch (_) {}
  }

  static String _extractText(Map<String, dynamic> p) {
    if (p['parts'] != null) {
      for (final part in p['parts'] as List) {
        if (part['mimeType'] == 'text/plain') {
          final d = part['body']?['data'];
          if (d != null) return utf8.decode(base64Url.decode((d as String).replaceAll('-', '+').replaceAll('_', '/')));
        }
      }
    }
    final d = p['body']?['data'];
    if (d != null) return utf8.decode(base64Url.decode((d as String).replaceAll('-', '+').replaceAll('_', '/')));
    return '';
  }

  static String? _findUrl(String text) {
    final exp = RegExp(r'https?://[^\s]+');
    return exp.firstMatch(text)?[0];
  }
}
