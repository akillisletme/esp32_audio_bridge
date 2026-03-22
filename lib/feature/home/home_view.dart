import 'package:akillisletme/feature/home/home_view_mode.dart';
import 'package:akillisletme/product/const/app_paddings.dart';
import 'package:akillisletme/product/init/language/locale_keys.g.dart';
import 'package:akillisletme/product/navigation/app_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends HomeViewMode {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.home_title.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => const SettingsRoute().push<void>(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => const AudioStreamRoute().push<void>(context),
        icon: const Icon(Icons.podcasts),
        label: Text(LocaleKeys.home_goToStream.tr()),
      ),
      body: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppPaddings.l,
          vertical: AppPaddings.l,
        ),
        children: [
          // ── Hero ──────────────────────────────────────────────
          _HeroSection(),
          const SizedBox(height: AppPaddings.xxl),

          // ── Nasıl Kullanılır ──────────────────────────────────
          _HowToUseCard(),
          const SizedBox(height: AppPaddings.l),

          // ── Ses Kaynakları ────────────────────────────────────
          _AudioModeCards(),
          const SizedBox(height: AppPaddings.l),

          // ── Varsayılan Bağlantı ───────────────────────────────
          _NetworkInfoCard(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// ── Hero ──────────────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        const SizedBox(height: AppPaddings.l),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.podcasts, size: 44, color: cs.onPrimary),
        ),
        const SizedBox(height: AppPaddings.l),
        Text(
          LocaleKeys.general_appName.tr(),
          style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppPaddings.s),
        Text(
          LocaleKeys.home_subtitle.tr(),
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ── Nasıl Kullanılır ──────────────────────────────────────────────────────────

class _HowToUseCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final steps = [
      (Icons.wifi, LocaleKeys.home_step1.tr()),
      (Icons.audio_file, LocaleKeys.home_step2.tr()),
      (Icons.play_circle_outline, LocaleKeys.home_step3.tr()),
    ];

    return Card(
      child: Padding(
        padding: AppPaddings.allL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppPaddings.m,
          children: [
            Row(
              spacing: AppPaddings.s,
              children: [
                Icon(Icons.help_outline, size: 18, color: cs.primary),
                Text(
                  LocaleKeys.home_howToUse.tr(),
                  style: tt.titleSmall?.copyWith(color: cs.primary),
                ),
              ],
            ),
            ...steps.indexed.map(((int, (IconData, String)) entry) {
              final (index, (icon, text)) = entry;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppPaddings.m,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: tt.labelMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(text, style: tt.bodyMedium),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Ses Kaynağı Kartları ──────────────────────────────────────────────────────

class _AudioModeCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppPaddings.m,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ModeCard(
            icon: Icons.phone_android,
            title: LocaleKeys.home_modeSystemTitle.tr(),
            description: LocaleKeys.home_modeSystemDesc.tr(),
          ),
        ),
        Expanded(
          child: _ModeCard(
            icon: Icons.audio_file,
            title: LocaleKeys.home_modeFileTitle.tr(),
            description: LocaleKeys.home_modeFileDesc.tr(),
          ),
        ),
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: AppPaddings.allL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppPaddings.s,
          children: [
            Icon(icon, color: cs.primary, size: 28),
            Text(
              title,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              description,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Varsayılan Bağlantı ───────────────────────────────────────────────────────

class _NetworkInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      color: cs.secondaryContainer,
      child: Padding(
        padding: AppPaddings.allL,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppPaddings.s,
          children: [
            Row(
              spacing: AppPaddings.s,
              children: [
                Icon(Icons.router, size: 18, color: cs.onSecondaryContainer),
                Text(
                  LocaleKeys.home_defaultNetwork.tr(),
                  style: tt.titleSmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ],
            ),
            _NetworkRow('IP', '192.168.4.1', cs, tt),
            _NetworkRow('Port', '4210', cs, tt),
          ],
        ),
      ),
    );
  }
}

class _NetworkRow extends StatelessWidget {
  const _NetworkRow(this.label, this.value, this.cs, this.tt);

  final String label;
  final String value;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
          ),
        ),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            color: cs.onSecondaryContainer,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
