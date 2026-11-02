import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

class Praktikum5Screen extends StatefulWidget {
  const Praktikum5Screen({super.key});

  @override
  State<Praktikum5Screen> createState() => _Praktikum5ScreenState();
}

class _Praktikum5ScreenState extends State<Praktikum5Screen> {
  MqttBrowserClient? client;
  bool isConnected = false;
  final String topic = 'kampus/demo/sensor02';
  final TextEditingController _tempController = TextEditingController(text: '28.5');
  final List<String> _logs = [];

  // ==========================================
  // LOGIKA KONEKSI MQTT OVER SECURE WEBSOCKET
  // ==========================================
  Future<void> connect() async {
    disconnect();

    // Generate Client ID unik dengan microsecond & nilai acak agar tidak bertabrakan antar tab
    final uniqueId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
    final clientId = 'flutter_client_$uniqueId';

    // Broker EMQX WSS (Secure WebSocket) sangat stabil untuk browser Chrome
    client = MqttBrowserClient('wss://broker.emqx.io/mqtt', clientId);
    client!.port = 8084;
    client!.keepAlivePeriod = 60;
    client!.websocketProtocols = MqttClientConstants.protocolsSingleDefault;

    client!.onConnected = () {
      if (mounted) {
        setState(() {
          isConnected = true;
          _logs.insert(0, '[Sistem] Terhubung ke broker EMQX');
        });
      }
    };

    client!.onDisconnected = () {
      if (mounted) {
        setState(() {
          isConnected = false;
          _logs.insert(0, '[Sistem] Terputus dari broker MQTT');
        });
      }
    };

    try {
      setState(() {
        _logs.insert(0, '[Sistem] Menghubungkan ke broker EMQX...');
      });

      await client!.connect();

      // Subscribe ke topik sensor
      client!.subscribe(topic, MqttQos.atMostOnce);
      _logs.insert(0, '[Sistem] Berhasil subscribe topik: $topic');

      // Listener data masuk secara real-time
      client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> events) {
        for (final event in events) {
          final publishMessage = event.payload as MqttPublishMessage;
          final payloadText = MqttPublishPayload.bytesToStringAsString(
            publishMessage.payload.message,
          );

          if (mounted) {
            setState(() {
              _logs.insert(0, 'Topik: ${event.topic} -> Pesan: $payloadText');
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isConnected = false;
          _logs.insert(0, '[Error]: Gagal koneksi MQTT ($e)');
        });
      }
      client?.disconnect();
    }
  }

  // ==========================================
  // PUBLISH DATA SENSOR
  // ==========================================
  void publishData() {
    if (client == null || !isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hubungkan ke MQTT terlebih dahulu!')),
      );
      return;
    }

    final val = double.tryParse(_tempController.text) ?? 25.0;
    final builder = MqttClientPayloadBuilder();
    final payloadJson = jsonEncode({
      'temperature': val,
      'timestamp': DateTime.now().toIso8601String(),
    });

    builder.addString(payloadJson);

    client!.publishMessage(
      topic,
      MqttQos.atMostOnce,
      builder.payload!,
    );

    setState(() {
      _logs.insert(0, '[Publish ke $topic]: $payloadJson');
    });
  }

  void disconnect() {
    client?.disconnect();
    client = null;
    if (mounted) {
      setState(() {
        isConnected = false;
      });
    }
  }

  @override
  void dispose() {
    disconnect();
    _tempController.dispose();
    super.dispose();
  }

  // ==========================================
  // ANTARMUKA PENGGUNA (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 5 — MQTT IoT'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Status bar & Tombol Aksi
            Row(
              children: [
                Icon(
                  isConnected ? Icons.check_circle : Icons.cancel,
                  color: isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  isConnected ? 'Status: Terhubung (EMQX)' : 'Status: Terputus',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: isConnected ? null : connect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Connect & Sub'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isConnected ? disconnect : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            const Divider(height: 24),

            // Form Input Nilai Suhu & Tombol Publish
            Card(
              color: Colors.teal.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.teal.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tempController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Nilai Suhu (°C)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: isConnected ? publishData : null,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Publish Sensor'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Log Monitor Pesan
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Monitor Topik: $topic',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                          'Tekan Connect & Sub untuk memantau data sensor.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final log = _logs[index];
                          final isPublish = log.startsWith('[Publish');
                          final isIncoming = log.startsWith('Topik:');

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                color: isIncoming
                                    ? Colors.blue.shade900
                                    : (isPublish ? Colors.teal.shade900 : Colors.black87),
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