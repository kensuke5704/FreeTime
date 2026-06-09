import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var anchor = Date.now

    private var dates: [Date] { store.weekDates(containing: anchor) }
    private struct DailyValue: Identifiable {
        let date: Date
        let minutes: Int
        var id: Date { date }
    }

    private var values: [DailyValue] {
        dates.map { DailyValue(date: $0, minutes: store.freeMinutes(on: $0)) }
    }
    private var weekMinutes: Int { values.reduce(0) { $0 + $1.minutes } }
    private var weekPlans: [TimePlan] {
        var result: [TimePlan] = []
        for date in dates {
            result.append(contentsOf: store.plans(on: date))
        }
        return result
    }
    private var onMinutes: Int {
        minutes(for: .on)
    }
    private var offMinutes: Int {
        minutes(for: .off)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    FreeTimeMetric(title: "今日", minutes: store.freeMinutes(on: .now))
                    Spacer()
                    FreeTimeMetric(title: "今週", minutes: weekMinutes, prominent: true)
                    Spacer()
                    FreeTimeMetric(title: "今月", minutes: weekMinutes * 4)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("曜日別").font(.headline)
                    Chart {
                        ForEach(values) { value in
                            BarMark(
                                x: .value("日付", value.date, unit: .day),
                                y: .value("空き時間", Double(value.minutes) / 60),
                                width: .ratio(0.7)
                            )
                            .foregroundStyle(Calendar.current.isDateInToday(value.date) ? Color.blue : Color.blue.opacity(0.25))
                            .cornerRadius(5)
                        }
                        RuleMark(y: .value("平均", Double(weekMinutes) / 420))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(dash: [4]))
                    }
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks(values: dates) { value in
                            AxisGridLine()
                            AxisTick()
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date.weekday3Text)
                                }
                            }
                        }
                    }
                    .chartYAxisLabel("時間")
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("時間の内訳").font(.headline)
                    BreakdownRow(title: "空き時間", minutes: weekMinutes, color: .white, outlined: true)
                    BreakdownRow(title: "ON", minutes: onMinutes, color: .blue)
                    BreakdownRow(title: "OFF", minutes: offMinutes, color: Color(.darkGray))
                }

                Label("土日は平日より使える時間が多い傾向です", systemImage: "lightbulb")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .navigationTitle("空き時間")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func minutes(for kind: PlanKind) -> Int {
        var total = 0
        for plan in weekPlans where plan.kind == kind {
            total += Int(plan.end.timeIntervalSince(plan.start) / 60)
        }
        return total
    }
}

private struct BreakdownRow: View {
    let title: String
    let minutes: Int
    let color: Color
    var outlined = false

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .overlay {
                    if outlined {
                        RoundedRectangle(cornerRadius: 4).stroke(.secondary)
                    }
                }
                .frame(width: 18, height: 18)
            Text(title).fontWeight(.semibold)
            Spacer()
            Text(minutes.durationText).foregroundStyle(.secondary)
        }
    }
}
