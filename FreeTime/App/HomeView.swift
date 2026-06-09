import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var selectedPlan: TimePlan?
    let openAdd: () -> Void

    private var todayPlans: [TimePlan] { store.plans(on: .now) }
    private var upcoming: TimePlan? {
        todayPlans.first { $0.start > .now }
    }
    private var urgentTasks: [FreeTimeTask] {
        store.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.deadline < $1.deadline }
            .prefix(2)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                FreeTimeMetric(title: "空き時間", minutes: store.freeMinutes(on: .now), prominent: true)

                if let upcoming {
                    Label {
                        Text("次の予定  \(upcoming.start.timeText)  \(upcoming.title)")
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("今日")
                        .font(.headline)
                    TimelineHourScale()
                    DayTimeline(date: .now, plans: todayPlans) { plan in
                        selectedPlan = plan
                    }
                        .frame(height: 54)
                }

                if !urgentTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("締切が近い課題")
                            .font(.headline)
                        ForEach(urgentTasks) { task in
                            NavigationLink {
                                TaskDetailView(taskID: task.id)
                            } label: {
                                TaskRow(task: task)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("今日の予定")
                        .font(.headline)
                    if todayPlans.isEmpty {
                        ContentUnavailableView {
                            Label("予定はありません", systemImage: "calendar")
                        } description: {
                            Text("右下の追加ボタンからONまたはOFF予定を登録できます。")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(todayPlans) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(plan.kind == .off ? Color(.darkGray) : plan.color.swiftUIColor)
                                        .frame(width: 5, height: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(plan.title).font(.body.weight(.semibold))
                                        Text("\(plan.start.timeText)–\(plan.end.timeText) ・ \(plan.kind.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }
            .padding()
            .padding(.bottom, 72)
        }
        .navigationTitle("今日")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottomTrailing) {
            AddButton(action: openAdd)
                .padding()
        }
        .sheet(item: $selectedPlan) { plan in
            PlanEditorView(plan: plan)
        }
    }
}
