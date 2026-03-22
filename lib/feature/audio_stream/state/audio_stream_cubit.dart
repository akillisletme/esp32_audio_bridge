import 'dart:async';
import 'dart:typed_data';

import 'package:akillisletme/feature/audio_stream/state/audio_stream_state.dart';
import 'package:akillisletme/product/init/language/locale_keys.g.dart';
import 'package:akillisletme/product/service/services/audio_capture_channel.dart';
import 'package:akillisletme/product/service/services/udp_sender_service.dart';
import 'package:akillisletme/product/service/services/wav_file_streamer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Ses yakalama / dosya akışı + UDP gönderim iş mantığı.
///
/// İki kaynak modu:
/// - [AudioSource.system] → Android MediaProjection (native)
/// - [AudioSource.file]   → WAV dosyası (Dart, native kod yok)
///
/// Her iki modda da ses verisi aynı [_onAudioData] → UDP yoluyla gönderilir.
final class AudioStreamCubit extends Cubit<AudioStreamState> {
  AudioStreamCubit({
    required AudioCaptureChannel captureChannel,
    required UdpSenderService    udpService,
    required WavFileStreamer      wavStreamer,
  })  : _capture  = captureChannel,
        _udp      = udpService,
        _wav      = wavStreamer,
        super(const AudioStreamState());

  final AudioCaptureChannel _capture;
  final UdpSenderService    _udp;
  final WavFileStreamer      _wav;

  StreamSubscription<Uint8List>? _audioSub;
  Timer?                          _statsTicker;

  int _prevPackets = 0;
  int _prevBytes   = 0;

  // ── Public API ────────────────────────────────────────────────────────

  /// Kaynak seçimini değiştirir (yayın sırasında değiştirilemez).
  void setAudioSource(AudioSource source) {
    if (state.isStreaming) return;
    emit(state.copyWith(audioSource: source));
  }

  /// Cihazdan WAV dosyası seçer.
  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['wav'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path   = picked.path;
    if (path == null) return;

    emit(
      state.copyWith(
        selectedFilePath: path,
        selectedFileName: picked.name,
        audioSource:      AudioSource.file,
      ),
    );
    _log('Dosya seçildi: ${picked.name}');
  }

  /// Döngü (loop) modunu değiştirir.
  void setLoopFile({required bool value}) {
    if (state.isStreaming) return;
    emit(state.copyWith(loopFile: value));
  }

