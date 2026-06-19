import Foundation

enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case on = "ON"
    case off = "OFF"

    var id: String { rawValue }
}

enum PlanColor: String, Codable, CaseIterable, Identifiable {
    case blue, green, orange, purple
    case red, pink, yellow, teal, cyan, indigo, mint, brown

    var id: String { rawValue }
}

struct TimePlan: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var start: Date
    var end: Date
    var kind: PlanKind
    var color: PlanColor = .blue
    var memo = ""
    var taskID: UUID?
    var sourceTemplateID: UUID?
    var sourceTemplateItemID: UUID?
}

struct FreeTimeTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var category: String
    var deadline: Date?
    var estimatedMinutes: Int
    var completedMinutes: Int = 0
    var priority: Int = 1
    var color: PlanColor = .blue
    var memo = ""
    var isCompleted = false

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        deadline: Date?,
        estimatedMinutes: Int,
        completedMinutes: Int = 0,
        priority: Int = 1,
        color: PlanColor = .blue,
        memo: String = "",
        isCompleted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.deadline = deadline
        self.estimatedMinutes = estimatedMinutes
        self.completedMinutes = completedMinutes
        self.priority = priority
        self.color = color
        self.memo = memo
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, category, deadline, estimatedMinutes, completedMinutes
        case priority, color, memo, isCompleted
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(String.self, forKey: .category)
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        estimatedMinutes = try container.decode(Int.self, forKey: .estimatedMinutes)
        completedMinutes = try container.decodeIfPresent(Int.self, forKey: .completedMinutes) ?? 0
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 1
        color = try container.decodeIfPresent(PlanColor.self, forKey: .color) ?? .blue
        memo = try container.decodeIfPresent(String.self, forKey: .memo) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(deadline, forKey: .deadline)
        try container.encode(estimatedMinutes, forKey: .estimatedMinutes)
        try container.encode(completedMinutes, forKey: .completedMinutes)
        try container.encode(priority, forKey: .priority)
        try container.encode(color, forKey: .color)
        try container.encode(memo, forKey: .memo)
        try container.encode(isCompleted, forKey: .isCompleted)
    }

    var remainingMinutes: Int {
        max(0, estimatedMinutes - completedMinutes)
    }

    var deadlineSortValue: Date {
        deadline ?? .distantFuture
    }

    var deadlineText: String {
        deadline?.formatted(.dateTime.month().day().hour().minute()) ?? "無期限"
    }
}

struct RoutineTemplate: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var weekdays: Set<Int>
    var items: [TemplateItem]
    var automaticallyApplies = true
}

struct TemplateItem: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var startMinute: Int
    var endMinute: Int
    var kind: PlanKind = .off
    var color: PlanColor = .blue

    init(
        id: UUID = UUID(),
        title: String,
        startMinute: Int,
        endMinute: Int,
        kind: PlanKind = .off,
        color: PlanColor = .blue
    ) {
        self.id = id
        self.title = title
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.kind = kind
        self.color = color
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, startMinute, endMinute, kind, color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        kind = try container.decodeIfPresent(PlanKind.self, forKey: .kind) ?? .off
        color = try container.decodeIfPresent(PlanColor.self, forKey: .color) ?? .blue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(endMinute, forKey: .endMinute)
        try container.encode(kind, forKey: .kind)
        try container.encode(color, forKey: .color)
    }
}

struct WidgetSnapshot: Codable {
    var generatedAt: Date
    var freeMinutes: Int
    var nextTitle: String?
    var nextStart: Date?
    var onPlans: [WidgetPlanSnapshot]?

    static let placeholder = WidgetSnapshot(
        generatedAt: .now,
        freeMinutes: 405,
        nextTitle: "課題",
        nextStart: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now),
        onPlans: [
            WidgetPlanSnapshot(
                title: "課題",
                start: .today(hour: 18),
                end: .today(hour: 19)
            ),
            WidgetPlanSnapshot(
                title: "ジム",
                start: .today(hour: 20),
                end: .today(hour: 21)
            )
        ]
    )
}

struct WidgetPlanSnapshot: Codable, Hashable {
    var title: String
    var start: Date
    var end: Date
}

enum SharedDefaults {
    static let appGroup = "group.com.kensuke5704.FreeTime"
    static let snapshotKey = "widgetSnapshot"
    static let storeKey = "freeTimeStore"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }
}

extension Date {
    static func today(hour: Int, minute: Int = 0, dayOffset: Int = 0) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: .now)) ?? .now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

extension Int {
    var durationText: String {
        let hours = self / 60
        let minutes = self % 60
        if hours == 0 { return "\(minutes)分" }
        if minutes == 0 { return "\(hours)時間" }
        return "\(hours)時間\(minutes)分"
    }
}
