import SwiftUI

struct TaskEditorView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var category = ""
    @State private var deadline = Calendar.current.date(byAdding: .day, value: 1, to: .today(hour: 23, minute: 59)) ?? .now
    @State private var estimatedMinutes = 120
    @State private var priority = 1
    @State private var memo = ""
    @State private var allocateAfterSave = true
    @State private var savedTaskID: UUID?

    var body: some View {
        NavigationStack {
            Form {
                Section("課題") {
                    TextField("タイトル", text: $title)
                    TextField("科目・カテゴリ", text: $category)
                    DatePicker("締切", selection: $deadline, in: Date.now...)
                }
                Section("見積もり") {
                    Stepper(
                        "必要時間  \(estimatedMinutes.durationText)",
                        value: $estimatedMinutes,
                        in: 15...1440,
                        step: 15
                    )
                    Picker("優先度", selection: $priority) {
                        Text("低").tag(0)
                        Text("中").tag(1)
                        Text("高").tag(2)
                    }
                }
                Section {
                    TextField("メモ（任意）", text: $memo, axis: .vertical)
                    Toggle("保存後、空き時間に配置", isOn: $allocateAfterSave)
                }
            }
            .navigationTitle("課題を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(allocateAfterSave ? "保存して配置" : "保存") {
                        let task = FreeTimeTask(
                            title: title.isEmpty ? "新しい課題" : title,
                            category: category.isEmpty ? "未分類" : category,
                            deadline: deadline,
                            estimatedMinutes: estimatedMinutes,
                            priority: priority,
                            memo: memo
                        )
                        store.add(task)
                        if allocateAfterSave {
                            savedTaskID = task.id
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { savedTaskID != nil },
                set: { if !$0 { savedTaskID = nil } }
            )) {
                if let savedTaskID {
                    SlotAllocatorView(taskID: savedTaskID) {
                        dismiss()
                    }
                }
            }
        }
    }
}
