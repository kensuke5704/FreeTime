import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss
    private let task: FreeTimeTask?
    @State private var title: String
    @State private var category: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var estimatedMinutes: Int
    @State private var memo: String
    @State private var allocateAfterSave: Bool
    @State private var pendingTask: FreeTimeTask?

    init(task: FreeTimeTask? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _category = State(initialValue: task?.category ?? "")
        _hasDeadline = State(initialValue: task?.deadline != nil)
        _deadline = State(
            initialValue: task?.deadline
                ?? Calendar.current.date(byAdding: .day, value: 1, to: .today(hour: 23, minute: 59))
                ?? .now
        )
        _estimatedMinutes = State(initialValue: task?.estimatedMinutes ?? 120)
        _memo = State(initialValue: task?.memo ?? "")
        _allocateAfterSave = State(initialValue: task == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("課題") {
                    TextField("タイトル", text: $title)
                    TextField("科目・カテゴリ", text: $category)
                    Toggle("期限を設定", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("締切", selection: $deadline)
                    } else {
                        LabeledContent("締切", value: "無期限")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("見積もり") {
                    Stepper(
                        "必要時間  \(estimatedMinutes.durationText)",
                        value: $estimatedMinutes,
                        in: 15...1440,
                        step: 15
                    )
                }
                Section {
                    TextField("メモ（任意）", text: $memo, axis: .vertical)
                    if task == nil {
                        Toggle("保存後、空き時間に配置", isOn: $allocateAfterSave)
                    }
                }
            }
            .navigationTitle(task == nil ? "課題を追加" : "課題を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(task == nil && allocateAfterSave ? "保存して配置" : "保存") {
                        let updated = FreeTimeTask(
                            id: task?.id ?? UUID(),
                            title: title.isEmpty ? "新しい課題" : title,
                            category: category.isEmpty ? "未分類" : category,
                            deadline: hasDeadline ? deadline : nil,
                            estimatedMinutes: estimatedMinutes,
                            completedMinutes: task?.completedMinutes ?? 0,
                            priority: task?.priority ?? 1,
                            memo: memo,
                            isCompleted: task?.isCompleted ?? false
                        )
                        if task != nil {
                            store.update(updated)
                            dismiss()
                        } else if allocateAfterSave {
                            pendingTask = updated
                        } else {
                            store.add(updated)
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { pendingTask != nil },
                set: { if !$0 { pendingTask = nil } }
            )) {
                if let pendingTask {
                    SlotAllocatorView(task: pendingTask, savesTaskOnCommit: true) {
                        dismiss()
                    }
                }
            }
        }
    }
}
