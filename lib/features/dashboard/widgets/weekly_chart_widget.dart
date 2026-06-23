import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../models/user_profile.dart';
import '../../../models/daily_completion.dart';

class WeeklyChartWidget extends StatelessWidget {
  final UserProfile profile;

  const WeeklyChartWidget({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final days = AppDateUtils.lastNDays(7);

    final bars = days.map((d) {
      final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final completion = profile.dailyCompletions.firstWhere(
        (c) => c.date == dateStr,
        orElse: () => DailyCompletion(date: dateStr),
      );
      return completion.completionPercent;
    }).toList();

    return Column(
      children: [
        SectionHeader(title: AppStrings.weeklyActivity),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            children: [
              SizedBox(
                height: 140,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: 1.0,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= days.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                AppDateUtils.weekdayShort(days[idx]),
                                style: AppTextStyles.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 0.5,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.chartGrid,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: List.generate(days.length, (i) {
                      final value = bars[i];
                      final isToday = AppDateUtils.isSameDay(days[i], DateTime.now());
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: value == 0 ? 0.02 : value,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isToday
                                  ? [AppColors.primary, AppColors.primaryLight]
                                  : [
                                      AppColors.primary.withValues(alpha: 0.4),
                                      AppColors.primary.withValues(alpha: 0.6),
                                    ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Today', style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary)),
                  const SizedBox(width: AppSpacing.md),
                  Container(width: 10, height: 10, decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(width: AppSpacing.xs),
                  Text('Previous days', style: AppTextStyles.labelSmall),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
