import 'package:akillisletme/feature/audio_stream/state/audio_stream_state.dart';
import 'package:akillisletme/product/const/app_paddings.dart';
import 'package:akillisletme/product/init/language/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Canlı istatistikleri gösteren kart satırı.
final class StatsBar extends StatelessWidget {
  const StatsBar({required this.state, super.key});

  final AudioStreamState state;

  @override
  Widget build(BuildContext context) {
    final cs          = Theme.of(context).colorScheme;
    final activeColor = state.isStreaming ? cs.primary : cs.outline;

    return Row(
      children: [
        _StatCard(
          label: LocaleKeys.audioStream_statKbs.tr(),
          value: state.kbytesPerSecond.toStringAsFixed(1),
          icon:  Icons.speed,
          color: activeColor,
        ),
        const SizedBox(width: AppPaddings.s),
        _StatCard(
          label: LocaleKeys.audioStream_statPps.tr(),
          value: state.packetsPerSecond.toString(),
          icon:  Icons.send,
          color: activeColor,
        ),
        const SizedBox(width: AppPaddings.s),
        _StatCard(
          label: LocaleKeys.audioStream_statTotalPackets.tr(),
          value: state.totalPackets.toString(),
          icon:  Icons.stacked_bar_chart,
          color: activeColor,
        ),
        const SizedBox(width: AppPaddings.s),
        _StatCard(
          label: LocaleKeys.audioStream_statTotalKb.tr(),
          value: (state.totalBytesSent / 1024).toStringAsFixed(0),
          icon:  Icons.data_usage,
          color: activeColor,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Expanded(
      child: Card(
        color: cs.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppPaddings.s,
            vertical:   AppPaddings.m,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: tt.titleMedium?.copyWith(
                  color:      color,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines:  1,
                overflow:  TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: cs.outline),
                textAlign: TextAlign.center,
                maxLines:  1,
                overflow:  TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
