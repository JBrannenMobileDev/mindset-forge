import Foundation

/// Shared payload model for the watch app and its complication extension.
/// Mirrors the Dart `WidgetPayload`. Delivered from the phone over
/// WatchConnectivity and cached in the watch's App Group for the complication.
struct WatchPayload: Codable {
    var state: String
    var focusText: String
    var focusDate: String
    var focusCompleted: Bool
    var hasFocusToday: Bool
    var sessionPeriod: String

    // Resolved next-action (mirrors the dashboard hero / iOS widget).
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
    var displayName: String
    var firstName: String
    var updatedAt: String

    static let appGroupId = "group.com.mindsetforge.mindsetforge"
    static let payloadKey = "widget_payload"

    static let empty = WatchPayload(
        state: "set_focus",
        focusText: "",
        focusDate: "",
        focusCompleted: false,
        hasFocusToday: false,
        sessionPeriod: "morning",
        actionField: "setFocus",
        sessionLabel: "TODAY'S FOCUS",
        headline: "Set Your Focus",
        subline: "Plan your day",
        accentKind: "set_focus",
        canCompleteInWidget: false,
        deepLink: "mindsetforge://focus",
        streak: 0,
        completedCount: 0,
        totalCount: 8,
        displayName: "",
        firstName: "there",
        updatedAt: ""
    )

    /// The calm "complete" states (success accent, no CTA).
    var isDone: Bool { accentKind == "done" }

    /// Primary glance line — the focus text / routine step / prompt.
    var glanceLine: String {
        headline.isEmpty ? sessionLabel : headline
    }

    // MARK: - App Group cache

    static func load() -> WatchPayload {
        guard
            let defaults = UserDefaults(suiteName: appGroupId),
            let raw = defaults.string(forKey: payloadKey),
            let data = raw.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(WatchPayload.self, from: data)
        else {
            return .empty
        }
        return decoded
    }

    /// Persists a context dictionary received over WatchConnectivity into the
    /// App Group as the same JSON blob the complication reads.
    static func save(from context: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(withJSONObject: context),
            let json = String(data: data, encoding: .utf8),
            let defaults = UserDefaults(suiteName: appGroupId)
        else { return }
        defaults.set(json, forKey: payloadKey)
    }
}

// MARK: - Resilient decoding

// Decoding lives in an extension so the synthesized memberwise initializer
// (used by `.empty` and the optimistic update) is preserved. `decodeIfPresent`
// keeps the glance working when a stale phone payload lacks the newer keys.
extension WatchPayload {
    enum CodingKeys: String, CodingKey {
        case state, focusText, focusDate, focusCompleted, hasFocusToday
        case sessionPeriod, actionField, sessionLabel, headline, subline
        case accentKind, canCompleteInWidget, deepLink
        case streak, completedCount, totalCount, displayName, firstName, updatedAt
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
        displayName = try c.decodeIfPresent(String.self, forKey: .displayName) ?? ""
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName) ?? "there"
        updatedAt = try c.decodeIfPresent(String.self, forKey: .updatedAt) ?? ""
    }
}
