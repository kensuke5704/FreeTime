import SwiftUI

struct PlanEditorView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss
    private let plan: TimePlan?
    @State private var title: String
    @State private var kind: PlanKind
    @State private var start: Date
    @State private var end: Date
    @State private var color: PlanColor
    @State private var memo: String
    @State private var taskID: UUID?
    @State private var confirmsDeletion = false

    init(plan: TimePlan? = nil, initialDate: Date? = nil, initialStart: Date? = nil) {
        let defaultStart = initialStart ?? initialDate.flatMap {
            Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: $0)
        } ?? .today(hour: 18)
        let initialEnd = Calendar.current.date(byAdding: .hour, value: 1, to: defaultStart)
            ?? .today(hour: 19)

        self.plan = plan
        _title = State(initialValue: plan?.title ?? "")
        _kind = State(initialValue: plan?.kind ?? .on)
        _start = State(initialValue: plan?.start ?? defaultStart)
        _end = State(initialValue: plan?.end ?? initialEnd)
        _color = State(initialValue: plan?.color ?? .blue)
        _memo = State(initialValue: plan?.memo ?? "")
        _taskID = State(initialValue: plan?.taskID)
    }

    private var selectableTasks: [FreeTimeTask] {
        store.tasks
            .filter { !$0.isCompleted || $0.id == taskID }
            .sorted {
                if $0.deadlineSortValue != $1.deadlineSortValue {
                    return $0.deadlineSortValue < $1.deadlineSortValue
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
    }

    private var selectedTask: FreeTimeTask? {
        store.tasks.first { $0.id == taskID }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("種類", selection: $kind) {
                    ForEach(PlanKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }
                .pickerStyle(.segmented)

                Section("予定") {
                    TextField("タイトル", text: Binding(
                        get: { title },
                        set: { newTitle in
                            title = newTitle
                            if let selectedTask = store.tasks.first(where: { $0.id == taskID }),
                               newTitle != selectedTask.title {
                                taskID = nil
                            }
                        }
                    ))

                    if kind == .on, !selectableTasks.isEmpty {
                        Picker("未完了の課題から選ぶ", selection: $taskID) {
                            Text("選択しない").tag(nil as UUID?)
                            ForEach(selectableTasks) { task in
                                Text(task.title).tag(task.id as UUID?)
                            }
                        }
                        .onChange(of: taskID) { _, newTaskID in
                            guard let task = store.tasks.first(where: { $0.id == newTaskID }) else {
                                return
                            }
                            title = task.title
                            color = task.color
                        }

                        if taskID != nil {
                            Text("この予定の時間は、選択した課題の配置済み時間に反映されます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    FiveMinuteDatePicker(title: "開始", selection: $start)
                    FiveMinuteDatePicker(
                        title: "終了",
                        selection: $end,
                        range: start...Date.distantFuture
                    )
                }

                if kind == .on {
                    Section("ONの設定") {
                        PlanColorSelector(selection: $color)
                            .disabled(selectedTask != nil)
                        if let selectedTask {
                            Text("課題の色（\(selectedTask.color.accessibilityName)）を使用します。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField("メモ（任意）", text: $memo, axis: .vertical)
                    }
                }

                if plan != nil {
                    Section {
                        Button {
                            duplicatePlan()
                        } label: {
                            Label("予定を複製", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

                        Button("予定を削除", role: .destructive) {
                            confirmsDeletion = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(plan == nil ? "予定を追加" : "予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(plan == nil ? "追加" : "保存") {
                        let updated = TimePlan(
                            id: plan?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? (kind == .on ? "予定" : "予定あり") : title,
                            start: start,
                            end: end,
                            kind: kind,
                            color: selectedTask?.color ?? color,
                            memo: memo,
                            taskID: kind == .on ? taskID : nil,
                            sourceTemplateID: plan?.sourceTemplateID,
                            sourceTemplateItemID: plan?.sourceTemplateItemID
                        )
                        if plan == nil {
                            store.add(updated)
                        } else {
                            store.update(updated)
                        }
                        dismiss()
                    }
                    .disabled(end <= start)
                }
            }
            .alert("この予定を削除しますか？", isPresented: $confirmsDeletion) {
                Button("削除", role: .destructive) {
                    if let plan {
                        store.delete(plan)
                    }
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("削除した予定は元に戻せません。")
            }
        }
    }

    private func duplicatePlan() {
        guard let plan else { return }
        store.add(TimePlan(
            title: plan.title,
            start: plan.start,
            end: plan.end,
            kind: plan.kind,
            color: plan.color,
            memo: plan.memo,
            taskID: plan.taskID
        ))
        dismiss()
    }
}

struct PlanColorSelector: View {
    @Binding var selection: PlanColor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("色")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                ForEach(PlanColor.allCases) { color in
                    Button {
                        selection = color
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                            Circle()
                                .fill(color.swiftUIColor.opacity(0.85))
                        }
                            .frame(width: 30, height: 30)
                            .overlay {
                                if selection == color {
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }
                            }
                            .overlay {
                                Circle()
                                    .stroke(selection == color ? Color.primary : Color.clear, lineWidth: 2)
                                    .padding(-3)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(color.accessibilityName)
                }
            }
        }
    }
}
