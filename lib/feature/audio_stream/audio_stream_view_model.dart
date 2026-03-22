import 'package:akillisletme/feature/audio_stream/audio_stream_view.dart';
import 'package:akillisletme/feature/audio_stream/state/audio_stream_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// ViewModel: controller'lar ve lifecycle yönetimi.
///
/// AudioStreamView BlocProvider'ı kendi build metodunda yarattığı için
/// initState'te cubit henüz erişilebilir değildir. Bu nedenle
/// controller'lar AudioStreamState default değerleriyle başlatılır.
abstract class AudioStreamViewModel extends State<AudioStreamView> {
  late final TextEditingController ipController;
  late final TextEditingController portController;
  late final ScrollController      logScrollController;

  @override
  void initState() {
    super.initState();
    // AudioStreamState default değerleriyle başlat.
    // BlocProvider build'de yaratıldığından initState'te cubit'e erişilemez.
    ipController        = TextEditingController(text: '192.168.4.1');
    portController      = TextEditingController(text: '4210');
    logScrollController = ScrollController();
  }

  @override
  void dispose() {
    ipController.dispose();
    portController.dispose();
    logScrollController.dispose();
    super.dispose();
  }

  /// IP ve Port değerlerini cubit'e aktarır.
  /// build'den sonra çağrıldığından cubit erişimi güvenlidir.
  void applyNetworkSettings() {
    final ip   = ipController.text.trim();
    final port = int.tryParse(portController.text.trim()) ?? 4210;
    context.read<AudioStreamCubit>().updateNetworkSettings(ip: ip, port: port);
    FocusScope.of(context).unfocus();
  }

  /// Log panelini en alta kaydırır.
  void scrollLogsToBottom() {
    if (!logScrollController.hasClients) return;
    final pos = logScrollController.position;
    if (pos.pixels < pos.maxScrollExtent) {
      logScrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve:    Curves.easeOut,
      );
    }
  }
}
