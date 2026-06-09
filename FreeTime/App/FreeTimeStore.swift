import Foundation
import SwiftUI
import WidgetKit

@MainActor
final class FreeTimeStore: ObservableObject {
    @Published var plans: [TimePlan] = []
    @Published var tasks: [FreeTimeTask] = []
    @Published var templates: [RoutineTemplate] = []

    private struct Payload: Codable {
        var plans: [TimePlan]
        var tasks: [FreeTimeTask]
        var templates: [RoutineTemplate]
    }

    init() {
        if !load() {
            save()
        } else {
            applyAutomaticTemplates()
        }
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
        plans.removeAll {
            $0.sourceTemplateID == template.id && $0.start >= Calendar.current.startOfDay(for: .now)
        }
        save()
    }

    func apply(_ template: RoutineTemplate) {
        apply(template, replacingExisting: false)
        save()
    }

    func addTaskPlan(task: FreeTimeTask, start: Date, end: Date) {
        plans.append(TimePlan(
            title: task.title,
            start: start,
            end: end,
            kind: .on,
            color: .blue,
            taskID: task.id
        ))
        save()
    }

    func plans(on date: Date) -> [TimePlan] {
        plans.filter { Calendar.current.isDate($0.start, inSameDayAs: date) }
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
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        let start = interval?.start ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    func availableSlots(before deadline: Date, minimumMinutes: Int = 30) -> [DateInterval] {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: .now)
        let lastDay = calendar.startOfDay(for: deadline)
        let dayCount = max(0, calendar.dateComponents([.day], from: startDay, to: lastDay).day ?? 0)

        return (0...dayCount).flatMap { offset -> [DateInterval] in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDay) else { return [] }
            let dayEnd = min(
                calendar.date(byAdding: .day, value: 1, to: date) ?? deadline,
                deadline
            )
            let lower = offset == 0 ? max(.now, date) : date
            let busy = plans(on: date).map { DateInterval(start: $0.start, end: $0.end) }
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
        let calendar = Calendar.current
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
                guard !alreadyExists else { continue }

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
        let payload = Payload(plans: plans, tasks: tasks, templates: templates)
        if let data = try? JSONEncoder().encode(payload) {
            SharedDefaults.defaults.set(data, forKey: SharedDefaults.storeKey)
        }
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
        return true
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
            nextStart: upcoming?.start
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            SharedDefaults.defaults.set(data, forKey: SharedDefaults.snapshotKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

}
