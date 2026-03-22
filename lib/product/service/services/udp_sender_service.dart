import 'dart:io';
import 'dart:typed_data';

/// UDP üzerinden ESP32'ye ses verisi gönderir.
///
/// Kullanım:
/// ```dart
/// await udp.initialize(ip: '192.168.4.1', port: 4210);
/// udp.send(audioChunk);  // her audio callback'te
/// await udp.close();
/// ```
///
/// İstatistikler [totalBytesSent] ve [totalPackets] ile izlenebilir.
final class UdpSenderService {
  UdpSenderService._();

  static final UdpSenderService instance = UdpSenderService._();

  RawDatagramSocket? _socket;
  InternetAddress? _address;
  int _port = 0;

  int _totalBytesSent = 0;
  int _totalPackets   = 0;

  /// Gönderilen toplam byte sayısı (o anki oturum için).
  int get totalBytesSent => _totalBytesSent;

  /// Gönderilen toplam UDP paket sayısı.
  int get totalPackets => _totalPackets;

  /// UDP soketi açar ve hedef adresi çözümler.
  ///
  /// Önceki oturum açıksa önce kapatır.
  Future<void> initialize({required String ip, required int port}) async {
    await close();
    _address = InternetAddress(ip);
    _port    = port;
    // 0 → işletim sistemi rastgele bir ephemeral port atar
    _socket  = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _totalBytesSent = 0;
    _totalPackets   = 0;
  }

  /// [data]'yı UDP datagramı olarak ESP32'ye gönderir.
  ///
  /// Başarılıysa `true`, soket kapalıysa veya hata varsa `false` döner.
  ///
  /// UDP'de paket kaybı normaldir; kritik veri için TCP kullan.
  bool send(Uint8List data) {
    final sock = _socket;
    final addr = _address;
    if (sock == null || addr == null) return false;

    try {
      final sent = sock.send(data, addr, _port);
      if (sent > 0) {
        _totalBytesSent += sent;
        _totalPackets++;
        return true;
      }
      return false;
    } on SocketException {
      return false;
    }
  }

  /// Soketi kapatır ve kaynakları serbest bırakır.
  Future<void> close() async {
    _socket?.close();
    _socket  = null;
    _address = null;
  }

  /// İstatistikleri sıfırlar (soketi kapatmaz).
  void resetStats() {
    _totalBytesSent = 0;
    _totalPackets   = 0;
  }
}
