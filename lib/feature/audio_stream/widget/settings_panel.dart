import 'package:akillisletme/feature/audio_stream/state/audio_stream_cubit.dart';
import 'package:akillisletme/feature/audio_stream/state/audio_stream_state.dart';
import 'package:akillisletme/product/const/app_paddings.dart';
import 'package:akillisletme/product/init/language/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Tüm ayarları içeren panel.
///
/// Yayın aktifken tüm kontroller devre dışıdır.
final class SettingsPanel extends StatelessWidget {
  const SettingsPanel({
    required this.ipController,
    required this.portController,
    required this.onApplyNetwork,
    super.key,
  });

  final TextEditingController ipController;
  final TextEditingController portController;
  final VoidCallback          onApplyNetwork;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioStreamCubit, AudioStreamState>(
      builder: (context, state) {
        final enabled = !state.isStreaming;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Kaynak seçimi ─────────────────────────────────
            _SourceCard(enabled: enabled, state: state),
            const SizedBox(height: AppPaddings.m),
            // ── Ağ ayarları ───────────────────────────────────
            _NetworkCard(
              ipController:   ipController,
              portController: portController,
              onApply:        onApplyNetwork,
              enabled:        enabled,
            ),
            const SizedBox(height: AppPaddings.m),
            // ── Ses ayarları (sistem sesi modunda) ────────────
            if (state.audioSource == AudioSource.system)
              _AudioCard(enabled: enabled, state: state),
          ],
        );
      },
    );
  }
}

