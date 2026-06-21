import SwiftUI
import UIKit

enum WeekDisplayMode: String, CaseIterable, Identifiable {
    case all = "すべて"
    case onAndFree = "ON＋空き"
    var id: String { rawValue }
}

struct FreeTimeMetric: View {
    let title: String
    let minutes: Int
    var prominent = false
    var splitsHoursAndMinutes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            if splitsHoursAndMinutes {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(minutes / 60)時間")
                    Text("\(minutes % 60)分")
                }
                .font(prominent ? .system(size: 38, weight: .bold, design: .rounded) : .title3.bold())
                .contentTransition(.numericText())
            } else {
                Text(minutes.durationText)
                    .font(prominent ? .system(size: 38, weight: .bold, design: .rounded) : .title3.bold())
                    .contentTransition(.numericText())
            }
        }
    }
}

struct DayTimeline: View {
    let date: Date
    let plans: [TimePlan]
    var mode: WeekDisplayMode = .all
    var showLabels = true
    var hourGridInterval = 6
    var onSelectPlan: ((TimePlan) -> Void)?
    var onSelectEmptyTime: ((Date) -> Void)?

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        guard let onSelectEmptyTime, geometry.size.width > 0 else { return }
                        let fraction = min(1, max(0, location.x / geometry.size.width))
                        let minute = min(1435, Int((fraction * 1440) / 5) * 5)
                        let dayStart = calendar.startOfDay(for: date)
                        if let selectedDate = calendar.date(
                            byAdding: .minute,
                            value: minute,
                            to: dayStart
                        ) {
                            guard !plans.contains(where: {
                                selectedDate >= $0.start && selectedDate < $0.end
                            }) else { return }
                            onSelectEmptyTime(startOfFreeInterval(containing: selectedDate))
                        }
                    }

                ForEach(timelineItems) { item in
                    let width = max(
                        2,
                        geometry.size.width * CGFloat(item.endMinute - item.startMinute) / 1440
                    )
                    let x = geometry.size.width * CGFloat(item.startMinute) / 1440
                    let spacing: CGFloat = item.laneCount > 1 ? 2 : 0
                    let availableHeight = geometry.size.height - spacing * CGFloat(item.laneCount - 1)
                    let height = availableHeight / CGFloat(item.laneCount)
                    let y = CGFloat(item.lane) * (height + spacing)

                    Button {
                        onSelectPlan?(item.plan)
                    } label: {
                        ZStack {
                            if item.plan.kind == .off && mode != .all {
                                HiddenOffPattern()
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        item.plan.kind == .off
                                            ? Color(.darkGray)
                                            : item.plan.color.swiftUIColor.opacity(0.85)
                                    )
                            }

                            if showLabels, item.plan.kind == .on || mode == .all {
                                ViewThatFits(in: .horizontal) {
                                    Text(item.plan.title)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)

                                    Color.clear
                                        .frame(width: 0, height: 0)
                                }
                                .padding(.horizontal, 4)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .frame(width: width, height: height)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelectPlan == nil)
                    .offset(x: x, y: y)
                }

                ForEach(Array(stride(from: hourGridInterval, to: 24, by: hourGridInterval)), id: \.self) { hour in
                    Rectangle()
                        .fill(Color(.separator).opacity(0.45))
                        .frame(width: 0.5)
                        .offset(x: geometry.size.width * CGFloat(hour) / 24)
                }
            }
        }
    }

    private func minutesSinceDayStart(_ date: Date, dayStart: Date) -> Int {
        max(0, min(1440, Int(date.timeIntervalSince(dayStart) / 60)))
    }

    private func startOfFreeInterval(containing selectedDate: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        return plans
            .filter { $0.end > dayStart && $0.end <= selectedDate }
            .map(\.end)
            .max() ?? dayStart
    }

    private var timelineItems: [TimelineItem] {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let visiblePlans = plans.compactMap { plan -> VisiblePlan? in
            let start = max(plan.start, dayStart)
            let end = min(plan.end, dayEnd)
            guard start < end else { return nil }
            return VisiblePlan(plan: plan, start: start, end: end)
        }
        .sorted {
            if $0.start == $1.start {
                return $0.end < $1.end
            }
            return $0.start < $1.start
        }

        var result: [TimelineItem] = []
        var overlapGroup: [VisiblePlan] = []
        var groupEnd = Date.distantPast

        for visiblePlan in visiblePlans {
            if !overlapGroup.isEmpty, visiblePlan.start >= groupEnd {
                result.append(contentsOf: makeTimelineItems(overlapGroup, dayStart: dayStart))
                overlapGroup.removeAll(keepingCapacity: true)
                groupEnd = .distantPast
            }
            overlapGroup.append(visiblePlan)
            groupEnd = max(groupEnd, visiblePlan.end)
        }

        result.append(contentsOf: makeTimelineItems(overlapGroup, dayStart: dayStart))
        return result
    }

    private func makeTimelineItems(_ group: [VisiblePlan], dayStart: Date) -> [TimelineItem] {
        guard !group.isEmpty else { return [] }

        var laneEnds: [Date] = []
        var assignments: [(visiblePlan: VisiblePlan, lane: Int)] = []

        for visiblePlan in group {
            let lane: Int
            if let availableLane = laneEnds.firstIndex(where: { $0 <= visiblePlan.start }) {
                lane = availableLane
                laneEnds[availableLane] = visiblePlan.end
            } else {
                lane = laneEnds.count
                laneEnds.append(visiblePlan.end)
            }
            assignments.append((visiblePlan, lane))
        }

        let laneCount = laneEnds.count
        return assignments.map {
            TimelineItem(
                plan: $0.visiblePlan.plan,
                startMinute: minutesSinceDayStart($0.visiblePlan.start, dayStart: dayStart),
                endMinute: minutesSinceDayStart($0.visiblePlan.end, dayStart: dayStart),
                lane: $0.lane,
                laneCount: laneCount
            )
        }
    }

    private struct VisiblePlan {
        let plan: TimePlan
        let start: Date
        let end: Date
    }

    private struct TimelineItem: Identifiable {
        let plan: TimePlan
        let startMinute: Int
        let endMinute: Int
        let lane: Int
        let laneCount: Int

        var id: UUID { plan.id }
    }
}

