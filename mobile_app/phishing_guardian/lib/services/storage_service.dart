import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanRecord {
  final String text;
  final bool isPhishing;
  final String explanation;
  final DateTime timestamp;
  final String source;
  final String provider;
  final bool phishtankMatch;
  final bool mlMatch;

  ScanRecord({
    required this.text,
    required this.isPhishing,
    required this.explanation,
    required this.timestamp,
    required this.source,
    required this.provider,
    required this.phishtankMatch,
    required this.mlMatch,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isPhishing': isPhishing,
        'explanation': explanation,
        'timestamp': timestamp.toIso8601String(),
        'source': source,
        'provider': provider,
        'phishtankMatch': phishtankMatch,
        'mlMatch': mlMatch,
      };

  factory ScanRecord.fromJson(Map<String, dynamic> json) => ScanRecord(
        text: json['text'] ?? '',
        isPhishing: json['isPhishing'] ?? false,
        explanation: json['explanation'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        source: json['source'] ?? 'Manual',
        provider: json['provider'] ?? 'Unknown',
        phishtankMatch: json['phishtankMatch'] ?? false,
        mlMatch: json['mlMatch'] ?? false,
      );
}

class StorageService {
  static const _historyKey = 'scan_history';
  static const _agreedKey = 'user_agreed';

  static Future<bool> hasUserAgreed() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_agreedKey) ?? false;
  }

  static Future<void> setUserAgreed() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_agreedKey, true);
  }

  static Future<void> saveScan({
    required String text,
    required bool isPhishing,
    required String explanation,
    required String source,
    required String provider,
    required bool phishtankMatch,
    required bool mlMatch,
  }) async {
    final records = await getRecords();
    records.insert(
      0,
      ScanRecord(
        text: text,
        isPhishing: isPhishing,
        explanation: explanation,
        timestamp: DateTime.now(),
        source: source,
        provider: provider,
        phishtankMatch: phishtankMatch,
        mlMatch: mlMatch,
      ),
    );
    if (records.length > 100) records.removeRange(100, records.length);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
      _historyKey,
      records.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  static Future<List<ScanRecord>> getRecords() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_historyKey) ?? [];
    return list.map((j) => ScanRecord.fromJson(jsonDecode(j))).toList();
  }

  static Future<void> deleteRecord(int index) async {
    final records = await getRecords();
    if (index >= 0 && index < records.length) {
      records.removeAt(index);
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
        _historyKey,
        records.map((r) => jsonEncode(r.toJson())).toList(),
      );
    }
  }

  static Future<void> clearHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_historyKey);
  }

  static Future<Map<String, int>> getStats() async {
    final records = await getRecords();
    final threats = records.where((r) => r.isPhishing).length;
    return {
      'total': records.length,
      'threats': threats,
      'safe': records.length - threats,
    };
  }

  static Future<List<double>> getWeeklyActivity() async {
    final records = await getRecords();
    final now = DateTime.now();
    List<int> counts = List.filled(7, 0);

    for (var r in records) {
      if (r.isPhishing) {
        final diff = now.difference(r.timestamp).inDays;
        if (diff >= 0 && diff < 7) {
          counts[6 - diff]++;
        }
      }
    }

    int maxCount = counts.reduce((a, b) => a > b ? a : b);
    if (maxCount == 0) return List.filled(7, 0.0);

    return counts.map((c) => c / maxCount).toList();
  }

  static List<String> getLast7DaysLabels() {
    final now = DateTime.now();
    final labels = <String>[];
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      labels.add(_dayAbbr(d.weekday));
    }
    return labels;
  }
  
  static String _dayAbbr(int weekday) {
    switch (weekday) {
      case 1: return 'M';
      case 2: return 'T';
      case 3: return 'W';
      case 4: return 'T';
      case 5: return 'F';
      case 6: return 'S';
      case 7: return 'S';
      default: return '';
    }
  }

  // ── Chat History Methods ──
  static const _chatHistoryKey = 'chat_history_v1';

  static Future<void> saveChatHistory(List<Map<String, String>> history) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_chatHistoryKey, jsonEncode(history));
  }

  static Future<List<Map<String, String>>> getChatHistory() async {
    final p = await SharedPreferences.getInstance();
    final data = p.getString(_chatHistoryKey);
    if (data == null) return [];
    try {
      final List decoded = jsonDecode(data);
      return decoded.map((e) => Map<String, String>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearChatHistory() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_chatHistoryKey);
  }
}
