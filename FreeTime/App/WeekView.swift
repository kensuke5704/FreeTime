import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var anchor = Date.now
    @State private var displayMode: WeekDisplayMode = .all
    @State private var selectedPlan: TimePlan?
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

                HStack {
                    Spacer().frame(width: 48)
                    TimelineHourScale()
                }

                VStack(spacing: 10) {
                    ForEach(dates, id: \.self) { date in
                        weekRow(date)
                    }
                }

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
    }

    private func weekRow(_ date: Date) -> some View {
        let task = store.tasks
            .filter { Calendar.current.isDate($0.deadline, inSameDayAs: date) && !$0.isCompleted }
            .sorted { $0.deadline < $1.deadline }
            .first

        return HStack(spacing: 8) {
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
                .frame(width: 40, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                if let task {
                    Label(task.title, systemImage: "flag.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(task.deadline.timeIntervalSinceNow < 86_400 ? .red : .orange)
                        .lineLimit(1)
                }
                DayTimeline(
                    date: date,
                    plans: store.plans(on: date),
                    mode: displayMode
                ) { plan in
                    selectedPlan = plan
                }
                .frame(height: 48)
            }
            .padding(.vertical, 4)
            .background {
                if Calendar.current.isDateInToday(date) {
                    RoundedRectangle(cornerRadius: 9).fill(Color.blue.opacity(0.06))
                }
            }
        }
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
}
