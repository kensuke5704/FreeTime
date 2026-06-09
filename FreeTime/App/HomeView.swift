import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var selectedPlan: TimePlan?
    @State private var showsOffPlans = true
    let openAdd: () -> Void

    private var todayPlans: [TimePlan] { store.plans(on: .now) }
    private var visibleTodayPlans: [TimePlan] {
        showsOffPlans ? todayPlans : todayPlans.filter { $0.kind == .on }
    }
    private var upcoming: TimePlan? {
        todayPlans.first { $0.start > .now }
    }
    private var urgentTasks: [FreeTimeTask] {
        store.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.deadlineSortValue < $1.deadlineSortValue }
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
                        NavigationLink {
                            AllIncompleteTasksView()
                        } label: {
                            Text("もっと見る")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("今日の予定")
                            .font(.headline)
                        Spacer()
                        Button(showsOffPlans ? "OFFを非表示" : "OFFを表示") {
                            showsOffPlans.toggle()
                        }
                        .font(.caption.weight(.semibold))
                    }
                    if visibleTodayPlans.isEmpty {
                        ContentUnavailableView {
                            Label(
                                todayPlans.isEmpty ? "予定はありません" : "ON予定はありません",
                                systemImage: "calendar"
                            )
                        } description: {
                            Text(
                                todayPlans.isEmpty
                                    ? "右下の追加ボタンからONまたはOFF予定を登録できます。"
                                    : "OFFを表示すると、すべての予定を確認できます。"
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(visibleTodayPlans) { plan in
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

private struct AllIncompleteTasksView: View {
    @EnvironmentObject private var store: FreeTimeStore

    private var tasks: [FreeTimeTask] {
        store.tasks
            .filter { !$0.isCompleted }
            .sorted { $0.deadlineSortValue < $1.deadlineSortValue }
    }

    var body: some View {
        List(tasks) { task in
            NavigationLink {
                TaskDetailView(taskID: task.id)
            } label: {
                TaskRow(task: task)
            }
        }
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView("未完了の課題はありません", systemImage: "checkmark.circle")
            }
        }
        .navigationTitle("未完了の課題")
        .navigationBarTitleDisplayMode(.inline)
    }
}
