import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

// Background handler wajib berada di tingkat atas (di luar kelas)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[FCM Background] Judul: ${message.notification?.title}');
  print('[FCM Background] Body: ${message.notification?.body}');
  print('[FCM Background] Data: ${message.data}');
}

class Praktikum8Screen extends StatefulWidget {
  const Praktikum8Screen({super.key});

  @override
  State<Praktikum8Screen> createState() => _Praktikum8ScreenState();
}

class _Praktikum8ScreenState extends State<Praktikum8Screen> {
  String? _fcmToken;
  String _statusText = 'Menginisialisasi FCM...';
  final List<String> _notificationsLog = [];

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    try {
      // 1. Inisialisasi Firebase menggunakan file firebase_options.dart
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final messaging = FirebaseMessaging.instance;

      // 2. Minta izin notifikasi (Notification Permission)
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        setState(() => _statusText = 'Izin notifikasi diberikan.');
      } else {
        setState(() => _statusText = 'Izin notifikasi ditolak/dibatasi.');
      }

      // 3. Ambil Registration Token FCM
      final token = await messaging.getToken(
      vapidKey: 'BO_Q9OYYxJ61W7VKjiE-0IFqo4aFKuS9LfgkYCeNwmHzTU2U5-5u_XReHub7i3GKBl8tnIdLL2ClPVwWxFu6vrE',
      );


      setState(() {
        _fcmToken = token;
        _statusText = 'Siap menerima push notification.';
      });

      // 4. Tangani pesan ketika aplikasi aktif di layar (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? 'Tanpa Judul';
        final body = message.notification?.body ?? 'Tanpa Pesan';
        final dataStr = message.data.isNotEmpty ? ' | Data: ${message.data}' : '';

        if (mounted) {
          setState(() {
            _notificationsLog.insert(
              0,
              '[Foreground] $title: $body$dataStr',
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title: $body'),
              backgroundColor: Colors.amber.shade900,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });

      // 5. Tangani ketika notifikasi di tray/background diklik pengguna
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (mounted) {
          setState(() {
            _notificationsLog.insert(
              0,
              '[Dibuka dari Tray] ${message.notification?.title}: ${message.notification?.body}',
            );
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _statusText = 'Error inisialisasi FCM: $e');
      }
    }
  }

  void _copyToken() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('FCM Token berhasil disalin!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 8 — FCM Push Notification'),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Status: $_statusText',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Token box
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FCM Registration Token:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _fcmToken ?? 'Mengambil token...',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: _fcmToken == null ? null : _copyToken,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin Token'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 28),

            // Log Riwayat Notifikasi
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Riwayat Notifikasi Diterima:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _notificationsLog.clear()),
                  child: const Text('Hapus Log'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _notificationsLog.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada notifikasi.\nKirim pesan uji coba dari Firebase Console.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _notificationsLog.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              _notificationsLog[index],
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}