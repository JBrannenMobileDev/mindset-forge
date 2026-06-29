import SwiftUI

/// MindShift design-system colors ported from `AppColors` (lib/core/constants).
/// Kept in sync manually since the widget extension cannot import Dart tokens.
enum MFColors {
    static let background = Color(hex: 0x0A0A0F)
    static let surface = Color(hex: 0x13131A)
    static let surfaceElevated = Color(hex: 0x1C1C27)
    static let surfaceHighest = Color(hex: 0x252535)
    static let border = Color(hex: 0x2A2A3A)
    static let primary = Color(hex: 0x9B40FF)
    // Brightened variants for text/icons sitting on the accent gradient, where
    // the base accent would be too low-contrast.
    static let primaryBright = Color(hex: 0xC9A0FF)
    static let secondary = Color(hex: 0x00E5FF)
    static let warning = Color(hex: 0xFFB547)
    static let error = Color(hex: 0xFF5E6C)
    static let success = Color(hex: 0x4CAF7D)
    static let successBright = Color(hex: 0x7DDCA8)
    static let textPrimary = Color(hex: 0xF0EFF8)
    static let textSecondary = Color(hex: 0x8B8BA0)
    static let textMuted = Color(hex: 0x4A4A60)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
