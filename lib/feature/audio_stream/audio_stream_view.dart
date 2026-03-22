import 'package:akillisletme/feature/audio_stream/audio_stream_view_model.dart';
import 'package:akillisletme/feature/audio_stream/state/audio_stream_cubit.dart';
import 'package:akillisletme/feature/audio_stream/state/audio_stream_state.dart';
import 'package:akillisletme/feature/audio_stream/widget/log_panel.dart';
import 'package:akillisletme/feature/audio_stream/widget/settings_panel.dart';
import 'package:akillisletme/feature/audio_stream/widget/stats_bar.dart';
import 'package:akillisletme/product/const/app_paddings.dart';
import 'package:akillisletme/product/init/language/locale_keys.g.dart';
import 'package:akillisletme/product/service/services/audio_capture_channel.dart';
import 'package:akillisletme/product/service/services/udp_sender_service.dart';
import 'package:akillisletme/product/service/services/wav_file_streamer.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// ESP32 ses akışı ana ekranı.
///
/// BlocProvider burada yerelde açılır — cubit sadece bu ekran açıkken yaşar.
/// Ekran kapatılınca cubit dispose edilir ve UDP soketi + ses kaynakları
/// otomatik serbest bırakılır.
class AudioStreamView extends StatefulWidget {
  const AudioStreamView({super.key});

  @override
  State<AudioStreamView> createState() => _AudioStreamViewState();
}

class _AudioStreamViewState extends AudioStreamViewModel {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AudioStreamCubit(
        captureChannel: AudioCaptureChannel.instance,
        udpService:     UdpSenderService.instance,
        wavStreamer:    WavFileStreamer.instance,
      ),
      child: _AudioStreamContent(
        ipController:        ipController,
        portController:      portController,
        logScrollController: logScrollController,
        onApplyNetwork:      applyNetworkSettings,
        onScrollToBottom:    scrollLogsToBottom,
      ),
    );
  }
}

// ── İçerik ────────────────────────────────────────────────────────────────────

class _AudioStreamContent extends StatelessWidget {
  const _AudioStreamContent({
    required this.ipController,
    required this.portController,
    required this.logScrollController,
    required this.onApplyNetwork,
    required this.onScrollToBottom,
  });

  final TextEditingController ipController;
  final TextEditingController portController;
  final ScrollController      logScrollController;
  final VoidCallback          onApplyNetwork;
  final VoidCallback          onScrollToBottom;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AudioStreamCubit, AudioStreamState>(
      // Yeni log gelince otomatik kaydır
      listenWhen: (prev, cur) => prev.logs.length != cur.logs.length,
      listener:   (_, __) => onScrollToBottom(),
      child: BlocListener<AudioStreamCubit, AudioStreamState>(
        // Hata gelince SnackBar göster
        listenWhen: (prev, cur) =>
            cur.error != null && prev.error != cur.error,
        listener: (ctx, state) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content:         Text('${LocaleKeys.error_title.tr()}: ${state.error}'),
              backgroundColor: Theme.of(ctx).colorScheme.error,
              behavior:        SnackBarBehavior.floating,
            ),
          );
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(LocaleKeys.audioStream_title.tr()),
            actions: [
              BlocBuilder<AudioStreamCubit, AudioStreamState>(
                buildWhen: (p, c) => p.isStreaming != c.isStreaming,
                builder: (ctx, state) => Padding(
                  padding: const EdgeInsets.only(right: AppPaddings.s),
                  child: Chip(
                    avatar: Icon(
                      state.isStreaming
                          ? Icons.circle
                          : Icons.circle_outlined,
                      size:  12,
                      color: state.isStreaming
                          ? Colors.green
                          : Theme.of(ctx).colorScheme.outline,
                    ),
                    label: Text(
                      state.isStreaming
                          ? LocaleKeys.audioStream_statusLive.tr()
                          : LocaleKeys.audioStream_statusWaiting.tr(),
                    ),
                    side: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          // ── Gövde ────────────────────────────────────────────────────
          body: BlocBuilder<AudioStreamCubit, AudioStreamState>(
            builder: (_, state) => ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppPaddings.l,
                vertical:   AppPaddings.m,
              ),
              children: [
                StatsBar(state: state),
                const SizedBox(height: AppPaddings.m),
                SettingsPanel(
                  ipController:   ipController,
                  portController: portController,
                  onApplyNetwork: onApplyNetwork,
                ),
                const SizedBox(height: AppPaddings.m),
                LogPanel(
                  logs:             state.logs,
                  scrollController: logScrollController,
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          // ── Başlat / Durdur FAB ──────────────────────────────────────
          floatingActionButton: BlocBuilder<AudioStreamCubit, AudioStreamState>(
            buildWhen: (p, c) =>
                p.isStreaming != c.isStreaming ||
                p.isLoading   != c.isLoading,
            builder: (ctx, state) {
              if (state.isLoading) {
                return const FloatingActionButton.extended(
                  onPressed: null,
                  icon:      SizedBox(
                    width:  18,
                    height: 18,
                    child:  CircularProgressIndicator(strokeWidth: 2),
                  ),
                  label: _ConnectingLabel(),
                );
              }

              return state.isStreaming
                  ? FloatingActionButton.extended(
                      onPressed: () =>
                          ctx.read<AudioStreamCubit>().stopStreaming(),
                      backgroundColor:
                          Theme.of(ctx).colorScheme.errorContainer,
                      foregroundColor:
                          Theme.of(ctx).colorScheme.onErrorContainer,
                      icon:  const Icon(Icons.stop_circle_outlined),
                      label: Text(LocaleKeys.audioStream_stopButton.tr()),
                    )
                  : FloatingActionButton.extended(
                      onPressed: () =>
                          ctx.read<AudioStreamCubit>().startStreaming(),
                      icon:  const Icon(Icons.play_circle_outline),
                      label: Text(LocaleKeys.audioStream_startButton.tr()),
                    );
            },
          ),
        ),
      ),
    );
  }
}

/// Const context'te tr() çağrısı yapılamadığı için ayrı widget.
class _ConnectingLabel extends StatelessWidget {
  const _ConnectingLabel();

  @override
  Widget build(BuildContext context) =>
      Text(LocaleKeys.audioStream_connecting.tr());
}
