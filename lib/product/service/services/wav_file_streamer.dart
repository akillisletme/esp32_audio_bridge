import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// WAV dosyasını parse ederek PCM16 chunk'larını zamanlı akış olarak sunar.
///
/// Tamamen Dart/Flutter tarafında çalışır — native kod gerekmez.
///
/// Desteklenen format: PCM WAV (AudioFormat = 1), 16-bit.
/// Desteklenmeyen formatlar hata fırlatır.
///
/// Kullanım:
/// ```dart
/// final sub = WavFileStreamer.instance
///     .stream(filePath: '/sdcard/ses.wav', chunkSize: 1024)
///     .listen(onData, onDone: onDone, onError: onError);
/// ```
final class WavFileStreamer {
  WavFileStreamer._();

  static final WavFileStreamer instance = WavFileStreamer._();

  /// WAV dosyasından PCM16 verisi akıtır.
  ///
  /// - [filePath]  : Dosyanın tam yolu
  /// - [chunkSize] : Her event'te kaç byte gönderileceği
  /// - [loop]      : Dosya bitince başa sar (varsayılan false)
  ///
  /// Chunk'lar arasında bekleme süresi WAV header'ındaki `byteRate`'den
  /// hesaplanır; bu sayede gerçek zamanlı oynatma hızında veri akar.
  ///
  /// Stream tamamlanınca (dosya bitti ve loop=false) kapanır.
  Stream<Uint8List> stream({
    required String filePath,
    required int    chunkSize,
    bool loop = false,
  }) async* {
    final header = await _parseWavHeader(filePath);
    final delayUs = (chunkSize * 1000000 / header.byteRate).round();
    final delay   = Duration(microseconds: delayUs);

    // RandomAccessFile: büyük dosyalarda RAM'e tamamen yüklemez
    final raf = await File(filePath).open();
    try {
      do {
        await raf.setPosition(header.dataOffset);
        var remaining = header.dataSize;

        while (remaining > 0) {
          final toRead = min(chunkSize, remaining);
          final buf    = Uint8List(toRead);
          final read   = await raf.readInto(buf);
          if (read <= 0) break;
          yield read == toRead ? buf : Uint8List.sublistView(buf, 0, read);
          remaining -= read;
          if (remaining > 0) await Future<void>.delayed(delay);
        }
      } while (loop);
    } finally {
      await raf.close();
    }
  }

  /// WAV header'ını ayrıştırır ve ses özelliklerini döner.
  Future<_WavHeader> _parseWavHeader(String filePath) async {
    final raf = await File(filePath).open();
    try {
      // İlk 12 byte: RIFF / chunkSize / WAVE
      final riffBuf = Uint8List(12);
      await raf.readInto(riffBuf);
      final riff = String.fromCharCodes(riffBuf.sublist(0, 4));
      final wave = String.fromCharCodes(riffBuf.sublist(8, 12));
      if (riff != 'RIFF' || wave != 'WAVE') {
        throw const FormatException('Geçersiz WAV dosyası (RIFF/WAVE başlığı yok)');
      }

      // Alt chunk'ları tara: "fmt " ve "data" chunk'larını bul
      int?   audioFormat;
      int?   numChannels;
      int?   sampleRate;
      int?   byteRate;
      int?   dataOffset;
      int?   dataSize;

      while (true) {
        final idBuf = Uint8List(8);
        final read  = await raf.readInto(idBuf);
        if (read < 8) break;

        final id        = String.fromCharCodes(idBuf.sublist(0, 4));
        final chunkSize = ByteData.sublistView(idBuf, 4, 8)
            .getUint32(0, Endian.little);

        if (id == 'fmt ') {
          final fmtBuf = Uint8List(chunkSize);
          await raf.readInto(fmtBuf);
          final bd   = ByteData.sublistView(fmtBuf);
          audioFormat = bd.getUint16(0, Endian.little);
          numChannels = bd.getUint16(2, Endian.little);
          sampleRate  = bd.getUint32(4, Endian.little);
          byteRate    = bd.getUint32(8, Endian.little);
          // bitsPerSample = bd.getUint16(14, Endian.little);
        } else if (id == 'data') {
          dataOffset = await raf.position();
          dataSize   = chunkSize;
          break; // data başladı, ara
        } else {
          // Bilinmeyen chunk — atla
          await raf.setPosition((await raf.position()) + chunkSize);
        }
      }

      if (audioFormat == null || numChannels == null ||
          sampleRate == null || byteRate == null ||
          dataOffset == null || dataSize == null) {
        throw const FormatException('WAV dosyası eksik veya bozuk');
      }
      if (audioFormat != 1) {
        throw FormatException(
          'Sadece PCM WAV destekleniyor (format=$audioFormat). '
          'MP3/AAC gibi sıkıştırılmış dosyalar desteklenmiyor.',
        );
      }

      return _WavHeader(
        numChannels: numChannels,
        sampleRate:  sampleRate,
        byteRate:    byteRate,
        dataOffset:  dataOffset,
        dataSize:    dataSize,
      );
    } finally {
      await raf.close();
    }
  }
}

/// WAV dosyasından çıkarılan ses meta verisi.
final class _WavHeader {
  const _WavHeader({
    required this.numChannels,
    required this.sampleRate,
    required this.byteRate,
    required this.dataOffset,
    required this.dataSize,
  });

  final int numChannels;
  final int sampleRate;

  /// Saniyede byte sayısı = sampleRate × channels × (bitsPerSample/8).
  /// Chunk'lar arası gecikmeyi hesaplamak için kullanılır.
  final int byteRate;

  /// Dosya içinde PCM verinin başladığı offset (byte).
  final int dataOffset;

  /// PCM verisinin toplam boyutu (byte).
  final int dataSize;
}

/// Dosya seçimi için meta veri taşıyıcısı.
final class SelectedAudioFile {
  const SelectedAudioFile({
    required this.path,
    required this.name,
  });

  final String path;
  final String name;
}
