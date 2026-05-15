import 'package:flutter/material.dart';
import 'package:another_telephony/telephony.dart';
import 'dart:async';
import 'dart:io';
import '../main.dart';
import '../widgets/about_app_dialog.dart';
import 'home_screen.dart';
import 'chat_screen.dart';
import 'news_screen.dart';
import 'history_screen.dart';
import 'library_screen.dart';
import 'vault_screen.dart';
import '../services/gmail_sync_service.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 2;
  Timer? _connTimer;
  bool _isOfflineDialogShowing = false;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      NewsScreen(),
      LibraryScreen(),
      HomeScreen(key: HomeScreen.scanKey),
      VaultScreen(),
      HistoryScreen(),
    ];
    Telephony.instance.listenIncomingSms(
      onNewMessage: (msg) => debugPrint("Foreground SMS: ${msg.body}"),
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
    // Auto-sync Gmail for threats on startup
    GmailSyncService.syncAndNotify(agilNotifications);

    _connTimer = Timer.periodic(const Duration(seconds: 3), (_) => _checkConnectivity());
  }

  @override
  void dispose() {
    _connTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
      }
    } catch (_) {
      hasInternet = false;
    }

    if (!mounted) return;

    if (!hasInternet && !_isOfflineDialogShowing) {
      _isOfflineDialogShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => WillPopScope(
          onWillPop: () async => false,
          child: const AlertDialog(
            backgroundColor: kSurface,
            title: Row(children: [
              Icon(Icons.wifi_off_rounded, color: kPrimary),
              SizedBox(width: 10),
              Text('No Connection', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
            content: Text('Internet was gone. Reconnect to continue using the app.', style: TextStyle(color: kTextSub, fontSize: 14)),
          ),
        ),
      );
    } else if (hasInternet && _isOfflineDialogShowing) {
      _isOfflineDialogShowing = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) {
            if (i == 2 && _index == 2) {
              HomeScreen.scanKey.currentState?.scanFromCamera();
            } else {
              setState(() => _index = i);
            }
          },
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.newspaper_rounded), label: 'News'),
            const BottomNavigationBarItem(icon: Icon(Icons.library_books_rounded), label: 'Library'),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -24,
                    left: -6,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))
                        ]
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset('assets/images/app_iconv2.png', width: 30, height: 30, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40, height: 24),
                ],
              ),
              label: 'Scan',
            ),
            const BottomNavigationBarItem(icon: Icon(Icons.security_rounded), label: 'Vault'),
            const BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'History'),
          ],
        ),
      ),
      floatingActionButton: Opacity(
        opacity: 0.7, // Slightly reduced opacity as requested
        child: FloatingActionButton(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const ChatScreen(),
          ),
          backgroundColor: kPrimary,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset('assets/images/chatbot.jpg', width: 32, height: 32),
          ),
        ),
      ),
    );
  }
}
