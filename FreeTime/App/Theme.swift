import SwiftUI

extension PlanColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: Color(red: 0.00, green: 0.42, blue: 1.00)
        case .green: Color(red: 0.00, green: 0.72, blue: 0.32)
        case .orange: Color(red: 1.00, green: 0.42, blue: 0.00)
        case .purple: Color(red: 0.66, green: 0.22, blue: 1.00)
        case .red: Color(red: 1.00, green: 0.12, blue: 0.18)
        case .pink: Color(red: 1.00, green: 0.12, blue: 0.55)
        case .yellow: Color(red: 1.00, green: 0.78, blue: 0.00)
        case .teal: Color(red: 0.00, green: 0.68, blue: 0.64)
        case .cyan: Color(red: 0.00, green: 0.70, blue: 0.95)
        case .indigo: Color(red: 0.25, green: 0.22, blue: 0.92)
        case .mint: Color(red: 0.00, green: 0.82, blue: 0.60)
        case .brown: Color(red: 0.68, green: 0.32, blue: 0.10)
        }
    }

    var accessibilityName: String {
        switch self {
        case .blue: "青"
        case .green: "緑"
        case .orange: "オレンジ"
        case .purple: "紫"
        case .red: "赤"
        case .pink: "ピンク"
        case .yellow: "黄"
        case .teal: "ティール"
        case .cyan: "シアン"
        case .indigo: "インディゴ"
        case .mint: "ミント"
        case .brown: "茶"
        }
    }
}

extension Date {
    var timeText: String {
        formatted(date: .omitted, time: .shortened)
    }

    var shortDateText: String {
        formatted(.dateTime.month(.defaultDigits).day().weekday(.short))
    }

    var weekday3Text: String {
        formatted(
            .dateTime
                .weekday(.abbreviated)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
        .uppercased()
    }
}
