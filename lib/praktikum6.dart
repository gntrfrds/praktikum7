import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Praktikum6Screen extends StatefulWidget {
  const Praktikum6Screen({super.key});

  @override
  State<Praktikum6Screen> createState() => _Praktikum6ScreenState();
}

class _Praktikum6ScreenState extends State<Praktikum6Screen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  WebSocketChannel? _signalingChannel;

  bool _isCameraReady = false;
  bool _isConnectedToSignaling = false;
  String _statusText = 'Inisialisasi renderer...';

  // Konfigurasi STUN server publik Google
  final Map<String, dynamic> _iceConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _connectSignaling();
  }

  // ==========================================
  // 1. KONEKSI KE SIGNALING SERVER
  // ==========================================
  void _connectSignaling() {
    try {
      _signalingChannel = WebSocketChannel.connect(Uri.parse('ws://localhost:3000'));
      _signalingChannel!.ready.then((_) {
        if (mounted) {
          setState(() {
            _isConnectedToSignaling = true;
            _statusText = 'Signaling terhubung. Buka kamera lalu lakukan panggilan.';
          });
        }
      });

      _signalingChannel!.stream.listen((message) async {
        final data = jsonDecode(message.toString()) as Map<String, dynamic>;
        final type = data['type'];

        if (type == 'offer') {
          // Menerima SDP Offer dari Flutter A
          await _handleOffer(data['sdp']);
        } else if (type == 'answer') {
          // Menerima SDP Answer dari Flutter B
          await _handleAnswer(data['sdp']);
        } else if (type == 'candidate') {
          // Menerima ICE Candidate
          await _handleRemoteCandidate(data['candidate']);
        } else if (type == 'hangup') {
          _resetCallState();
        }
      }, onError: (e) {
        if (mounted) setState(() => _statusText = 'Signaling Error: $e');
      });
    } catch (e) {
      if (mounted) setState(() => _statusText = 'Gagal konek signaling: $e');
    }
  }

  void _sendSignaling(Map<String, dynamic> data) {
    _signalingChannel?.sink.add(jsonEncode(data));
  }

  // ==========================================
  // 2. AKSES MEDIA LOKAL (KAMERA & MIKROFON)
  // ==========================================
  Future<void> _openCamera() async {
    try {
      final mediaConstraints = <String, dynamic>{
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;

      setState(() {
        _isCameraReady = true;
        _statusText = 'Kamera & Mikrofon lokal aktif.';
      });
    } catch (e) {
      setState(() => _statusText = 'Gagal mengakses kamera/mikrofon: $e');
    }
  }

  // ==========================================
  // 3. PEMBUATAN RTCPeerConnection & ICE
  // ==========================================
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceConfiguration);

    // Kirim ICE candidate yang ditemukan ke peer melalui signaling
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _sendSignaling({
        'type': 'candidate',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    // Sambungkan track video & audio yang diterima dari lawan bicara (remote)
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
          _statusText = 'Panggilan terhubung (Media P2P Mengalir)!';
        });
      }
    };

    // Tambahkan track media lokal ke koneksi
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }
  }

  // ==========================================
  // 4. ROLE FLUTTER A: BUAT OFFER
  // ==========================================
  Future<void> _makeCall() async {
    if (!_isCameraReady) {
      await _openCamera();
    }

    await _createPeerConnection();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    _sendSignaling({
      'type': 'offer',
      'sdp': offer.sdp,
    });

    setState(() => _statusText = 'SDP Offer terkirim. Menunggu Answer...');
  }

  // ==========================================
  // 5. ROLE FLUTTER B: PROSES OFFER & JAWAB ANSWER
  // ==========================================
  Future<void> _handleOffer(String sdp) async {
    if (!_isCameraReady) {
      await _openCamera();
    }

    await _createPeerConnection();

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    _sendSignaling({
      'type': 'answer',
      'sdp': answer.sdp,
    });

    setState(() => _statusText = 'Offer diterima. SDP Answer dikirimkan balik.');
  }

  Future<void> _handleAnswer(String sdp) async {
    await _peerConnection?.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
  }

  Future<void> _handleRemoteCandidate(Map<String, dynamic> candidateData) async {
    final candidate = RTCIceCandidate(
      candidateData['candidate'],
      candidateData['sdpMid'],
      candidateData['sdpMLineIndex'],
    );
    await _peerConnection?.addCandidate(candidate);
  }

  // ==========================================
  // 6. PUTUS PANGGILAN
  // ==========================================
  void _hangUp() {
    _sendSignaling({'type': 'hangup'});
    _resetCallState();
  }

  void _resetCallState() {
    _peerConnection?.close();
    _peerConnection = null;
    _remoteRenderer.srcObject = null;
    if (mounted) {
      setState(() => _statusText = 'Panggilan dihentikan.');
    }
  }

  @override
  void dispose() {
    _hangUp();
    _localStream?.dispose();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signalingChannel?.sink.close();
    super.dispose();
  }

  // ==========================================
  // ANTARMUKA TAMPILAN (UI)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Praktikum 6 — WebRTC P2P'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Banner Status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: _isConnectedToSignaling ? Colors.green.shade100 : Colors.red.shade100,
            child: Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isConnectedToSignaling ? Colors.green.shade900 : Colors.red.shade900,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Tampilan Video Lokal dan Video Remote
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  // Video Lokal
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            RTCVideoView(_localRenderer, mirror: true),
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: Chip(
                                label: Text('Video Lokal', style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Video Remote (Lawan Bicara)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            RTCVideoView(_remoteRenderer),
                            const Positioned(
                              top: 8,
                              left: 8,
                              child: Chip(
                                label: Text('Video Remote', style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bar Tombol Kontrol
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _openCamera,
                  icon: const Icon(Icons.videocam),
                  label: const Text('Buka Kamera'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: _makeCall,
                  icon: const Icon(Icons.call),
                  label: const Text('Panggil (Offer)'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: _hangUp,
                  icon: const Icon(Icons.call_end),
                  label: const Text('Tutup Panggilan'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}