// ── Kaynak Seçimi ─────────────────────────────────────────────────────────────

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.enabled, required this.state});

  final bool             enabled;
  final AudioStreamState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AudioStreamCubit>();
    final cs    = Theme.of(context).colorScheme;
    final tt    = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppPaddings.allL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppPaddings.m,
          children: [
            _SectionHeader(
              icon:  Icons.input,
              label: LocaleKeys.audioStream_sourceTitle.tr(),
            ),

            // Kaynak toggle
            SegmentedButton<AudioSource>(
              segments: [
                ButtonSegment(
                  value: AudioSource.system,
                  label: Text(LocaleKeys.audioStream_sourceSystem.tr()),
                  icon:  const Icon(Icons.phone_android),
                ),
                ButtonSegment(
                  value: AudioSource.file,
                  label: Text(LocaleKeys.audioStream_sourceFile.tr()),
                  icon:  const Icon(Icons.audio_file),
                ),
              ],
              selected:           {state.audioSource},
              onSelectionChanged: enabled
                  ? (s) => cubit.setAudioSource(s.first)
                  : null,
            ),

            // Dosya modu UI
            if (state.audioSource == AudioSource.file) ...[
              // Seçili dosya bilgisi
              if (state.selectedFileName.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppPaddings.m,
                    vertical:   AppPaddings.s,
                  ),
                  decoration: BoxDecoration(
                    color:        cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    spacing: AppPaddings.s,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size:  16,
                        color: cs.onSecondaryContainer,
                      ),
                      Expanded(
                        child: Text(
                          state.selectedFileName,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSecondaryContainer,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  LocaleKeys.audioStream_fileNotSelected.tr(),
                  style: tt.bodySmall?.copyWith(color: cs.outline),
                ),

              // Dosya seç butonu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: enabled ? cubit.pickFile : null,
                  icon:      const Icon(Icons.folder_open),
                  label:     Text(LocaleKeys.audioStream_pickFile.tr()),
                ),
              ),

              // Döngü switch
              SwitchListTile(
                value:     state.loopFile,
                onChanged: enabled
                    ? (v) => cubit.setLoopFile(value: v)
                    : null,
                title:    Text(LocaleKeys.audioStream_loopFile.tr()),
                subtitle: Text(LocaleKeys.audioStream_loopFileDesc.tr()),
                secondary: const Icon(Icons.loop),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Ağ Ayarları ───────────────────────────────────────────────────────────────

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.ipController,
    required this.portController,
    required this.onApply,
    required this.enabled,
  });

  final TextEditingController ipController;
  final TextEditingController portController;
  final VoidCallback          onApply;
  final bool                  enabled;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppPaddings.allL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppPaddings.m,
          children: [
            _SectionHeader(
              icon:  Icons.wifi,
              label: LocaleKeys.audioStream_networkSettings.tr(),
            ),
            Row(
              spacing: AppPaddings.m,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller:   ipController,
                    enabled:      enabled,
                    keyboardType: TextInputType.text,
                    decoration: InputDecoration(
                      labelText:  LocaleKeys.audioStream_ipAddress.tr(),
                      hintText:   '192.168.4.1',
                      prefixIcon: const Icon(Icons.router),
                      border:     const OutlineInputBorder(),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller:   portController,
                    enabled:      enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: LocaleKeys.audioStream_port.tr(),
                      hintText:  '4210',
                      border:    const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: enabled ? onApply : null,
                child: Text(LocaleKeys.audioStream_apply.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ses Ayarları ──────────────────────────────────────────────────────────────

class _AudioCard extends StatelessWidget {
  const _AudioCard({required this.enabled, required this.state});

  final bool             enabled;
  final AudioStreamState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AudioStreamCubit>();

    return Card(
      child: Padding(
        padding: AppPaddings.allL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppPaddings.m,
          children: [
            _SectionHeader(
              icon:  Icons.tune,
              label: LocaleKeys.audioStream_audioSettings.tr(),
            ),

            DropdownMenu<SampleRate>(
              initialSelection: state.sampleRate,
              label:            Text(LocaleKeys.audioStream_sampleRate.tr()),
              leadingIcon:      const Icon(Icons.graphic_eq),
              enabled:          enabled,
              expandedInsets:   EdgeInsets.zero,
              onSelected: enabled
                  ? (v) => cubit.updateAudioSettings(sampleRate: v)
                  : null,
              dropdownMenuEntries: SampleRate.values.map((sr) {
                return DropdownMenuEntry(
                  value: sr,
                  label: '${sr.hz} Hz  ($sr)',
                );
              }).toList(),
            ),

            DropdownMenu<BufferSize>(
              initialSelection: state.bufferSize,
              label:            Text(LocaleKeys.audioStream_bufferSize.tr()),
              leadingIcon:      const Icon(Icons.memory),
              enabled:          enabled,
              expandedInsets:   EdgeInsets.zero,
              onSelected: enabled
                  ? (v) => cubit.updateAudioSettings(bufferSize: v)
                  : null,
              dropdownMenuEntries: BufferSize.values.map((bs) {
                return DropdownMenuEntry(
                  value: bs,
                  label: '${bs.bytes} byte  ($bs)',
                );
              }).toList(),
            ),

            _SectionHeader(
              icon:  Icons.speaker_group,
              label: LocaleKeys.audioStream_channel.tr(),
            ),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 1,
                  label: Text(LocaleKeys.audioStream_mono.tr()),
                  icon:  const Icon(Icons.speaker),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(LocaleKeys.audioStream_stereo.tr()),
                  icon:  const Icon(Icons.speaker_group),
                ),
              ],
              selected:           {state.channels},
              onSelectionChanged: enabled
                  ? (s) => cubit.updateAudioSettings(channels: s.first)
                  : null,
            ),

            SwitchListTile(
              value:     state.addWavHeader,
              onChanged: enabled
                  ? (v) => cubit.updateAudioSettings(addWavHeader: v)
                  : null,
              title:    Text(LocaleKeys.audioStream_wavHeader.tr()),
              subtitle: Text(LocaleKeys.audioStream_wavHeaderDesc.tr()),
              secondary: const Icon(Icons.audio_file),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Yardımcı ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Row(
      spacing: AppPaddings.s,
      children: [
        Icon(icon, size: 18, color: cs.primary),
        Text(label, style: tt.titleSmall?.copyWith(color: cs.primary)),
      ],
    );
  }
}
