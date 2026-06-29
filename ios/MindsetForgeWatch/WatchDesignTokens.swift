import SwiftUI

/// MindShift palette for watchOS (mirrors `AppColors`). Separate from the iOS
/// widget copy so each target compiles independently.
enum MFColors {
    static let background = Color(hex: 0x0A0A0F)
    static let surfaceElevated = Color(hex: 0x1C1C27)
    static let border = Color(hex: 0x2A2A3A)
    static let primary = Color(hex: 0x9B40FF)
    static let secondary = Color(hex: 0x00E5FF)
    static let warning = Color(hex: 0xFFB547)
    static let success = Color(hex: 0x4CAF7D)
    static let textPrimary = Color(hex: 0xF0EFF8)
    static let textSecondary = Color(hex: 0x8B8BA0)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}
