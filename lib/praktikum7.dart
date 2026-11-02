import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ==========================================
// STRUKTUR PESAN PROTOBUF (Generated Model)
// ==========================================
class SensorRequest {
  final String deviceId;
  SensorRequest({required this.deviceId});

  Map<String, dynamic> toJson() => {'device_id': deviceId};
}

class SensorReading {
  final String deviceId;
  final double value;
  final int timestamp;

  SensorReading({
    required this.deviceId,
    required this.value,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      deviceId: json['device_id'] ?? '',
      value: (json['value'] as num).toDouble(),
      timestamp: json['timestamp'] is int
          ? json['timestamp']
          : int.tryParse(json['timestamp'].toString()) ?? 0,
    );
  }

  @override
  String toString() =>
      'Device: $deviceId | Nilai: ${value.toStringAsFixed(2)} | Waktu: ${DateTime.fromMillisecondsSinceEpoch(timestamp).toIso8601String()}';
}

// ==========================================
// TAMPILAN PRAKTIKUM 7
// ==========================================
class Praktikum7Screen extends StatefulWidget {
  const Praktikum7Screen({super.key});

  @override
  State<Praktikum7Screen> createState() => _Praktikum7ScreenState();
}

class _Praktikum7ScreenState extends State<Praktikum7Screen> {
  final TextEditingController _deviceController = TextEditingController(text: 'device-esp32-01');
  final List<String> _logs = [];

  bool _isStreaming = false;
  http.Client? _streamClient;
  StreamSubscription? _streamSubscription;

  // 1. UNARY RPC: GetLatest (1 Request -> 1 Response)
  Future<void> _callUnaryGetLatest() async {
    final deviceId = _deviceController.text.trim();
    final request = SensorRequest(deviceId: deviceId);

    setState(() {
      _logs.insert(0, '[Unary Request] Meminta GetLatest() untuk $deviceId...');
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:3000/monitoring.SensorService/GetLatest'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(request.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reading = SensorReading.fromJson(data);
        setState(() {
          _logs.insert(0, '[Unary Response] $reading');
        });
      } else {
        setState(() {
          _logs.insert(0, '[gRPC Error] Status Code: ${response.statusCode}');
        });
      }
    } catch (e) {
      setState(() {
        _logs.insert(0, '[Unary Error] $e');
      });
    }
  }

  // 2. SERVER STREAMING: WatchSensor (1 Request -> Stream Response Berkelanjutan)
  Future<void> _startServerStreaming() async {
    _stopServerStreaming();

    final deviceId = _deviceController.text.trim();
    setState(() {
      _isStreaming = true;
      _logs.insert(0, '[Server Stream] Memulai WatchSensor() untuk $deviceId...');
    });

    try {
      _streamClient = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse('http://localhost:3000/monitoring.SensorService/WatchSensor?device_id=$deviceId'),
      );

      final response = await _streamClient!.send(request);

      _streamSubscription = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('data:')) {
          final jsonStr = line.substring(5).trim();
          if (jsonStr.isNotEmpty) {
            final data = jsonDecode(jsonStr);
            final reading = SensorReading.fromJson(data);

            if (mounted) {
              setState(() {
                _logs.insert(0, '[Stream Inflow] $reading');
              });
            }
          }
        }
      }, onError: (e) {
        if (mounted) {
          setState(() {
            _isStreaming = false;
            _logs.insert(0, '[Stream Error] $e');
          });
        }
      }, onDone: () {
        if (mounted) {
          setState(() {
            _isStreaming = false;
            _logs.insert(0, '[Stream Done] Aliran data selesai.');
          });
        }
      });
    } catch (e) {
      setState(() {
        _isStreaming = false;
        _logs.insert(0, '[Stream Connection Error] $e');
      });
    }
  }

  void _stopServerStreaming() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamClient?.close();
    _streamClient = null;

    if (_isStreaming) {
      setState(() {
        _isStreaming = false;
        _logs.insert(0, '[Server Stream] Dihentikan oleh client.');
      });
    }
  }

  @override
  void dispose() {
    _stopServerStreaming();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 7 — gRPC Streaming'),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Parameter Input Device ID
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _deviceController,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => setState(() => _logs.clear()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade400,
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Clear Log'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tombol Uji Unary & Server Streaming
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _callUnaryGetLatest,
                  icon: const Icon(Icons.arrow_upward),
                  label: const Text('Unary: GetLatest'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isStreaming ? _stopServerStreaming : _startServerStreaming,
                  icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                  label: Text(_isStreaming ? 'Stop Streaming' : 'Server Stream: WatchSensor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStreaming ? Colors.red : Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // Monitor Log RPC
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Log Transaksi gRPC (Protobuf):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Tekan "Unary: GetLatest" atau "Server Stream" untuk menguji.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final isUnary = log.startsWith('[Unary Response]');
                          final isStream = log.startsWith('[Stream Inflow]');
                          final isError = log.contains('Error');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: isError
                                    ? Colors.red.shade900
                                    : (isUnary
                                        ? Colors.purple.shade900
                                        : (isStream ? Colors.indigo.shade900 : Colors.black87)),
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