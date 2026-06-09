import SwiftUI

enum WeekDisplayMode: String, CaseIterable, Identifiable {
    case all = "すべて"
    case onAndFree = "ON＋空き"
    case onOnly = "ONのみ"
    var id: String { rawValue }
}

struct FreeTimeMetric: View {
    let title: String
    let minutes: Int
    var prominent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(minutes.durationText)
                .font(prominent ? .system(size: 38, weight: .bold, design: .rounded) : .title3.bold())
                .contentTransition(.numericText())
        }
    }
}

struct DayTimeline: View {
    let date: Date
    let plans: [TimePlan]
    var mode: WeekDisplayMode = .all
    var showLabels = true
    var onSelectPlan: ((TimePlan) -> Void)?

    private let calendar = Calendar.current

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    }

                ForEach(plans) { plan in
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
                    let visibleStart = max(plan.start, dayStart)
                    let visibleEnd = min(plan.end, dayEnd)
                    let start = minutesSinceDayStart(visibleStart, dayStart: dayStart)
                    let end = minutesSinceDayStart(visibleEnd, dayStart: dayStart)
                    let width = max(2, geometry.size.width * CGFloat(end - start) / 1440)
                    let x = geometry.size.width * CGFloat(start) / 1440

                    Button {
                        onSelectPlan?(plan)
                    } label: {
                        ZStack {
                            if plan.kind == .off && mode != .all {
                                HiddenOffPattern()
                            } else {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(plan.kind == .off ? Color(.darkGray) : plan.color.swiftUIColor.opacity(0.85))
                            }

                            if showLabels, plan.kind == .on || mode == .all {
                                ViewThatFits(in: .horizontal) {
                                    Text(plan.title)
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
                        .frame(width: width, height: geometry.size.height)
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelectPlan == nil)
                    .offset(x: x)
                    .opacity(mode == .onOnly && plan.kind == .off ? 0.32 : 1)
                }

                ForEach([6, 12, 18], id: \.self) { hour in
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
}

struct TimelineHourScale: View {
    var body: some View {
        GeometryReader { geometry in
            ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
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

    private var urgencyColor: Color {
        let hours = task.deadline.timeIntervalSinceNow / 3600
        return hours < 24 ? .red : hours < 72 ? .orange : .secondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.body.weight(.semibold))
                    Text("\(task.category) ・ 残り\(task.remainingMinutes.durationText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(task.deadline.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(urgencyColor)
            }
            ProgressView(value: Double(task.completedMinutes), total: Double(max(1, task.estimatedMinutes)))
                .tint(urgencyColor)
        }
        .padding(.vertical, 5)
    }
}
