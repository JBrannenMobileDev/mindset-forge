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
import '../../core/utils/breakpoints.dart';
import '../../models/journal_entry.dart';
import '../../providers/journal_provider.dart';
import '../../providers/daily_completion_provider.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen> {
  /// Desktop master/detail selection. Null until the user picks an entry, at
  /// which point the right reader pane follows it.
  String? _selectedEntryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final journalDone = ref.read(dailyCompletionProvider).journalCompleted;
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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (Breakpoints.isWideWidth(constraints.maxWidth)) {
              return _buildDesktop(context, entriesAsync);
            }
            return ResponsiveLayout(
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
                    child: Row(
                      children: [
                        Text(AppStrings.journal,
                            style: AppTextStyles.headlineLarge),
                        const Spacer(),
                        entriesAsync.maybeWhen(
                          data: (entries) => entries.isEmpty
                              ? const SizedBox.shrink()
                              : _AddEntryButton(
                                  onTap: () => context.push('/journal/new'),
                                ),
                          orElse: () => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  entriesAsync.when(
                    loading: () => const Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPaddingH),
                        child: ShimmerList(count: 4),
                      ),
                    ),
                    error: (_, __) => Expanded(
                      child: ErrorState(
                        message: AppStrings.errorGeneric,
                        onRetry: () => ref.invalidate(journalEntriesProvider),
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
                            ..._groupByMonth(entries).entries.map((group) =>
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(group.key,
                                        style: AppTextStyles.overline.copyWith(
                                            color: AppColors.textSecondary)),
                                    const SizedBox(height: AppSpacing.md),
                                    ...group.value
                                        .asMap()
                                        .entries
                                        .map((e) => Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: AppSpacing.md),
                                              child: _JournalEntryCard(
                                                entry: e.value,
                                                onTap: () => context.push(
                                                    '/journal/${e.value.id}'),
                                              ).animate().fadeIn(
                                                    delay: Duration(
                                                        milliseconds:
                                                            e.key * 50),
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
            );
          },
        ),
      ),
    );
  }

  /// Wide layout: a selectable entry list (with the mood trend) on the left and
  /// the selected entry rendered inline on the right — no push navigation.
  Widget _buildDesktop(
    BuildContext context,
    AsyncValue<List<JournalEntry>> entriesAsync,
  ) {
    return WebContentFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Row(
              children: [
                Text(AppStrings.journal, style: AppTextStyles.headlineLarge),
                const Spacer(),
                entriesAsync.maybeWhen(
                  data: (entries) => entries.isEmpty
                      ? const SizedBox.shrink()
                      : _AddEntryButton(
                          onTap: () => context.push('/journal/new'),
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          Expanded(
            child: entriesAsync.when(
              loading: () => const ShimmerList(count: 4),
              error: (_, __) => ErrorState(
                message: AppStrings.errorGeneric,
                onRetry: () => ref.invalidate(journalEntriesProvider),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: EmptyState(
                      icon: Icons.menu_book_rounded,
                      title: AppStrings.noJournalEntries,
                      subtitle: AppStrings.noJournalSubtitle,
                      ctaLabel: AppStrings.newEntry,
                      onCta: () => context.push('/journal/new'),
                    ),
                  );
                }

                // Default to the most recent entry until the user picks one.
                final selectedId = (_selectedEntryId != null &&
                        entries.any((e) => e.id == _selectedEntryId))
                    ? _selectedEntryId!
                    : entries.first.id;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 360,
                      child: ListView(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.lg,
                          bottom: AppSpacing.xl,
                        ),
                        children: [
                          _MoodChart(entries: entries),
                          const SizedBox(height: AppSpacing.lg),
                          ..._groupByMonth(entries).entries.map(
                                (group) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.key,
                                      style: AppTextStyles.overline.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    ...group.value.map(
                                      (entry) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: AppSpacing.md,
                                        ),
                                        child: _JournalEntryCard(
                                          entry: entry,
                                          selected: entry.id == selectedId,
                                          onTap: () => setState(
                                            () => _selectedEntryId = entry.id,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _EntryReaderPane(entryId: selectedId),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
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

class _AddEntryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddEntryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.newEntry,
      child: Material(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.add_rounded, size: 20, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Inline reader for the desktop master/detail layout. Renders the selected
/// entry on the right without pushing a route, with an inline delete affordance.
class _EntryReaderPane extends ConsumerWidget {
  final String entryId;

  const _EntryReaderPane({required this.entryId});

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

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(journalProvider.notifier).deleteEntry(entryId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider).valueOrNull ?? [];
    final entry = entries.where((e) => e.id == entryId).firstOrNull;

    if (entry == null) {
      return Center(
        child: Text(
          AppStrings.errorGeneric,
          style:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.lg, bottom: AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  entry.mode[0].toUpperCase() + entry.mode.substring(1),
                  style:
                      AppTextStyles.overline.copyWith(color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(_moodEmoji(entry.mood),
                    style: const TextStyle(fontSize: 14)),
                const SizedBox(width: AppSpacing.sm),
                Text('•', style: AppTextStyles.labelSmall),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  AppDateUtils.formatDate(entry.createdAt),
                  style: AppTextStyles.labelSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error, size: 20),
                  onPressed: () => _delete(context, ref),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (entry.prompt.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  entry.prompt,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              entry.content,
              style: AppTextStyles.bodyLarge.copyWith(height: 1.8),
            ),
          ],
        ),
      ),
    );
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
    final rawSpots = recent
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), _moodToValue(e.value.mood)))
        .toList();
    final spots = rawSpots.length == 1
        ? [rawSpots.first, FlSpot(1.0, rawSpots.first.y)]
        : rawSpots;
    final avg = rawSpots.isEmpty
        ? 3.0
        : rawSpots.map((s) => s.y).reduce((a, b) => a + b) / rawSpots.length;

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
              Text(AppStrings.moodTrendTitle, style: AppTextStyles.labelLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  AppStrings.moodTrendAvg(avg.toStringAsFixed(1)),
                  style: AppTextStyles.labelSmall
                      .copyWith(color: AppColors.primary),
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
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.chartGrid, strokeWidth: 1),
                ),
                titlesData: const FlTitlesData(
                  leftTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.2),
                          Colors.transparent
                        ],
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
  final bool selected;

  const _JournalEntryCard({
    required this.entry,
    required this.onTap,
    this.selected = false,
  });

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
      borderColor: selected ? AppColors.primary : null,
      backgroundColor: selected ? AppColors.primaryContainer : null,
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
                    Icon(_modeIcon(entry.mode),
                        color: _modeColor(entry.mode), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      entry.mode[0].toUpperCase() + entry.mode.substring(1),
                      style: AppTextStyles.labelSmall
                          .copyWith(color: _modeColor(entry.mode)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(_moodEmoji(entry.mood),
                  style: const TextStyle(fontSize: 16)),
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
