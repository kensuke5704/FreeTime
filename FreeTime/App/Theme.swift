import SwiftUI

extension PlanColor {
    var swiftUIColor: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .purple: .purple
        }
    }

    var accessibilityName: String {
        switch self {
        case .blue: "青"
        case .green: "緑"
        case .orange: "オレンジ"
        case .purple: "紫"
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
