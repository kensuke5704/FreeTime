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
                    let start = minute(of: plan.start)
                    let end = minute(of: plan.end)
                    let width = max(2, geometry.size.width * CGFloat(end - start) / 1440)
                    let x = geometry.size.width * CGFloat(start) / 1440

                    Button {
                        onSelectPlan?(plan)
                    } label: {
                        if plan.kind == .off && mode != .all {
                            HiddenOffPattern()
                        } else {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(plan.kind == .off ? Color(.darkGray) : plan.color.swiftUIColor.opacity(0.85))
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(onSelectPlan == nil)
                    .frame(width: width, height: geometry.size.height)
                    .offset(x: x)
                    .overlay(alignment: .leading) {
                        if showLabels, width > 38, plan.kind == .on || mode == .all {
                            Text(plan.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(plan.kind == .off ? .white : .white)
                                .lineLimit(1)
                                .padding(.leading, 4)
                        }
                    }
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

    private func minute(of date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

struct TimelineHourScale: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
                Text("\(hour)")
                    .frame(
                        maxWidth: .infinity,
                        alignment: hour == 0 ? .leading : hour == 24 ? .trailing : .center
                    )
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
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
