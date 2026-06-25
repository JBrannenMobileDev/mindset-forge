import '../../models/goal.dart';
import 'app_strings.dart';

/// Static metadata for the goal timeframe options, shared by the goal form and
/// onboarding so the choices and default durations stay consistent.
class GoalTypeOption {
  final String value;
  final String label;
  final String subtitle;

  /// Default number of days from creation used to seed the target date when the
  /// user picks this timeframe and hasn't manually chosen a date.
  final int defaultDays;

  const GoalTypeOption(
    this.value,
    this.label,
    this.subtitle,
    this.defaultDays,
  );
}

const List<GoalTypeOption> kGoalTypeOptions = [
  GoalTypeOption(
    kGoalTypeShortTerm,
    AppStrings.goalTypeShort,
    AppStrings.goalTypeShortSub,
    90,
  ),
  GoalTypeOption(
    kGoalTypeMediumTerm,
    AppStrings.goalTypeMedium,
    AppStrings.goalTypeMediumSub,
    270,
  ),
  GoalTypeOption(
    kGoalTypeLongTerm,
    AppStrings.goalTypeLong,
    AppStrings.goalTypeLongSub,
    365 * 3,
  ),
  GoalTypeOption(
    kGoalTypeLifeGoal,
    AppStrings.goalTypeLife,
    AppStrings.goalTypeLifeSub,
    365 * 8,
  ),
];

/// Infers a [Goal.goalType] from a rough duration in months (used for the
/// template goals which only carry a month count).
String goalTypeFromMonths(int months) {
  if (months <= 3) return kGoalTypeShortTerm;
  if (months <= 12) return kGoalTypeMediumTerm;
  if (months <= 60) return kGoalTypeLongTerm;
  return kGoalTypeLifeGoal;
}