  /// Ses akışını başlatır.
  /// Kaynak moduna göre otomatik olarak doğru yolu seçer.
  Future<void> startStreaming() async {
    if (state.isStreaming || state.isLoading) return;

    if (state.audioSource == AudioSource.file) {
      final path = state.selectedFilePath;
      if (path == null || path.isEmpty) {
        emit(state.copyWith(error: 'Önce bir WAV dosyası seçin.'));
        return;
      }
    }

    emit(state.copyWith(isLoading: true, error: null, logs: const []));

    try {
      await _udp.initialize(ip: state.targetIp, port: state.targetPort);

      if (state.audioSource == AudioSource.system) {
        await _startSystemCapture();
      } else {
        await _startFileStream();
      }

      _startStatsTicker();
      emit(state.copyWith(isLoading: false, isStreaming: true));
      _log(LocaleKeys.audioStream_logStarted.tr(
        namedArgs: {'ip': state.targetIp, 'port': state.targetPort.toString()},
      ));

      if (state.audioSource == AudioSource.system) {
        _log(LocaleKeys.audioStream_logSourceSystem.tr(
          namedArgs: {
            'sampleRate': state.sampleRate.toString(),
            'channel':    state.channels == 1
                ? LocaleKeys.audioStream_mono.tr()
                : LocaleKeys.audioStream_stereo.tr(),
            'buffer':     state.bufferSize.toString(),
          },
        ));
      } else {
        _log(LocaleKeys.audioStream_logSourceFile.tr(
          namedArgs: {
            'fileName': state.selectedFileName,
            'buffer':   state.bufferSize.toString(),
            'loop':     state.loopFile
                ? LocaleKeys.audioStream_logLoopEnabled.tr()
                : LocaleKeys.audioStream_logLoopDisabled.tr(),
          },
        ));
      }
    } on Object catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      _log(LocaleKeys.audioStream_logError.tr(namedArgs: {'error': e.toString()}));
    }
  }

  /// Ses akışını durdurur ve kaynakları serbest bırakır.
  Future<void> stopStreaming() async {
    if (!state.isStreaming && !state.isLoading) return;

    _statsTicker?.cancel();
    _statsTicker = null;

    await _audioSub?.cancel();
    _audioSub = null;

    if (state.audioSource == AudioSource.system) {
      await _capture.stopCapture();
    }
    await _udp.close();

    final kb = (state.totalBytesSent / 1024).toStringAsFixed(1);
    _log(LocaleKeys.audioStream_logStopped.tr(
      namedArgs: {'kb': kb, 'packets': state.totalPackets.toString()},
    ));

    emit(state.copyWith(isStreaming: false, isLoading: false));
  }

  /// Ağ ayarlarını günceller (yayın sırasında değiştirilemez).
  void updateNetworkSettings({required String ip, required int port}) {
    if (state.isStreaming) return;
    emit(state.copyWith(targetIp: ip, targetPort: port));
  }

  /// Ses ayarlarını günceller (yayın sırasında değiştirilemez).
  void updateAudioSettings({
    BufferSize? bufferSize,
    SampleRate? sampleRate,
    int?        channels,
    bool?       addWavHeader,
  }) {
    if (state.isStreaming) return;
    emit(
      state.copyWith(
        bufferSize:   bufferSize   ?? state.bufferSize,
        sampleRate:   sampleRate   ?? state.sampleRate,
        channels:     channels     ?? state.channels,
        addWavHeader: addWavHeader ?? state.addWavHeader,
      ),
    );
  }

  // ── Kaynak başlatıcılar ────────────────────────────────────────────────

  Future<void> _startSystemCapture() async {
    await _capture.startCapture(
      sampleRate: state.sampleRate.hz,
      channels:   state.channels,
      bufferSize: state.bufferSize.bytes,
    );
    _audioSub = _capture.audioStream.listen(
      _onAudioData,
      onError:       _onStreamError,
      onDone:        _onStreamDone,
      cancelOnError: false,
    );
  }

  Future<void> _startFileStream() async {
    final stream = _wav.stream(
      filePath:  state.selectedFilePath!,
      chunkSize: state.bufferSize.bytes,
      loop:      state.loopFile,
    );
    _audioSub = stream.listen(
      _onAudioData,
      onError:       _onStreamError,
      onDone:        _onStreamDone,
      cancelOnError: false,
    );
  }

  // ── Ortak data pipeline ───────────────────────────────────────────────

  void _onAudioData(Uint8List raw) {
    final payload = state.addWavHeader ? _wrapInWav(raw) : raw;
    if (!_udp.send(payload)) {
      _log(LocaleKeys.audioStream_logSendError.tr());
    }
  }

  void _onStreamError(Object error) {
    _log(LocaleKeys.audioStream_logChannelError.tr(namedArgs: {'error': error.toString()}));
    stopStreaming();
  }

  void _onStreamDone() {
    _log(LocaleKeys.audioStream_logChannelDone.tr());
    stopStreaming();
  }

  // ── İstatistik ────────────────────────────────────────────────────────

  void _startStatsTicker() {
    _prevPackets = 0;
    _prevBytes   = 0;
    _statsTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      final packets = _udp.totalPackets;
      final bytes   = _udp.totalBytesSent;
      emit(
        state.copyWith(
          totalBytesSent:   bytes,
          totalPackets:     packets,
          packetsPerSecond: packets - _prevPackets,
          kbytesPerSecond:  (bytes - _prevBytes) / 1024.0,
        ),
      );
      _prevPackets = packets;
      _prevBytes   = bytes;
    });
  }

  // ── Yardımcılar ───────────────────────────────────────────────────────

  void _log(String message) {
    final now   = DateTime.now();
    final ts    =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final entry   = '[$ts] $message';
    final updated = [...state.logs, entry];
    final trimmed = updated.length > 150
        ? updated.sublist(updated.length - 150)
        : updated;
    emit(state.copyWith(logs: trimmed));
  }

  /// PCM16 verisini WAV container'a sarar (44 byte header + data).
  Uint8List _wrapInWav(Uint8List pcm) {
    final ch            = state.channels;
    final sr            = state.sampleRate.hz;
    const bitsPerSample = 16;
    final byteRate      = sr * ch * bitsPerSample ~/ 8;
    final blockAlign    = ch * bitsPerSample ~/ 8;
    final dataSize      = pcm.length;
    final chunkSize     = 36 + dataSize;

    final hdr = ByteData(44)
      ..setUint8(0, 0x52) ..setUint8(1, 0x49) ..setUint8(2, 0x46) ..setUint8(3, 0x46)
      ..setUint32(4, chunkSize, Endian.little)
      ..setUint8(8, 0x57) ..setUint8(9, 0x41) ..setUint8(10, 0x56) ..setUint8(11, 0x45)
      ..setUint8(12, 0x66) ..setUint8(13, 0x6D) ..setUint8(14, 0x74) ..setUint8(15, 0x20)
      ..setUint32(16, 16, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, ch, Endian.little)
      ..setUint32(24, sr, Endian.little)
      ..setUint32(28, byteRate, Endian.little)
      ..setUint16(32, blockAlign, Endian.little)
      ..setUint16(34, bitsPerSample, Endian.little)
      ..setUint8(36, 0x64) ..setUint8(37, 0x61) ..setUint8(38, 0x74) ..setUint8(39, 0x61)
      ..setUint32(40, dataSize, Endian.little);

    return Uint8List(44 + dataSize)
      ..setAll(0, hdr.buffer.asUint8List())
      ..setAll(44, pcm);
  }

  @override
  Future<void> close() async {
    _statsTicker?.cancel();
    await _audioSub?.cancel();
    return super.close();
  }
}
