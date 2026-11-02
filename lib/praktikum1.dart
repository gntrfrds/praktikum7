import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


const baseUrl = 'http://localhost:3000';

Future<Map<String, dynamic>> getData() async {
    final response = await http.get(Uri.parse('$baseUrl/api/data'));

  if (response.statusCode != 200) {
    throw Exception('Gagal mengambil data');
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> sendMessage(String message) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/message'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'message': message}),
  );

  if (response.statusCode != 200) {
    throw Exception('Gagal mengirim pesan');
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}

class Praktikum1Screen extends StatefulWidget {
  const Praktikum1Screen({super.key});

  @override
  State<Praktikum1Screen> createState() => _Praktikum1ScreenState();
}

class _Praktikum1ScreenState extends State<Praktikum1Screen> {
  String textData = 'Tekan "GET Data" untuk memulai';
  String textPesan = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 1 - REST API'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              textData,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final data = await getData();
                  setState(() {
                    textData = 'Counter: ${data['counter']}\n'
                        'Value: ${data['value']}\n'
                        'Waktu: ${data['timestamp']}';
                  });
                } catch (e) {
                  setState(() {
                    textData = 'Error: $e';
                  });
                }
              },
              child: const Text('GET Data'),
            ),
            const SizedBox(height: 40),
            Text(
              textPesan,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                try {
                  final response = await sendMessage('Halo dari Praktikum 1!');
                  setState(() {
                    textPesan = 'Pesan terkirim!\nBalasan server: ${response['message']}';
                  });
                } catch (e) {
                  setState(() {
                    textPesan = 'Error: $e';
                  });
                }
              },
              child: const Text('POST Pesan'),
            ),
          ],
        ),
      ),
    );
  }
}