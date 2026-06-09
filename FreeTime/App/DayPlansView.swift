import SwiftUI

struct DayPlansView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var selectedPlan: TimePlan?
    let date: Date

    private var plans: [TimePlan] {
        store.plans(on: date)
    }

    var body: some View {
        List {
            Section {
                DayTimeline(date: date, plans: plans) { plan in
                    selectedPlan = plan
                }
                    .frame(height: 64)
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            }

            Section("予定") {
                if plans.isEmpty {
                    ContentUnavailableView(
                        "予定はありません",
                        systemImage: "calendar",
                        description: Text("この日はすべて空き時間です。")
                    )
                } else {
                    ForEach(plans) { plan in
                        Button {
                            selectedPlan = plan
                        } label: {
                            HStack(spacing: 12) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(plan.kind == .off ? Color(.darkGray) : plan.color.swiftUIColor)
                                    .frame(width: 5, height: 38)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(plan.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("\(plan.start.timeText)–\(plan.end.timeText) ・ \(plan.kind.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "pencil")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.month().day().weekday(.wide)))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPlan) { plan in
            PlanEditorView(plan: plan)
        }
    }
}
