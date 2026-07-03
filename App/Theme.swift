import SwiftUI

enum Theme {
    static let cream = Color(red: 1.0, green: 0.965, blue: 0.91)
    static let ink = Color(red: 0.137, green: 0.153, blue: 0.20)
    static let flame = Color(red: 0.969, green: 0.718, blue: 0.20)
    static let faded = ink.opacity(0.55)

    static func font(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
