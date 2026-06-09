import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var showCompleted = false
    let openAdd: () -> Void

    private var visibleTasks: [FreeTimeTask] {
        store.tasks
            .filter { $0.isCompleted == showCompleted }
            .sorted { $0.deadline < $1.deadline }
    }

    var body: some View {
        List {
            Picker("状態", selection: $showCompleted) {
                Text("未完了").tag(false)
                Text("完了").tag(true)
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            ForEach(groups) { group in
                Section(group.title) {
                    ForEach(group.tasks) { task in
                        NavigationLink {
                            TaskDetailView(taskID: task.id)
                        } label: {
                            TaskRow(task: task)
                        }
                        .swipeActions {
                            Button("削除", role: .destructive) {
                                store.delete(task)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("課題")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: openAdd) {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private struct TaskGroup: Identifiable {
        let title: String
        let tasks: [FreeTimeTask]
        var id: String { title }
    }

    private var groups: [TaskGroup] {
        let calendar = Calendar.current
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: .now) ?? .now
        let inWeek = calendar.date(byAdding: .day, value: 7, to: .now) ?? .now
        return [
            TaskGroup(title: "期限間近", tasks: visibleTasks.filter { $0.deadline <= inThreeDays }),
            TaskGroup(title: "今週", tasks: visibleTasks.filter { $0.deadline > inThreeDays && $0.deadline <= inWeek }),
            TaskGroup(title: "あとで", tasks: visibleTasks.filter { $0.deadline > inWeek })
        ].filter { !$0.tasks.isEmpty }
    }
}

struct TaskDetailView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID
    @State private var showAllocator = false
    @State private var confirmsDeletion = false

    private var task: FreeTimeTask? {
        store.tasks.first { $0.id == taskID }
    }

    var body: some View {
        Group {
            if let task {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label(task.category, systemImage: "folder")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Label(task.deadline.formatted(.dateTime.month().day().hour().minute()), systemImage: "flag.fill")
                                    .foregroundStyle(task.deadline.timeIntervalSinceNow < 86_400 ? .red : .orange)
                            }
                            .font(.subheadline.weight(.semibold))

                            HStack(alignment: .firstTextBaseline) {
                                Text("\(task.completedMinutes.durationText) / \(task.estimatedMinutes.durationText)")
                                    .font(.title2.bold())
                                Spacer()
                                Text("残り\(task.remainingMinutes.durationText)")
                                    .foregroundStyle(.secondary)
                            }
                            ProgressView(value: Double(task.completedMinutes), total: Double(max(1, task.estimatedMinutes)))
                        }

                        if !task.memo.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("メモ").font(.headline)
                                Text(task.memo)
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("配置済みの予定").font(.headline)
                            let linked = store.plans.filter { $0.taskID == task.id }.sorted { $0.start < $1.start }
                            if linked.isEmpty {
                                ContentUnavailableView("まだ配置されていません", systemImage: "calendar.badge.plus")
                                    .frame(maxWidth: .infinity)
                            } else {
                                ForEach(linked) { plan in
                                    Label(
                                        "\(plan.start.shortDateText) \(plan.start.timeText)–\(plan.end.timeText)",
                                        systemImage: "link"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    Divider()
                                }
                            }
                        }

                        Button {
                            showAllocator = true
                        } label: {
                            Label("空き時間に配置", systemImage: "calendar.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            var updated = task
                            updated.isCompleted = true
                            updated.completedMinutes = updated.estimatedMinutes
                            store.update(updated)
                        } label: {
                            Text("完了にする").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button("課題を削除", role: .destructive) {
                            confirmsDeletion = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                }
                .navigationTitle(task.title)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showAllocator) {
                    SlotAllocatorView(taskID: task.id)
                }
                .alert("この課題を削除しますか？", isPresented: $confirmsDeletion) {
                    Button("削除", role: .destructive) {
                        store.delete(task)
                        dismiss()
                    }
                    Button("キャンセル", role: .cancel) {}
                } message: {
                    Text("配置済みの予定も削除されます。")
                }
            } else {
                ContentUnavailableView("課題が見つかりません", systemImage: "exclamationmark.triangle")
            }
        }
    }
}
