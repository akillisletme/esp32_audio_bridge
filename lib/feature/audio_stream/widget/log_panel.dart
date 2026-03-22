import 'package:akillisletme/product/const/app_paddings.dart';
import 'package:akillisletme/product/init/language/locale_keys.g.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Zaman damgalı log kayıtlarını gösteren panel.
final class LogPanel extends StatelessWidget {
  const LogPanel({
    required this.logs,
    required this.scrollController,
    super.key,
  });

  final List<String> logs;
  final ScrollController scrollController;

  String get _logText => logs.join('\n');

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _logText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocaleKeys.audioStream_logCopied.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(text: _logText));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppPaddings.l,
              AppPaddings.m,
              AppPaddings.s,
              0,
            ),
            child: Row(
              children: [
                Icon(Icons.terminal, size: 18, color: cs.primary),
                const SizedBox(width: AppPaddings.s),
                Text(
                  LocaleKeys.audioStream_logTitle.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.primary),
                ),
                const Spacer(),
                Text(
                  LocaleKeys.audioStream_logLines.tr(
                    namedArgs: {'count': logs.length.toString()},
                  ),
                  style: tt.labelSmall?.copyWith(color: cs.outline),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: LocaleKeys.audioStream_logCopy.tr(),
                  onPressed: logs.isEmpty ? null : () => _copy(context),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.share, size: 18),
                  tooltip: LocaleKeys.audioStream_logShare.tr(),
                  onPressed: logs.isEmpty ? null : _share,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppPaddings.s),
          const Divider(height: 1),
          SizedBox(
            height: 220,
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      LocaleKeys.audioStream_logEmpty.tr(),
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  )
                : ListView.builder(
                    controller:  scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppPaddings.m,
                      vertical:   AppPaddings.s,
                    ),
                    itemCount:   logs.length,
                    itemBuilder: (_, i) {
                      final lower = logs[i].toLowerCase();
                      return _LogLine(
                        line:    logs[i],
                        isError: lower.contains('hata') ||
                                 lower.contains('error') ||
                                 logs[i].contains('⚠'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LogLine extends StatelessWidget {
  const _LogLine({required this.line, required this.isError});

  final String line;
  final bool   isError;

  @override
  Widget build(BuildContext context) {
    final cs    = Theme.of(context).colorScheme;
    final color = isError ? cs.error : cs.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Text(
        line,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize:   11,
          color:      color,
          height:     1.4,
        ),
      ),
    );
  }
}
