import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Palette helpers

/// Accent bucket -> brand colour, mirroring the in-app hero (morning = warning,
/// evening = secondary, focus / set-focus = primary, done = success).
private func focusAccent(for payload: WidgetPayload) -> Color {
    switch payload.accentKind {
    case "morning": return MFColors.warning
    case "evening": return MFColors.secondary
    case "done": return MFColors.success
    default: return MFColors.primary
    }
}

/// Brighter accent for text/icons that sit on top of the accent gradient.
private func focusAccentBright(for payload: WidgetPayload) -> Color {
    switch payload.accentKind {
    case "morning": return MFColors.warning
    case "evening": return MFColors.secondary
    case "done": return MFColors.successBright
    default: return MFColors.primaryBright
    }
}

private func iconName(for payload: WidgetPayload) -> String {
    switch payload.actionField {
    case "identityRead": return "person.fill"
    case "affirmationsMorning": return "sun.max.fill"
    case "affirmationsEvening": return "moon.stars.fill"
    case "futureSelfCompleted": return "sparkles"
    case "journalCompleted": return "square.and.pencil"
    case "dayPlanned": return "checkmark.circle"
    case "chatCompleted": return "bubble.left.and.bubble.right.fill"
    case "gratitudeLogged": return "heart.fill"
    case "evidenceLogged": return "trophy.fill"
    case "focus": return "scope"
    case "setFocus": return "plus.circle.fill"
    case "onTrack": return "checkmark.circle.fill"
    default:
        if payload.isDone { return "checkmark.circle.fill" }
        if payload.state == "set_focus" { return "plus.circle.fill" }
        return "scope"
    }
}

// MARK: - Signature background

/// Nebula background matching the in-app Today's Focus hero: an elevated dark
/// surface with a diagonal accent wash and a soft secondary glow.
private struct FocusBackground: View {
    let payload: WidgetPayload

    var body: some View {
        let accent = focusAccent(for: payload)
        ZStack {
            MFColors.surfaceElevated
            LinearGradient(
                colors: [accent.opacity(0.42), accent.opacity(0.12), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if !payload.isDone {
                RadialGradient(
                    colors: [MFColors.secondary.opacity(0.16), .clear],
                    center: .bottomTrailing,
                    startRadius: 4,
                    endRadius: 220
                )
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func focusContainerBackground(_ payload: WidgetPayload) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { FocusBackground(payload: payload) }
        } else {
            background(FocusBackground(payload: payload))
        }
    }

    /// Lock-screen accessories must declare a (clear) container background on
    /// iOS 17 so the system applies its own vibrant material.
    @ViewBuilder
    func accessoryContainerBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { Color.clear }
        } else {
            self
        }
    }
}

// MARK: - Reusable pieces

private struct Eyebrow: View {
    let text: String
    let accent: Color
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .heavy))
            .tracking(1.4)
            .foregroundColor(accent)
    }
}

private struct IconBadge: View {
    let systemName: String
    let accent: Color
    var size: CGFloat = 40

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(accent.opacity(0.18))
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundColor(accent)
            )
    }
}

struct StreakBadge: View {
    let streak: Int
    var compact: Bool = false

    var body: some View {
        if streak > 0 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: compact ? 9 : 10, weight: .bold))
                Text("\(streak)")
                    .font(.system(size: compact ? 11 : 12, weight: .bold))
            }
            .foregroundColor(MFColors.warning)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(MFColors.warning.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

/// Daily-routine progress as a row of dots (filled = completed today).
private struct ProgressDots: View {
    let filled: Int
    let total: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< max(total, 0), id: \.self) { i in
                Capsule()
                    .fill(i < filled ? accent : MFColors.textMuted.opacity(0.5))
                    .frame(width: i < filled ? 11 : 6, height: 4)
            }
        }
    }
}

