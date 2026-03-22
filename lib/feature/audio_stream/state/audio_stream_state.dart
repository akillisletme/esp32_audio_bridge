import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_stream_state.freezed.dart';

/// Ses kaynağı seçeneği.
enum AudioSource {
  /// Android MediaProjection ile tüm sistem sesini yakalar.
  system,

  /// Cihazdan seçilen WAV dosyasını okur ve akıtır.
  file,
}

/// UDP paket boyutu seçenekleri (byte).
///
/// Küçük buffer → düşük gecikme, yüksek paket sayısı
/// Büyük buffer → yüksek verim, daha az paket
enum BufferSize {
  tiny(512),
  small(1024),
  medium(2048),
  large(4096);

  const BufferSize(this.bytes);

  final int bytes;

  @override
  String toString() => '$bytes B';
}

/// Örnekleme frekansı seçenekleri (Hz) — yalnızca sistem sesi modunda geçerli.
/// Dosya modunda WAV header'ından otomatik okunur.
enum SampleRate {
  phone(8000),
  voip(16000),
  cd(44100),
  studio(48000);

  const SampleRate(this.hz);

  final int hz;

  @override
  String toString() =>
      '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)} kHz';
}

@freezed
abstract class AudioStreamState with _$AudioStreamState {
  const factory AudioStreamState({
    // ── Akış durumu ────────────────────────────────────────
    @Default(false) bool isStreaming,
    @Default(false) bool isLoading,

    // ── Kaynak seçimi ──────────────────────────────────────
    /// Sistem sesi mi yoksa seçilen dosya mı akıtılsın.
    @Default(AudioSource.system) AudioSource audioSource,

    /// Seçilen WAV dosyasının tam yolu (dosya modunda).
    String? selectedFilePath,

    /// Kullanıcıya gösterilen dosya adı.
    @Default('') String selectedFileName,

    /// Dosya bitince başa sar.
    @Default(false) bool loopFile,

    // ── Ağ ayarları ────────────────────────────────────────
    /// ESP32 IP adresi. AP modda varsayılan: 192.168.4.1
    @Default('192.168.4.1') String targetIp,

    /// ESP32'nin dinlediği UDP port numarası.
    @Default(4210) int targetPort,

    // ── Ses ayarları (sistem sesi modunda geçerli) ─────────
    /// Her UDP paketinin byte boyutu.
    @Default(BufferSize.small) BufferSize bufferSize,

    /// PCM örnekleme frekansı — sistem sesi modunda.
    @Default(SampleRate.cd) SampleRate sampleRate,

    /// 1 = Mono, 2 = Stereo — sistem sesi modunda.
    @Default(1) int channels,

    /// Her pakete 44 byte WAV header ekle.
    /// ESP32 bu header'ı WAV formatı olarak parse edebilir.
    @Default(false) bool addWavHeader,

    // ── Canlı istatistikler ────────────────────────────────
    @Default(0) int totalBytesSent,
    @Default(0) int totalPackets,

    /// Son 1 saniyedeki paket sayısı.
    @Default(0) int packetsPerSecond,

    /// Son 1 saniyedeki veri hızı (KB/s).
    @Default(0.0) double kbytesPerSecond,

    // ── Log ve hata ────────────────────────────────────────
    @Default([]) List<String> logs,
    String? error,
  }) = _AudioStreamState;
}
