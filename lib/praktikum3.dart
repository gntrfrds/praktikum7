import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Praktikum3Screen extends StatefulWidget {
  const Praktikum3Screen({super.key});

  @override
  State<Praktikum3Screen> createState() => _Praktikum3ScreenState();
}

class _Praktikum3ScreenState extends State<Praktikum3Screen> {
  String sseData = 'Tekan "Start SSE" untuk mendengarkan event';
  http.Client? _client;
  StreamSubscription? _subscription;

  // ==========================================
  // STREAMING HTTP LISTENER (PENGGANTI EVENTSOURCE)
  // ==========================================
  Future<void> listenToEvents() async {
    stopListening();

    setState(() {
      sseData = 'Terhubung ke SSE server, menunggu event...';
    });

    try {
      _client = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse('http://localhost:3000/api/events'),
      );
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      // Membaca aliran data teks per baris sesuai standar SSE
      _subscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data:')) {
          final data = line.substring(5).trim();
          print('SSE: $data');

          if (mounted && data.isNotEmpty && data != '{}') {
            setState(() {
              sseData = 'SSE: $data';
            });
          }
        }
      }, onError: (e) {
        print('SSE Error: $e');
        if (mounted) {
          setState(() {
            sseData = 'SSE Error: $e';
          });
        }
      });
    } catch (e) {
      print('Connection Error: $e');
      if (mounted) {
        setState(() {
          sseData = 'Connection Error: $e';
        });
      }
    }
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _client?.close();
    _client = null;
    setState(() {
      sseData = 'Koneksi SSE dihentikan';
    });
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 3 — Server-Sent Events'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  sseData,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: listenToEvents,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Start SSE'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: stopListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Stop SSE'),
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