/// 7-day streak chain for the focus-complete state. Mirrors the in-app
/// dashboard: a flame-filled circle for qualifying days, an in-progress ring
/// for today (focus done ≠ streak earned), and empty dots for missed days.
private struct WeekStreakRow: View {
    let weekStreak: [Bool]
    let weekLabels: [String]
    var dot: CGFloat = 26

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0 ..< weekStreak.count, id: \.self) { i in
                let isToday = i == weekStreak.count - 1
                VStack(spacing: 5) {
                    Text(weekLabels.indices.contains(i) ? weekLabels[i] : "")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(isToday ? MFColors.successBright : MFColors.textMuted)
                    cell(qualifying: weekStreak[i], isToday: isToday)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func cell(qualifying: Bool, isToday: Bool) -> some View {
        if qualifying {
            ZStack {
                Circle().fill(MFColors.warning)
                Image(systemName: "flame.fill")
                    .font(.system(size: dot * 0.42, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: dot, height: dot)
            .overlay(
                Group {
                    if isToday {
                        Circle().strokeBorder(MFColors.successBright, lineWidth: 2)
                    }
                }
            )
        } else if isToday {
            ZStack {
                Circle().fill(MFColors.success.opacity(0.15))
                Circle().strokeBorder(MFColors.successBright, lineWidth: 2)
                Image(systemName: "flame.fill")
                    .font(.system(size: dot * 0.42, weight: .bold))
                    .foregroundColor(MFColors.successBright)
            }
            .frame(width: dot, height: dot)
        } else {
            Circle()
                .fill(MFColors.textMuted.opacity(0.2))
                .frame(width: dot, height: dot)
        }
    }
}

/// Contextual action: interactive Mark Done (iOS 17+), a done badge, or a
/// "set focus" prompt. Non-interactive states rely on the whole-widget URL.
private struct FocusAction: View {
    let payload: WidgetPayload
    let accent: Color
    var compact: Bool = false

    private var hPad: CGFloat { compact ? 12 : 16 }
    private var vPad: CGFloat { compact ? 7 : 9 }
    private var fontSize: CGFloat { compact ? 12 : 13 }

    var body: some View {
        if payload.canCompleteInWidget {
            // Today's Focus — the only action completable in place.
            if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: CompleteFocusIntent()) {
                    pill(compact ? "Done" : "Mark Done", "checkmark", filled: true)
                }
                .buttonStyle(.plain)
            } else {
                pill("Open to complete", "arrow.up.right", filled: false)
            }
        } else if payload.isDone {
            pill("Done for today", "checkmark.circle.fill", filled: false)
        } else if payload.accentKind == "set_focus" {
            pill("Set focus", "plus", filled: true)
        } else {
            // Morning / evening routine step — opens the app to that action.
            pill(compact ? "Open" : "Begin", "arrow.up.right", filled: true)
        }
    }

    private func pill(_ text: String, _ system: String, filled: Bool) -> some View {
        Label(text, systemImage: system)
            .font(.system(size: fontSize, weight: .bold))
            .padding(.horizontal, hPad)
            .padding(.vertical, vPad)
            .background(filled ? accent : accent.opacity(0.18))
            .foregroundColor(filled ? .white : accent)
            .clipShape(Capsule())
    }
}

// MARK: - Entry view (family router)

struct FocusWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FocusEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallFocusView(payload: entry.payload)
        case .systemMedium:
            MediumFocusView(payload: entry.payload)
        case .systemLarge:
            LargeFocusView(payload: entry.payload)
        default:
            if #available(iOSApplicationExtension 16.0, *) {
                AccessoryFocusView(payload: entry.payload)
            } else {
                SmallFocusView(payload: entry.payload)
            }
        }
    }
}

// MARK: - Small

struct SmallFocusView: View {
    let payload: WidgetPayload

