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
    @State private var confirmsDeletion = false

    init(plan: TimePlan? = nil, initialDate: Date? = nil) {
        let initialStart = initialDate.flatMap {
            Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: $0)
        } ?? .today(hour: 18)
        let initialEnd = Calendar.current.date(byAdding: .hour, value: 1, to: initialStart)
            ?? .today(hour: 19)

        self.plan = plan
        _title = State(initialValue: plan?.title ?? "")
        _kind = State(initialValue: plan?.kind ?? .on)
        _start = State(initialValue: plan?.start ?? initialStart)
        _end = State(initialValue: plan?.end ?? initialEnd)
        _color = State(initialValue: plan?.color ?? .blue)
        _memo = State(initialValue: plan?.memo ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("種類", selection: $kind) {
                    ForEach(PlanKind.allCases) { kind in Text(kind.rawValue).tag(kind) }
                }
                .pickerStyle(.segmented)

                Section("予定") {
                    TextField("タイトル", text: $title)
                    DatePicker("開始", selection: $start)
                    DatePicker("終了", selection: $end, in: start...)
                }

                if kind == .on {
                    Section("ONの設定") {
                        PlanColorSelector(selection: $color)
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
                            color: color,
                            memo: memo,
                            taskID: plan?.taskID,
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
        HStack {
            Text("色")
            Spacer()
            ForEach(PlanColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(color.swiftUIColor)
                        .frame(width: 28, height: 28)
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
