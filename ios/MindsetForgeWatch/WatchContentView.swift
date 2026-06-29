import SwiftUI

/// The watch glance: today's focus, streak, and a single "Mark done" action.
struct WatchContentView: View {
    @ObservedObject private var connectivity = WatchConnectivityProvider.shared

    var body: some View {
        let payload = connectivity.payload
        let accent = watchAccent(for: payload)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(payload.sessionLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(accent)
                        Spacer()
                        if payload.streak > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                Text("\(payload.streak)")
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(MFColors.warning)
                        }
                    }

                    Text(payload.glanceLine)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(MFColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !payload.subline.isEmpty {
                        Text(payload.subline)
                            .font(.system(size: 13))
                            .foregroundColor(MFColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if payload.totalCount > 0 {
                        ProgressView(value: Double(payload.completedCount),
                                     total: Double(payload.totalCount))
                            .tint(accent)
                        Text("\(payload.completedCount) of \(payload.totalCount) wins")
                            .font(.system(size: 12))
                            .foregroundColor(MFColors.textSecondary)
                    }

                    actionButton(payload: payload, accent: accent)
                }
                .padding(.vertical, 4)
            }
            .containerBackground(MFColors.background.gradient, for: .navigation)
            .navigationTitle("MindsetForge")
        }
    }

    private func watchAccent(for payload: WatchPayload) -> Color {
        switch payload.accentKind {
        case "morning": return MFColors.warning
        case "evening": return MFColors.secondary
        case "done": return MFColors.success
        default: return MFColors.primary
        }
    }

    @ViewBuilder
    private func actionButton(payload: WatchPayload, accent: Color) -> some View {
        if payload.canCompleteInWidget {
            // Today's Focus — the only action completable from the watch.
            Button {
                connectivity.completeFocus()
            } label: {
                Label("Mark Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .tint(accent)
            .padding(.top, 4)
        } else if payload.isDone {
            Label("Done for today", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(MFColors.success)
                .padding(.top, 4)
        } else {
            // Routine step — guide the user to finish it on the phone.
            Label("Open on iPhone", systemImage: "iphone")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(MFColors.textSecondary)
                .padding(.top, 4)
        }
    }
}
