import SwiftUI

struct NotePalette {
    let paper: Color
    let ink: Color
    let accent: Color

    private static let colors: [(lightPaper: UInt32, darkPaper: UInt32, lightAccent: UInt32, darkAccent: UInt32)] = [
        (0xEEEDFE, 0x26215C, 0x3C3489, 0xCECBF6),
        (0xE1F5EE, 0x04342C, 0x085041, 0x9FE1CB),
        (0xFAECE7, 0x4A1B0C, 0x712B13, 0xF5C4B3),
        (0xFAEEDA, 0x412402, 0x633806, 0xFAC775),
        (0xFBEAF0, 0x4B1528, 0x72243E, 0xF4C0D1),
        (0xE6F1FB, 0x042C53, 0x0C447C, 0xB5D4F4)
    ]

    static func forList(at index: Int, colorScheme: ColorScheme) -> NotePalette {
        let colors = colors[index]
        if colorScheme == .dark {
            return NotePalette(paper: rgb(colors.darkPaper), ink: rgb(colors.lightPaper), accent: rgb(colors.darkAccent))
        }
        return NotePalette(paper: rgb(colors.lightPaper), ink: rgb(colors.darkPaper), accent: rgb(colors.lightAccent))
    }

    private static func rgb(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 255) / 255,
            green: Double((hex >> 8) & 255) / 255,
            blue: Double(hex & 255) / 255
        )
    }
}
