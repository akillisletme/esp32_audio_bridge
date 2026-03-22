import 'package:flutter/services.dart';

/// Android taraflı ses yakalama servisine platform channel köprüsü.
///
/// MethodChannel: start / stop komutları
/// EventChannel : PCM16 byte chunk'larının akışı
///
/// Kanal adları MainActivity.kt'deki sabitlerle eşleşmeli.
final class AudioCaptureChannel {
  AudioCaptureChannel._();

  static final AudioCaptureChannel instance = AudioCaptureChannel._();

  static const _method = MethodChannel(
    'com.cleanstart.akillisletme/audio_capture',
  );

  static const _event = EventChannel(
    'com.cleanstart.akillisletme/audio_stream',
  );

  /// Android'den gelen ham PCM16 ses byte'larının akışı.
  ///
  /// Her event bir bufferSize büyüklüğündeki chunk'tır.
  /// Akışı dinlemek için önce [startCapture] çağrılmalıdır.
  Stream<Uint8List> get audioStream => _event
      .receiveBroadcastStream()
      .map((event) => Uint8List.fromList((event as List).cast<int>()));

  /// Sistem sesini yakalamayı başlatır.
  ///
  /// - [sampleRate]: Örnekleme hızı (Hz), örn. 44100
  /// - [channels]: Kanal sayısı — 1=mono, 2=stereo
  /// - [bufferSize]: Her chunk'ın byte boyutu, örn. 1024
  ///
  /// Android ilk çağrıda MediaProjection izin dialogunu açar.
  Future<void> startCapture({
    required int sampleRate,
    required int channels,
    required int bufferSize,
  }) async {
    await _method.invokeMethod<void>('startCapture', {
      'sampleRate': sampleRate,
      'channels': channels,
      'bufferSize': bufferSize,
    });
  }

  /// Ses yakalamayı durdurur ve Android kaynaklarını serbest bırakır.
  Future<void> stopCapture() async {
    await _method.invokeMethod<void>('stopCapture');
  }
}
