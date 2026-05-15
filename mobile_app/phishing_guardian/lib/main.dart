import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:another_telephony/telephony.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';

import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/agreement_screen.dart';
import 'screens/main_shell.dart';

final FlutterLocalNotificationsPlugin agilNotifications =
    FlutterLocalNotificationsPlugin();

const String kBaseUrl = 'http://192.168.254.118:5000';

const kBg        = Color(0xFF0F0F1A);
const kSurface   = Color(0xFF1A1A2E);
const kCard      = Color(0xFF16213E);
const kPrimary   = Color(0xFFE53935);
const kSecondary = Color(0xFFFF6B6B);
const kSuccess   = Color(0xFF4CAF50);
const kMuted     = Color(0xFF6B6B8A);
const kTextSub   = Color(0xFF9E9E9E);

@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  final RegExp exp = RegExp(r'(?:(?:https?|ftp):\/\/)?[\w\/\-?=%.]+\.[\w\/\-?=%.]+');
  final String? foundUrl = exp.firstMatch(message.body ?? "")?[0];
  if (foundUrl == null) return;

  try {
    final res = await http.post(
      Uri.parse('$kBaseUrl/scan'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": foundUrl}),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['status'] != "SECURE") {
        final isBlacklisted = data['phishtank_match'] == true;
        final title = isBlacklisted
            ? 'BLACKLISTED PHISHING LINK'
            : 'PHISHING ATTACK DETECTED';
        final body = isBlacklisted
            ? 'This link is in the PhishTank global database. DO NOT CLICK.\nReason: ${data['explanation']}'
            : 'Reason: ${data['explanation']}';

        // Create notification details first
        AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'scam_alerts', 
          'Scam Alerts',
          importance: Importance.max,
          priority: Priority.high,
          color: kPrimary,
          styleInformation: BigTextStyleInformation(body),
        );
        
        await StorageService.saveScan(
          text: message.body ?? '',
          isPhishing: true,
          explanation: data['explanation'] ?? '',
          source: 'SMS',
          provider: data['provider'] ?? 'Unknown',
          phishtankMatch: isBlacklisted,
          mlMatch: data['ml_match'] == true,
        );
        
        NotificationDetails notificationDetails = NotificationDetails(
          android: androidDetails,
        );
        
        await agilNotifications.show(
          0,
          title,
          body,
          notificationDetails,
        );
      }
    }
  } catch (e) {
    // Error handled silently
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await agilNotifications.initialize(initializationSettings);

  // Request notification permission for Android 13+
  await agilNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // Listen for incoming SMS
  final Telephony telephony = Telephony.instance;
  telephony.listenIncomingSms(
    onNewMessage: (SmsMessage message) {
      // Foreground
    },
    onBackgroundMessage: backgroundMessageHandler,
  );

  runApp(const PhishingGuardianApp());
}

class PhishingGuardianApp extends StatelessWidget {
  const PhishingGuardianApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agil',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kPrimary,
          secondary: kSecondary,
          surface: kSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          color: kSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: kSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: kMuted),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: kBg,
          selectedItemColor: kPrimary,
          unselectedItemColor: kMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const SplashScreen(),
    );
  }
}