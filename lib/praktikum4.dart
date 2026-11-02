import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Praktikum4Screen extends StatefulWidget {
  const Praktikum4Screen({super.key});

  @override
  State<Praktikum4Screen> createState() => _Praktikum4ScreenState();
}

class _Praktikum4ScreenState extends State<Praktikum4Screen> {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  final TextEditingController _messageController = TextEditingController();
  final List<String> _logs = [];

  void _connect() {
    if (_isConnected) return;

    try {
      final uri = Uri.parse('ws://localhost:3000');
      _channel = WebSocketChannel.connect(uri);

      // Tunggu hingga channel benar-benar siap sebelum mengaktifkan UI
      _channel!.ready.then((_) {
        if (mounted) {
          setState(() {
            _isConnected = true;
            _logs.insert(0, '[Sistem] Terhubung ke ws://localhost:3000');
          });
        }
      }).catchError((err) {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _logs.insert(0, '[Error]: Gagal inisiasi ($err)');
          });
        }
      });

      _channel!.stream.listen(
        (message) {
          print('Dari server: $message');
          String teksPesan = message.toString();

          try {
            final parsed = jsonDecode(message.toString());
            if (parsed is Map && parsed.containsKey('message')) {
              teksPesan = parsed['message'];
            }
          } catch (_) {}

          if (mounted) {
            setState(() {
              _logs.insert(0, 'Dari server: $teksPesan');
            });
          }
        },
        onError: (err) {
          print('WebSocket error: $err');
          if (mounted) {
            setState(() {
              _isConnected = false;
              _logs.insert(0, '[Error]: $err');
            });
          }
        },
        onDone: () {
          print('Koneksi ditutup');
          if (mounted) {
            setState(() {
              _isConnected = false;
              _logs.insert(0, '[Sistem] Koneksi WebSocket ditutup');
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _logs.insert(0, '[Error]: $e');
        });
      }
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_channel != null && _isConnected) {
      final payload = jsonEncode({
        'message': text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      _channel!.sink.add(payload);
      _messageController.clear();
    }
  }

  void _disconnect() {
    _channel?.sink.close();
    _channel = null;
    if (mounted) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 4 — WebSocket'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.cancel,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Status: Terhubung' : 'Status: Terputus',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isConnected ? null : _connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Connect'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isConnected ? _disconnect : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _isConnected,
                    decoration: InputDecoration(
                      labelText: _isConnected
                          ? 'Ketik pesan...'
                          : 'Hubungkan koneksi untuk mengetik',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _sendMessage : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Kirim'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Log Pesan Masuk & Keluar:',
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
                          'Tekan Connect untuk memulai.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final isServer = log.startsWith('Dari server:');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: isServer
                                    ? Colors.blue.shade900
                                    : Colors.black87,
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