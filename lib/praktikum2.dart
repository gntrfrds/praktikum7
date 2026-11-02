import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Gunakan localhost untuk browser Chrome
const baseUrl = 'http://localhost:3000';

class Praktikum2Screen extends StatefulWidget {
  const Praktikum2Screen({super.key});

  @override
  State<Praktikum2Screen> createState() => _Praktikum2ScreenState();
}

class _Praktikum2ScreenState extends State<Praktikum2Screen> {
  String displayData = 'Pilih metode untuk mulai menguji';
  String currentMode = 'Belum berjalan';

  // Fungsi dasar mengambil data lewat HTTP GET
  Future<Map<String, dynamic>> getData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/data'));

    if (response.statusCode != 200) {
      throw Exception('Gagal mengambil data');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ==========================================
  // 1. REGULAR POLLING (Request berkala)
  // ==========================================
  Timer? pollingTimer;

  void startPolling() {
    stopAll();
    setState(() {
      currentMode = 'Regular Polling (Setiap 2 Detik)';
      displayData = 'Memulai polling...';
    });

    pollingTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) async {
        try {
          final data = await getData();
          print('Data terbaru (Polling): $data');
          if (mounted) {
            setState(() {
              displayData = 'Counter: ${data['counter']}\n'
                  'Value: ${data['value']}\n'
                  'Waktu: ${data['timestamp']}';
            });
          }
        } catch (e) {
          print('Polling error: $e');
        }
      },
    );
  }

  // ==========================================
  // 2. LONG POLLING (Server menahan request)
  // ==========================================
  bool isLongPollingActive = false;
  int lastCounter = -1;

  Future<void> startLongPolling() async {
    stopAll();
    isLongPollingActive = true;
    setState(() {
      currentMode = 'Long Polling (Server-Held)';
      displayData = 'Menghubungkan ke server...';
    });

    while (isLongPollingActive) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/api/long-poll?lastCounter=$lastCounter'),
        );

        if (!isLongPollingActive) break;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          lastCounter = data['counter'] ?? lastCounter;

          if (mounted) {
            setState(() {
              displayData = 'Counter: ${data['counter']}\n'
                  'Value: ${data['value']}\n'
                  'Waktu: ${data['timestamp']}';
            });
          }
        } else if (response.statusCode == 204) {
          print('Long poll timeout, menyambung ulang...');
        }
      } catch (e) {
        print('Long poll error: $e');
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  // Menghentikan semua proses
  void stopAll() {
    pollingTimer?.cancel();
    pollingTimer = null;
    isLongPollingActive = false;
    setState(() {
      currentMode = 'Dihentikan';
    });
  }

  @override
  void dispose() {
    stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 2 — Polling & Long Polling'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Mode Aktif: $currentMode',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  displayData,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: startPolling,
                    child: const Text('Start Regular Polling'),
                  ),
                  ElevatedButton(
                    onPressed: startLongPolling,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start Long Polling'),
                  ),
                  ElevatedButton(
                    onPressed: stopAll,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}