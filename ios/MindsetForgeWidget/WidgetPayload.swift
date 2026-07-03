import Foundation

/// Mirror of the Dart `WidgetPayload` (lib/models/widget_payload.dart), decoded
/// from the JSON blob the app writes into the shared App Group via `home_widget`.
///
/// The next-action fields (`sessionLabel`, `headline`, `subline`, `accentKind`,
/// ...) are resolved on the Dart side by the shared `resolveHeroAction`, so the
/// widget shows exactly the same "right now" action as the in-app hero.
struct WidgetPayload: Codable {
    var state: String
    var focusText: String
    var focusDate: String
    var focusCompleted: Bool
    var hasFocusToday: Bool
    var sessionPeriod: String

    // Resolved next-action (mirrors the dashboard hero).
    var actionField: String
    var sessionLabel: String
    var headline: String
    var subline: String
    var accentKind: String
    var canCompleteInWidget: Bool
    var deepLink: String

    var streak: Int
    var completedCount: Int
    var totalCount: Int

    /// Last 7 days of streak qualification (oldest → newest, index 6 = today).
    var weekStreak: [Bool]
    /// Per-day 9/9 perfect flag aligned to `weekStreak` (index 6 = today).
    var weekPerfect: [Bool]
    /// Single-char weekday letters aligned to `weekStreak` (M T W T F S S).
    var weekLabels: [String]
    /// Nudge line shown beneath the 7-day chain in the focus-complete state.
    var weekCaption: String

    var displayName: String
    var firstName: String
    var updatedAt: String

    static let appGroupId = "group.com.mindsetforge.mindsetforge"
    static let payloadKey = "widget_payload"

    static let empty = WidgetPayload(
        state: "set_focus",
        focusText: "",
        focusDate: "",
        focusCompleted: false,
        hasFocusToday: false,
        sessionPeriod: "morning",
        actionField: "setFocus",
        sessionLabel: "TODAY'S FOCUS",
        headline: "Set Your Focus",
        subline: "Choose the #1 action that moves you closest to who you're becoming.",
        accentKind: "set_focus",
        canCompleteInWidget: false,
        deepLink: "mindsetforge://focus",
        streak: 0,
        completedCount: 0,
        totalCount: 8,
        weekStreak: [],
        weekPerfect: [],
        weekLabels: [],
        weekCaption: "",
        displayName: "",
        firstName: "there",
        updatedAt: ""
    )

    /// Reads the latest payload the app stored in the App Group. Falls back to
    /// `.empty` if nothing has been written yet or decoding fails.
    static func load() -> WidgetPayload {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: payloadKey),
            let data = raw.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(WidgetPayload.self, from: data)
        else {
            return .empty
        }
        return decoded
    }

    // MARK: - Presentation helpers

    /// The calm "complete" states (success accent, no CTA).
    var isDone: Bool { accentKind == "done" }

    /// Whether there's a daily-routine progress value worth rendering.
    var hasProgress: Bool { totalCount > 0 }

    /// Whether a secondary line should render under the headline.
    var hasSubline: Bool { !subline.isEmpty }

    /// Whether a full 7-day streak chain is available to render.
    var hasWeekStreak: Bool { weekStreak.count == 7 && weekLabels.count == 7 }
}

// MARK: - Resilient decoding

// Decoding lives in an extension so the synthesized memberwise initializer
// (used by `.empty`) is preserved. `decodeIfPresent` keeps the widget working
// across version transitions where a stale payload may lack the newer keys.
extension WidgetPayload {
    enum CodingKeys: String, CodingKey {
        case state, focusText, focusDate, focusCompleted, hasFocusToday
        case sessionPeriod, actionField, sessionLabel, headline, subline
        case accentKind, canCompleteInWidget, deepLink
        case streak, completedCount, totalCount
        case weekStreak, weekPerfect, weekLabels, weekCaption
        case displayName, firstName, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        state = try c.decodeIfPresent(String.self, forKey: .state) ?? "set_focus"
        focusText = try c.decodeIfPresent(String.self, forKey: .focusText) ?? ""
        focusDate = try c.decodeIfPresent(String.self, forKey: .focusDate) ?? ""
        focusCompleted = try c.decodeIfPresent(Bool.self, forKey: .focusCompleted) ?? false
        hasFocusToday = try c.decodeIfPresent(Bool.self, forKey: .hasFocusToday) ?? false
        sessionPeriod = try c.decodeIfPresent(String.self, forKey: .sessionPeriod) ?? "morning"
        actionField = try c.decodeIfPresent(String.self, forKey: .actionField) ?? "setFocus"
        sessionLabel = try c.decodeIfPresent(String.self, forKey: .sessionLabel) ?? "TODAY'S FOCUS"
        let decodedHeadline = try c.decodeIfPresent(String.self, forKey: .headline)
        headline = decodedHeadline ?? (focusText.isEmpty ? "Set Your Focus" : focusText)
        subline = try c.decodeIfPresent(String.self, forKey: .subline) ?? ""
        accentKind = try c.decodeIfPresent(String.self, forKey: .accentKind)
            ?? (hasFocusToday ? "focus" : "set_focus")
        canCompleteInWidget = try c.decodeIfPresent(Bool.self, forKey: .canCompleteInWidget)
            ?? (hasFocusToday && !focusCompleted)
        deepLink = try c.decodeIfPresent(String.self, forKey: .deepLink) ?? "mindsetforge://focus"
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        completedCount = try c.decodeIfPresent(Int.self, forKey: .completedCount) ?? 0
        totalCount = try c.decodeIfPresent(Int.self, forKey: .totalCount) ?? 8
        weekStreak = try c.decodeIfPresent([Bool].self, forKey: .weekStreak) ?? []
        weekPerfect = try c.decodeIfPresent([Bool].self, forKey: .weekPerfect) ?? []
        weekLabels = try c.decodeIfPresent([String].self, forKey: .weekLabels) ?? []
        weekCaption = try c.decodeIfPresent(String.self, forKey: .weekCaption) ?? ""
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName) ?? "there"
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}
