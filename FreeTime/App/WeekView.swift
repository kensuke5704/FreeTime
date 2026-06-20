import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var anchor = Date.now
    @State private var displayMode: WeekDisplayMode = .all
    @State private var selectedPlan: TimePlan?
    @State private var addInitialStart = Date.now
    @State private var isAddingFromTimeline = false
    @State private var timelineScale: CGFloat = 1
    let openAdd: () -> Void

    private var dates: [Date] { store.weekDates(containing: anchor) }
    private var weekFreeMinutes: Int { dates.reduce(0) { $0 + store.freeMinutes(on: $1) } }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Button {
                        anchor = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: anchor) ?? anchor
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text(weekRangeText)
                            .font(.headline)
                        Text("空き時間 \(weekFreeMinutes.durationText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        anchor = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: anchor) ?? anchor
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                Picker("表示", selection: $displayMode) {
                    ForEach(WeekDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                GeometryReader { geometry in
                    let baseTimelineWidth = max(280, geometry.size.width - 48)
                    let timelineWidth = baseTimelineWidth * timelineScale

                    HStack(spacing: 8) {
                        VStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    timelineScale = timelineScale == 1 ? 3 : 1
                                }
                            } label: {
                                Image(systemName: timelineScale == 1
                                      ? "magnifyingglass"
                                      : "magnifyingglass.circle.fill")
                                    .frame(width: 40, height: 24)
                                    .background(Color(.systemBackground))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .accessibilityLabel(timelineScale == 1 ? "3倍に拡大" : "元の大きさに戻す")

                            ForEach(dates, id: \.self) { date in
                                dateCell(date)
                            }
                        }
                        .frame(width: 40)

                        ScrollView(.horizontal, showsIndicators: timelineScale > 1) {
                            VStack(spacing: 10) {
                                TimelineHourScale(interval: timelineScale == 1 ? 6 : 2)
                                    .frame(width: timelineWidth)

                                ForEach(dates, id: \.self) { date in
                                    timelineRow(date, timelineWidth: timelineWidth)
                                }
                            }
                            .frame(width: timelineWidth, alignment: .leading)
                        }
                        .scrollDisabled(timelineScale == 1)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 40)
                            .onEnded { value in
                                guard timelineScale == 1 else { return }
                                if value.translation.width < -50 {
                                    moveWeek(by: 1)
                                } else if value.translation.width > 50 {
                                    moveWeek(by: -1)
                                }
                            }
                    )
                }
                .frame(height: 24 + (68 * 7) + (10 * 7))

                legend
            }
            .padding()
            .padding(.bottom, 72)
        }
        .navigationTitle("週間")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("今日") { anchor = .now }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            AddButton(action: openAdd)
                .padding()
        }
        .sheet(item: $selectedPlan) { plan in
            PlanEditorView(plan: plan)
        }
        .sheet(isPresented: $isAddingFromTimeline) {
            PlanEditorView(initialStart: addInitialStart)
        }
    }

    private func dateCell(_ date: Date) -> some View {
        NavigationLink {
            DayPlansView(date: date)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(date.weekday3Text)
                    .font(.caption.weight(.semibold))
                Text(date.formatted(.dateTime.day()))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .primary)
            }
            .frame(width: 40, height: 68, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func timelineRow(_ date: Date, timelineWidth: CGFloat) -> some View {
        let task = store.tasks
            .filter {
                guard let deadline = $0.deadline else { return false }
                return Calendar.current.isDate(deadline, inSameDayAs: date) && !$0.isCompleted
            }
            .sorted { $0.deadlineSortValue < $1.deadlineSortValue }
            .first

        return VStack(alignment: .leading, spacing: 4) {
            if let task {
                Label(task.title, systemImage: "flag.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle((task.deadline?.timeIntervalSinceNow ?? .infinity) < 86_400 ? .red : .orange)
                    .lineLimit(1)
            }
            DayTimeline(
                date: date,
                plans: store.plans(on: date),
                mode: displayMode,
                hourGridInterval: timelineScale == 1 ? 6 : 2,
                onSelectPlan: { plan in
                    selectedPlan = plan
                },
                onSelectEmptyTime: { date in
                    addInitialStart = date
                    isAddingFromTimeline = true
                }
            )
            .frame(width: timelineWidth, height: 48)
        }
        .padding(.vertical, 4)
        .background {
            if Calendar.current.isDateInToday(date) {
                RoundedRectangle(cornerRadius: 9).fill(Color.blue.opacity(0.06))
            }
        }
        .frame(width: timelineWidth, height: 68, alignment: .leading)
    }

    private var legend: some View {
        HStack(spacing: 18) {
            Label("ON", systemImage: "square.fill").foregroundStyle(.blue)
            Label("空き時間", systemImage: "square").foregroundStyle(.primary)
            HStack(spacing: 5) {
                HiddenOffPattern().frame(width: 16, height: 16)
                Text("非表示のOFF")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var weekRangeText: String {
        guard let first = dates.first, let last = dates.last else { return "" }
        return "\(first.formatted(.dateTime.month().day()))–\(last.formatted(.dateTime.month().day()))"
    }

    private func moveWeek(by value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            anchor = Calendar.current.date(byAdding: .weekOfYear, value: value, to: anchor) ?? anchor
        }
    }
}