    var body: some View {
        let accent = focusAccent(for: payload)
        let bright = focusAccentBright(for: payload)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow(text: payload.sessionLabel, accent: bright)
                Spacer()
                StreakBadge(streak: payload.streak, compact: true)
            }
            Spacer(minLength: 6)
            Text(payload.headline)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(MFColors.textPrimary)
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            FocusAction(payload: payload, accent: accent, compact: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .focusContainerBackground(payload)
        .widgetURL(URL(string: payload.deepLink))
    }
}

// MARK: - Medium

struct MediumFocusView: View {
    let payload: WidgetPayload

    var body: some View {
        let accent = focusAccent(for: payload)
        let bright = focusAccentBright(for: payload)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                IconBadge(systemName: iconName(for: payload), accent: bright, size: 38)
                Eyebrow(text: payload.sessionLabel, accent: bright)
                Spacer()
                StreakBadge(streak: payload.streak)
            }
            Text(payload.headline)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(MFColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            // In the done state the streak chain + caption replace the subline.
            if payload.hasSubline && !(payload.isDone && payload.hasWeekStreak) {
                Text(payload.subline)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(MFColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if payload.isDone && payload.hasWeekStreak {
                VStack(alignment: .leading, spacing: 8) {
                    WeekStreakRow(
                        weekStreak: payload.weekStreak,
                        weekLabels: payload.weekLabels,
                        dot: 22
                    )
                    HStack(alignment: .center) {
                        FocusAction(payload: payload, accent: accent)
                        Spacer()
                        Text(payload.weekCaption)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(MFColors.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
            } else {
                HStack(alignment: .center) {
                    FocusAction(payload: payload, accent: accent)
                    Spacer()
                    if payload.hasProgress {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(payload.completedCount)/\(payload.totalCount) today")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(MFColors.textSecondary)
                            ProgressDots(
                                filled: payload.completedCount,
                                total: payload.totalCount,
                                accent: bright
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusContainerBackground(payload)
        .widgetURL(URL(string: payload.deepLink))
    }
}

// MARK: - Large

struct LargeFocusView: View {
    let payload: WidgetPayload

    var body: some View {
        let accent = focusAccent(for: payload)
        let bright = focusAccentBright(for: payload)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                IconBadge(systemName: iconName(for: payload), accent: bright, size: 46)
                Eyebrow(text: payload.sessionLabel, accent: bright)
                Spacer()
                StreakBadge(streak: payload.streak)
            }
            Text(payload.headline)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(MFColors.textPrimary)
                .lineLimit(5)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            if payload.hasSubline {
                Text(payload.subline)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(MFColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if payload.isDone && payload.hasWeekStreak {
                VStack(alignment: .leading, spacing: 10) {
                    WeekStreakRow(
                        weekStreak: payload.weekStreak,
                        weekLabels: payload.weekLabels,
                        dot: 30
                    )
                    Text(payload.weekCaption)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MFColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if payload.hasProgress {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(payload.completedCount) of \(payload.totalCount) complete today")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(MFColors.textSecondary)
                    ProgressDots(
                        filled: payload.completedCount,
                        total: payload.totalCount,
                        accent: bright
                    )
                }
            }
            FocusAction(payload: payload, accent: accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .focusContainerBackground(payload)
        .widgetURL(URL(string: payload.deepLink))
    }
}

// MARK: - Lock screen accessory

@available(iOSApplicationExtension 16.0, *)
struct AccessoryFocusView: View {
    @Environment(\.widgetFamily) private var family
    let payload: WidgetPayload

    var body: some View {
        Group {
            if family == .accessoryInline {
                Label(inlineText, systemImage: iconName(for: payload))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.sessionLabel)
                        .font(.system(size: 10, weight: .semibold))
                    Text(payload.headline)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                }
            }
        }
        .accessoryContainerBackground()
        .widgetURL(URL(string: payload.deepLink))
    }

    private var inlineText: String {
        payload.headline.isEmpty ? payload.sessionLabel : payload.headline
    }
}
