import AppIntents
import Foundation
import home_widget

/// Interactive widget action (iOS 17+) for marking Today's Focus done without
/// opening the app. Delegates to `home_widget`'s background worker, which runs
/// the registered Dart `widgetInteractiveCallback` so all persistence logic
/// lives in one place (Dart/Firestore).
///
/// This file is a member of BOTH the Runner app target and the widget
/// extension target. Conforming to `ForegroundContinuableIntent` (app target
/// only) forces the work to run in the app process where Flutter plugins —
/// including Firebase — are registered.
@available(iOS 17, *)
public struct CompleteFocusIntent: AppIntent {
    public static var title: LocalizedStringResource = "Mark Focus Done"
    public static var description = IntentDescription("Marks today's #1 focus complete.")

    public init() {}

    /// Must match `group.com.mindsetforge.mindsetforge` in the entitlements,
    /// `WidgetSyncService.appGroupId` (Dart), and `WidgetPayload.appGroupId`.
    /// Inlined here (rather than referencing `WidgetPayload`) because this file
    /// is a member of both the Runner app target and the widget extension, and
    /// `WidgetPayload` only exists in the widget extension.
    private static let appGroupId = "group.com.mindsetforge.mindsetforge"

    public func perform() async throws -> some IntentResult {
        await HomeWidgetBackgroundWorker.run(
            url: URL(string: "mindsetforge://completeFocus"),
            appGroup: Self.appGroupId
        )
        return .result()
    }
}

@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension CompleteFocusIntent: ForegroundContinuableIntent {}
