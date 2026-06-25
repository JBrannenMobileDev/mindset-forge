import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/shimmer_widget.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/utils/app_date_utils.dart';
import '../../models/journal_entry.dart';
import '../../providers/journal_provider.dart';
import '../../providers/daily_completion_provider.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final journalDone =
          ref.read(dailyCompletionProvider).journalCompleted;
      if (!journalDone) {
        context.push('/journal/new');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(journalEntriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: entriesAsync.whenOrNull(
        data: (entries) => entries.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () => context.push('/journal/new'),
                icon: const Icon(Icons.add_rounded),
                label: const Text(AppStrings.newEntry),
              ),
      ),
      body: SafeArea(
        bottom: false,
        child: ResponsiveLayout(
          maxWidth: 680,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.lg,
                AppSpacing.screenPaddingH,
                AppSpacing.md,
              ),
              child: Text(AppStrings.journal, style: AppTextStyles.headlineLarge),
            ),
            entriesAsync.when(
              loading: () => const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
                  child: ShimmerList(count: 4),
                ),
              ),
              error: (_, __) => Expanded(
                child: Center(
                  child: Text(
                    AppStrings.errorGeneric,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: EmptyState(
                        icon: Icons.menu_book_rounded,
                        title: AppStrings.noJournalEntries,
                        subtitle: AppStrings.noJournalSubtitle,
                        ctaLabel: AppStrings.newEntry,
                        onCta: () => context.push('/journal/new'),
                      ),
                    ),
                  );
                }

                return Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenPaddingH,
                      0,
                      AppSpacing.screenPaddingH,
                      100,
                    ),
                    children: [
                      _MoodChart(entries: entries),
                      const SizedBox(height: AppSpacing.xl),
                      ..._groupByMonth(entries).entries.map((group) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.key, style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
                              const SizedBox(height: AppSpacing.md),
                              ...group.value.asMap().entries.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                    child: _JournalEntryCard(
                                      entry: e.value,
                                      onTap: () => context.push('/journal/${e.value.id}'),
                                    ).animate().fadeIn(
                                          delay: Duration(milliseconds: e.key * 50),
                                          duration: 300.ms,
                                        ),
                                  )),
                              const SizedBox(height: AppSpacing.md),
                            ],
                          )),
                    ],
                  ),
                );
              },
            ),
          ],
          ),
        ),
      ),
    );
  }

  Map<String, List<JournalEntry>> _groupByMonth(List<JournalEntry> entries) {
    final grouped = <String, List<JournalEntry>>{};
    for (final entry in entries) {
      final key = AppDateUtils.formatMonthYear(entry.createdAt);
      grouped.putIfAbsent(key, () => []).add(entry);
    }
    return grouped;
  }
}

class _MoodChart extends StatelessWidget {
  final List<JournalEntry> entries;

  const _MoodChart({required this.entries});

  double _moodToValue(String mood) {
    return switch (mood) {
      'amazing' => 5.0,
      'good' => 4.0,
      'okay' => 3.0,
      'struggling' => 2.0,
      'low' => 1.0,
      _ => 3.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final recent = entries.take(30).toList().reversed.toList();
    // fl_chart needs ≥2 distinct X values to draw a line; duplicate the single
    // point offset by 1 so the chart always has something to render.
    final rawSpots = recent.asMap().entries.map((e) => FlSpot(e.key.toDouble(), _moodToValue(e.value.mood))).toList();
    final spots = rawSpots.length == 1
        ? [rawSpots.first, FlSpot(1.0, rawSpots.first.y)]
        : rawSpots;
    final avg = rawSpots.isEmpty ? 3.0 : rawSpots.map((s) => s.y).reduce((a, b) => a + b) / rawSpots.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mood Trend', style: AppTextStyles.labelLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  'Avg: ${avg.toStringAsFixed(1)}/5',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 100,
            child: LineChart(
              LineChartData(
                minY: 0.5,
                maxY: 5.5,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.chartGrid, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.secondary,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) =>
                          FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.secondary,
                        strokeWidth: 1.5,
                        strokeColor: AppColors.surface,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.secondary.withValues(alpha: 0.2), Colors.transparent],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;

  const _JournalEntryCard({required this.entry, required this.onTap});

  String _moodEmoji(String mood) {
    return switch (mood) {
      'amazing' => '🤩',
      'good' => '😊',
      'okay' => '😐',
      'struggling' => '😟',
      'low' => '😔',
      _ => '😐',
    };
  }

  Color _modeColor(String mode) {
    return switch (mode) {
      'reflect' => AppColors.secondary,
      'grow' => AppColors.categoryHealth,
      'prime' => AppColors.warning,
      _ => AppColors.primary,
    };
  }

  IconData _modeIcon(String mode) {
    return switch (mode) {
      'reflect' => Icons.nightlight_round,
      'grow' => Icons.eco_rounded,
      'prime' => Icons.wb_sunny_rounded,
      _ => Icons.edit_note_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _modeColor(entry.mode).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_modeIcon(entry.mode), color: _modeColor(entry.mode), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        entry.mode[0].toUpperCase() + entry.mode.substring(1),
                        style: AppTextStyles.labelSmall.copyWith(color: _modeColor(entry.mode)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(_moodEmoji(entry.mood), style: const TextStyle(fontSize: 16)),
                const Spacer(),
                Text(
                  AppDateUtils.formatDate(entry.createdAt),
                  style: AppTextStyles.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (entry.prompt.isNotEmpty)
              Text(
                entry.prompt,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              entry.content,
              style: AppTextStyles.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
      ),
    );
  }
}
