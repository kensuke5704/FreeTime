import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class FreeTimeStore: ObservableObject {
    @Published var plans: [TimePlan] = []
    @Published var tasks: [FreeTimeTask] = []
    @Published var templates: [RoutineTemplate] = []
    @Published private(set) var lastAutomaticBackupDate: Date?
    private var deletedTemplatePlanKeys: Set<String> = []

    private struct Payload: Codable {
        var plans: [TimePlan]
        var tasks: [FreeTimeTask]
        var templates: [RoutineTemplate]
        var deletedTemplatePlanKeys: Set<String>?
    }

    private struct BackupEnvelope: Codable {
        var version: Int
        var exportedAt: Date
        var payload: Payload
    }

    init() {
        lastAutomaticBackupDate = newestAutomaticBackupURL()
            .flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }

        if !load(), !loadLatestAutomaticBackup() {
            save()
        } else {
            applyAutomaticTemplates()
        }
    }

    func backupData() throws -> Data {
        let envelope = BackupEnvelope(
            version: 1,
            exportedAt: .now,
            payload: Payload(
                plans: plans,
                tasks: tasks,
                templates: templates,
                deletedTemplatePlanKeys: deletedTemplatePlanKeys
            )
        )
        return try JSONEncoder().encode(envelope)
    }

    func restoreBackup(from data: Data) throws {
        let payload: Payload
        if let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: data) {
            guard envelope.version == 1 else {
                throw BackupError.unsupportedVersion
            }
            payload = envelope.payload
        } else {
            payload = try JSONDecoder().decode(Payload.self, from: data)
        }

        plans = payload.plans
        tasks = payload.tasks
        templates = payload.templates
        deletedTemplatePlanKeys = payload.deletedTemplatePlanKeys ?? []
        applyAutomaticTemplates()
    }

    func add(_ plan: TimePlan) {
        plans.append(plan)
        save()
    }

    func update(_ plan: TimePlan) {
        guard let index = plans.firstIndex(where: { $0.id == plan.id }) else { return }
        plans[index] = plan
        save()
    }

    func delete(_ plan: TimePlan) {
        if let key = templatePlanKey(for: plan) {
            deletedTemplatePlanKeys.insert(key)
        }
        plans.removeAll { $0.id == plan.id }
        save()
    }

    func add(_ task: FreeTimeTask) {
        tasks.append(task)
        save()
    }

    func update(_ task: FreeTimeTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        for planIndex in plans.indices where plans[planIndex].taskID == task.id {
            plans[planIndex].title = task.title
        }
        save()
    }

    func delete(_ task: FreeTimeTask) {
        tasks.removeAll { $0.id == task.id }
        plans.removeAll { $0.taskID == task.id }
        save()
    }

    func add(_ template: RoutineTemplate) {
        templates.append(template)
        apply(template, replacingExisting: false)
        save()
    }

    func update(_ template: RoutineTemplate) {
        guard let index = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[index] = template
        apply(template, replacingExisting: true)
        save()
    }

    func delete(_ template: RoutineTemplate) {
        templates.removeAll { $0.id == template.id }
        deletedTemplatePlanKeys = deletedTemplatePlanKeys.filter {
            !$0.hasPrefix("\(template.id.uuidString)|")
        }
        plans.removeAll {
            $0.sourceTemplateID == template.id && $0.start >= Calendar.current.startOfDay(for: .now)
        }
        save()
    }

    func apply(_ template: RoutineTemplate) {
        apply(template, replacingExisting: false)
        save()
    }

    func addTaskPlans(task: FreeTimeTask, intervals: [DateInterval], addTask: Bool = false) {
        if addTask {
            tasks.append(task)
        }
        for interval in intervals {
            plans.append(TimePlan(
                title: task.title,
                start: interval.start,
                end: interval.end,
                kind: .on,
                color: .blue,
                taskID: task.id
            ))
        }
        save()
    }

    func scheduledMinutes(for task: FreeTimeTask) -> Int {
        let intervals = plans
            .filter { $0.taskID == task.id && $0.end > $0.start }
            .map { DateInterval(start: $0.start, end: $0.end) }
            .sorted { $0.start < $1.start }

        var merged: [DateInterval] = []
        for interval in intervals {
            if let last = merged.last, interval.start <= last.end {
                merged[merged.count - 1] = DateInterval(
                    start: last.start,
                    end: max(last.end, interval.end)
                )
            } else {
                merged.append(interval)
            }
        }

        return merged.reduce(0) {
            $0 + Int($1.duration / 60)
        }
    }

    func progressMinutes(for task: FreeTimeTask) -> Int {
        min(task.estimatedMinutes, task.completedMinutes + scheduledMinutes(for: task))
    }

    func remainingMinutes(for task: FreeTimeTask) -> Int {
        max(0, task.estimatedMinutes - progressMinutes(for: task))
    }

    func plans(on date: Date) -> [TimePlan] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return plans.filter { $0.start < dayEnd && $0.end > dayStart }
            .sorted { $0.start < $1.start }
    }

    func freeMinutes(on date: Date) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let ranges = plans(on: date)
            .map { max($0.start, dayStart)..<min($0.end, dayEnd) }
            .filter { $0.lowerBound < $0.upperBound }
            .sorted { $0.lowerBound < $1.lowerBound }

        var merged: [Range<Date>] = []
        for range in ranges {
            if let last = merged.last, range.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
            } else {
                merged.append(range)
            }
        }
        let occupied = merged.reduce(0) {
            $0 + Int($1.upperBound.timeIntervalSince($1.lowerBound) / 60)
        }
        return max(0, 24 * 60 - occupied)
    }

    func weekDates(containing date: Date) -> [Date] {
        let calendar = mondayFirstCalendar
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let start = interval?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func availableSlots(before deadline: Date, minimumMinutes: Int = 30) -> [DateInterval] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: .now)
        let lastDay = calendar.startOfDay(for: deadline)
        guard deadline > .now else { return [] }
        let dayCount = max(0, calendar.dateComponents([.day], from: startDay, to: lastDay).day ?? 0)

        return (0...dayCount).flatMap { offset -> [DateInterval] in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { return [] }
            let dayEnd = min(
                calendar.date(byAdding: .day, value: 1, to: date) ?? deadline,
                deadline
            )
            let lower = offset == 0 ? max(.now, date) : date
            guard lower < dayEnd else { return [] }
            let busy = plans(on: date).compactMap { plan -> DateInterval? in
                let start = max(plan.start, date)
                let end = min(plan.end, dayEnd)
                guard start < end else { return nil }
                return DateInterval(start: start, end: end)
            }
                .sorted { $0.start < $1.start }
            var cursor = lower
            var slots: [DateInterval] = []
            for interval in busy where interval.end > lower && interval.start < dayEnd {
                if interval.start.timeIntervalSince(cursor) >= Double(minimumMinutes * 60) {
                    slots.append(DateInterval(start: cursor, end: interval.start))
                }
                cursor = max(cursor, interval.end)
            }
            if dayEnd.timeIntervalSince(cursor) >= Double(minimumMinutes * 60) {
                slots.append(DateInterval(start: cursor, end: dayEnd))
            }
            return slots
        }
    }

    private func applyAutomaticTemplates() {
        for template in templates where template.automaticallyApplies {
            apply(template, replacingExisting: false)
        }
        save()
    }

    private func apply(_ template: RoutineTemplate, replacingExisting: Bool) {
        let calendar = mondayFirstCalendar
        let today = calendar.startOfDay(for: .now)

        if replacingExisting {
            plans.removeAll {
                $0.sourceTemplateID == template.id && $0.start >= today
            }
        }

        let firstDay = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let dayCount = 8 * 7

        for offset in 0..<dayCount {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            guard template.weekdays.contains(weekday) else { continue }

            for item in template.items {
                guard
                    let start = calendar.date(byAdding: .minute, value: item.startMinute, to: day),
                    let end = calendar.date(byAdding: .minute, value: item.endMinute, to: day)
                else { continue }

                let alreadyExists = plans.contains {
                    $0.sourceTemplateID == template.id
                        && $0.sourceTemplateItemID == item.id
                        && calendar.isDate($0.start, inSameDayAs: day)
                }
                let deletionKey = templatePlanKey(
                    templateID: template.id,
                    itemID: item.id,
                    date: day
                )
                guard !alreadyExists, !deletedTemplatePlanKeys.contains(deletionKey) else { continue }

                plans.append(TimePlan(
                    title: item.title,
                    start: start,
                    end: end,
                    kind: item.kind,
                    color: item.color,
                    sourceTemplateID: template.id,
                    sourceTemplateItemID: item.id
                ))
            }
        }
    }

    func save() {
        let payload = Payload(
            plans: plans,
            tasks: tasks,
            templates: templates,
            deletedTemplatePlanKeys: deletedTemplatePlanKeys
        )
        if let data = try? JSONEncoder().encode(payload) {
            SharedDefaults.defaults.set(data, forKey: SharedDefaults.storeKey)
        }
        saveAutomaticBackup(payload)
        updateWidgetSnapshot()
    }

    private func load() -> Bool {
        guard
            let data = SharedDefaults.defaults.data(forKey: SharedDefaults.storeKey),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return false }
        plans = payload.plans
        tasks = payload.tasks
        templates = payload.templates
        deletedTemplatePlanKeys = payload.deletedTemplatePlanKeys ?? []
        return true
    }

    private func saveAutomaticBackup(_ payload: Payload) {
        let envelope = BackupEnvelope(version: 1, exportedAt: .now, payload: payload)
        guard let data = try? JSONEncoder().encode(envelope) else { return }

        do {
            let directory = try automaticBackupDirectory()
            let timestamp = Int(Date.now.timeIntervalSince1970 * 1_000)
            let url = directory.appendingPathComponent("FreeTime-\(timestamp).json")
            try data.write(to: url, options: .atomic)
            lastAutomaticBackupDate = .now
            pruneAutomaticBackups(in: directory)
        } catch {
            // The primary app data remains available even if a backup write fails.
        }
    }

    private func loadLatestAutomaticBackup() -> Bool {
        guard
            let url = newestAutomaticBackupURL(),
            let data = try? Data(contentsOf: url),
            let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: data),
            envelope.version == 1
        else {
            return false
        }

        plans = envelope.payload.plans
        tasks = envelope.payload.tasks
        templates = envelope.payload.templates
        deletedTemplatePlanKeys = envelope.payload.deletedTemplatePlanKeys ?? []
        lastAutomaticBackupDate = envelope.exportedAt
        return true
    }

    private func automaticBackupDirectory() throws -> URL {
        let root = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = root.appendingPathComponent("AutomaticBackups", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func newestAutomaticBackupURL() -> URL? {
        guard
            let directory = try? automaticBackupDirectory(),
            let urls = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return nil
        }

        return urls
            .filter { $0.pathExtension == "json" }
            .sorted { modificationDate(of: $0) > modificationDate(of: $1) }
            .first
    }

    private func pruneAutomaticBackups(in directory: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        let oldBackups = urls
            .filter { $0.pathExtension == "json" }
            .sorted { modificationDate(of: $0) > modificationDate(of: $1) }
            .dropFirst(10)

        for url in oldBackups {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func modificationDate(of url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }

    private func updateWidgetSnapshot() {
        let upcoming = plans
            .filter { $0.start > .now && Calendar.current.isDateInToday($0.start) }
            .sorted { $0.start < $1.start }
            .first
        let snapshot = WidgetSnapshot(
            generatedAt: .now,
            freeMinutes: freeMinutes(on: .now),
            nextTitle: upcoming?.title,
            nextStart: upcoming?.start,
            onPlans: plans
                .filter { $0.kind == .on && $0.end > .now }
                .sorted { $0.start < $1.start }
                .prefix(100)
                .map {
                    WidgetPlanSnapshot(title: $0.title, start: $0.start, end: $0.end)
                }
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            SharedDefaults.defaults.set(data, forKey: SharedDefaults.snapshotKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private var mondayFirstCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func templatePlanKey(for plan: TimePlan) -> String? {
        guard
            let templateID = plan.sourceTemplateID,
            let itemID = plan.sourceTemplateItemID
        else {
            return nil
        }
        return templatePlanKey(templateID: templateID, itemID: itemID, date: plan.start)
    }

    private func templatePlanKey(templateID: UUID, itemID: UUID, date: Date) -> String {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(templateID.uuidString)|\(itemID.uuidString)|\(day.year ?? 0)-\(day.month ?? 0)-\(day.day ?? 0)"
    }

}

private enum BackupError: LocalizedError {
    case unsupportedVersion

    var errorDescription: String? {
        "このバックアップは現在のバージョンでは読み込めません。"
    }
}
