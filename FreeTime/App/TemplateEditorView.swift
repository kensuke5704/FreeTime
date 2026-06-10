import SwiftUI

struct TemplateEditorView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss

    private let template: RoutineTemplate?
    @State private var title: String
    @State private var weekdays: Set<Int>
    @State private var items: [TemplateItem]
    @State private var automaticallyApplies: Bool
    @State private var selectedItem: TemplateItem?
    @State private var isAddingItem = false
    @State private var confirmsDeletion = false

    private let weekdayOptions = [
        (2, "MON"), (3, "TUE"), (4, "WED"), (5, "THU"),
        (6, "FRI"), (7, "SAT"), (1, "SUN")
    ]

    init(template: RoutineTemplate? = nil) {
        self.template = template
        _title = State(initialValue: template?.title ?? "")
        _weekdays = State(initialValue: template?.weekdays ?? [])
        _items = State(initialValue: template?.items ?? [])
        _automaticallyApplies = State(initialValue: template?.automaticallyApplies ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("テンプレート") {
                    TextField("名前", text: $title)
                    Toggle("毎週自動反映", isOn: $automaticallyApplies)
                }

                Section("曜日") {
                    HStack(spacing: 8) {
                        ForEach(weekdayOptions, id: \.0) { weekday in
                            Button {
                                if weekdays.contains(weekday.0) {
                                    weekdays.remove(weekday.0)
                                } else {
                                    weekdays.insert(weekday.0)
                                }
                            } label: {
                                Text(weekday.1)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(
                                        weekdays.contains(weekday.0) ? Color.blue : Color(.systemGray6),
                                        in: Circle()
                                    )
                                    .foregroundStyle(weekdays.contains(weekday.0) ? .white : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("時間帯") {
                    ForEach(items.sorted { $0.startMinute < $1.startMinute }) { item in
                        Button {
                            selectedItem = item
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(item.kind == .on ? Color.blue : Color(.darkGray))
                                    .frame(width: 5, height: 32)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .foregroundStyle(.primary)
                                    Text("\(item.startMinute.minuteText)–\(item.endMinute.minuteText) ・ \(item.kind.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        isAddingItem = true
                    } label: {
                        Label("時間帯を追加", systemImage: "plus")
                    }
                }

                if template != nil {
                    Section {
                        Button("テンプレートを削除", role: .destructive) {
                            confirmsDeletion = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(template == nil ? "テンプレートを追加" : "テンプレートを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let updated = RoutineTemplate(
                            id: template?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? "新しいテンプレート"
                                : title,
                            weekdays: weekdays,
                            items: items.sorted { $0.startMinute < $1.startMinute },
                            automaticallyApplies: automaticallyApplies
                        )
                        if template == nil {
                            store.add(updated)
                        } else {
                            store.update(updated)
                        }
                        dismiss()
                    }
                    .disabled(weekdays.isEmpty || items.isEmpty)
                }
            }
            .sheet(isPresented: $isAddingItem) {
                TemplateItemEditorView { item in
                    items.append(item)
                }
            }
            .sheet(item: $selectedItem) { item in
                TemplateItemEditorView(item: item) { updated in
                    guard let index = items.firstIndex(where: { $0.id == updated.id }) else { return }
                    items[index] = updated
                } onDelete: {
                    items.removeAll { $0.id == item.id }
                }
            }
            .confirmationDialog(
                "このテンプレートを削除しますか？",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("削除", role: .destructive) {
                    if let template {
                        store.delete(template)
                    }
                    dismiss()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
}

private struct TemplateItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let item: TemplateItem?
    let onSave: (TemplateItem) -> Void
    var onDelete: (() -> Void)?

    @State private var title: String
    @State private var kind: PlanKind
    @State private var color: PlanColor
    @State private var start: Date
    @State private var end: Date

    init(
        item: TemplateItem? = nil,
        onSave: @escaping (TemplateItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.item = item
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: item?.title ?? "")
        _kind = State(initialValue: item?.kind ?? .off)
        _color = State(initialValue: item?.color ?? .blue)
        _start = State(initialValue: Self.date(for: item?.startMinute ?? 8 * 60))
        _end = State(initialValue: Self.date(for: item?.endMinute ?? 9 * 60))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("種類", selection: $kind) {
                    ForEach(PlanKind.allCases) { kind in
                        Text(kind.rawValue).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                Section("時間帯") {
                    TextField("タイトル", text: $title)
                    FiveMinuteDatePicker(
                        title: "開始",
                        selection: $start,
                        displayedComponents: .time
                    )
                    FiveMinuteDatePicker(
                        title: "終了",
                        selection: $end,
                        displayedComponents: .time
                    )
                }

                if kind == .on {
                    Section("ONの設定") {
                        PlanColorSelector(selection: $color)
                    }
                }

                if item != nil {
                    Section {
                        Button("時間帯を削除", role: .destructive) {
                            onDelete?()
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(item == nil ? "時間帯を追加" : "時間帯を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(TemplateItem(
                            id: item?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? (kind == .on ? "予定" : "使えない時間")
                                : title,
                            startMinute: start.minuteOfDay,
                            endMinute: end.minuteOfDay,
                            kind: kind,
                            color: color
                        ))
                        dismiss()
                    }
                    .disabled(end.minuteOfDay <= start.minuteOfDay)
                }
            }
        }
    }

    private static func date(for minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: .now
        ) ?? .now
    }
}

private extension Date {
    var minuteOfDay: Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

extension Int {
    var minuteText: String {
        String(format: "%02d:%02d", self / 60, self % 60)
    }
}