struct FiveMinuteDatePicker: View {
    enum Mode {
        case dateAndTime
        case time
    }

    let title: String
    @Binding var selection: Date
    var range: ClosedRange<Date>?
    var displayedComponents: Mode = .dateAndTime

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            FiveMinuteDatePickerControl(
                selection: $selection,
                range: range,
                mode: displayedComponents
            )
            .frame(minWidth: displayedComponents == .time ? 92 : 190, minHeight: 34)
        }
    }
}

private struct FiveMinuteDatePickerControl: UIViewRepresentable {
    @Binding var selection: Date
    let range: ClosedRange<Date>?
    let mode: FiveMinuteDatePicker.Mode

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.preferredDatePickerStyle = .compact
        picker.minuteInterval = 5
        picker.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.datePickerMode = mode == .time ? .time : .dateAndTime
        picker.minuteInterval = 5
        picker.minimumDate = range?.lowerBound
        picker.maximumDate = range?.upperBound

        let roundedSelection = selection.roundedDownToFiveMinutes
        if selection != roundedSelection {
            DispatchQueue.main.async {
                selection = roundedSelection
            }
        }
        if abs(picker.date.timeIntervalSince(roundedSelection)) > 0.5 {
            picker.setDate(roundedSelection, animated: false)
        }
    }

    final class Coordinator: NSObject {
        @Binding private var selection: Date

        init(selection: Binding<Date>) {
            _selection = selection
        }

        @objc func valueChanged(_ sender: UIDatePicker) {
            selection = sender.date.roundedDownToFiveMinutes
        }
    }
}

private extension Date {
    var roundedDownToFiveMinutes: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: self
        )
        var rounded = components
        rounded.minute = ((components.minute ?? 0) / 5) * 5
        rounded.second = 0
        return calendar.date(from: rounded) ?? self
    }
}

struct TimelineHourScale: View {
    var interval = 6

    var body: some View {
        GeometryReader { geometry in
            ForEach(Array(stride(from: 0, through: 24, by: interval)), id: \.self) { hour in
                Text("\(hour)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .position(
                        x: min(
                            geometry.size.width - 14,
                            max(14, geometry.size.width * CGFloat(hour) / 24)
                        ),
                        y: geometry.size.height / 2
                    )
            }
        }
        .frame(height: 16)
    }
}

struct HiddenOffPattern: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(.systemGray6)))
            var path = Path()
            for x in stride(from: -size.height, through: size.width, by: 8) {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
            }
            context.stroke(path, with: .color(Color(.systemGray4)), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct TaskRow: View {
    let task: FreeTimeTask
    var scheduledMinutes = 0

    private var progressMinutes: Int {
        min(task.estimatedMinutes, task.completedMinutes + scheduledMinutes)
    }

    private var remainingMinutes: Int {
        max(0, task.estimatedMinutes - progressMinutes)
    }

    private var urgencyColor: Color {
        guard let deadline = task.deadline else { return .secondary }
        let hours = deadline.timeIntervalSinceNow / 3600
        return hours < 24 ? .red : hours < 72 ? .orange : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(task.color.swiftUIColor)
                            .frame(width: 11, height: 11)
                        Text(task.title).font(.body.weight(.semibold))
                    }
                    Text("\(task.category) ・ 残り\(remainingMinutes.durationText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(task.deadlineText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(urgencyColor)
            }
            ProgressView(value: Double(progressMinutes), total: Double(max(1, task.estimatedMinutes)))
                .tint(task.color.swiftUIColor)
        }
        .padding(.vertical, 5)
    }
}
