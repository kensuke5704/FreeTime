import SwiftUI

struct SlotAllocatorView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss

    private let taskID: UUID?
    private let draftTask: FreeTimeTask?
    private let savesTaskOnCommit: Bool
    var completion: (() -> Void)?

    @State private var selected: [DateInterval] = []
    @State private var editingSlot: EditableSlot?

    init(taskID: UUID, completion: (() -> Void)? = nil) {
        self.taskID = taskID
        draftTask = nil
        savesTaskOnCommit = false
        self.completion = completion
    }

    init(
        task: FreeTimeTask,
        savesTaskOnCommit: Bool,
        completion: (() -> Void)? = nil
    ) {
        taskID = nil
        draftTask = task
        self.savesTaskOnCommit = savesTaskOnCommit
        self.completion = completion
    }

    private var task: FreeTimeTask? {
        if let draftTask { return draftTask }
        guard let taskID else { return nil }
        return store.tasks.first { $0.id == taskID }
    }

    private var slots: [DateInterval] {
        guard let task else { return [] }
        return store.availableSlots(before: task.deadline)
            .filter { $0.duration >= 30 * 60 }
            .prefix(20)
            .map { $0 }
    }

    private var selectedMinutes: Int {
        selected.reduce(0) { $0 + Int($1.duration / 60) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let task {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(task.title).font(.headline)
                                Text("残り\(task.remainingMinutes.durationText) ・ 締切 \(task.deadline.formatted(.dateTime.month().day().hour().minute()))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(groupedSlots) { group in
                            Section(group.date.shortDateText) {
                                ForEach(group.slots, id: \.self) { slot in
                                    SlotRow(
                                        slot: slot,
                                        selectedInterval: selectedInterval(in: slot)
                                    ) {
                                        editingSlot = EditableSlot(interval: slot)
                                    }
                                    .listRowBackground(selectedInterval(in: slot) == nil ? nil : Color.blue.opacity(0.08))
                                }
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        VStack(spacing: 10) {
                            HStack {
                                Text("選択 \(selectedMinutes.durationText)")
                                Spacer()
                                Text("必要 \(task.remainingMinutes.durationText)")
                            }
                            .font(.subheadline.weight(.semibold))
                            Button {
                                store.addTaskPlans(
                                    task: task,
                                    intervals: selected,
                                    addTask: savesTaskOnCommit
                                )
                                completion?()
                                dismiss()
                            } label: {
                                Text("予定に追加").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(selected.isEmpty)
                        }
                        .padding()
                        .background(.bar)
                    }
                } else {
                    ContentUnavailableView("課題が見つかりません", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("空き時間に配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $editingSlot) { editableSlot in
                let slot = editableSlot.interval
                SlotTimeEditorView(
                    slot: slot,
                    initial: selectedInterval(in: slot)
                ) { interval in
                    selected.removeAll { sameSlot($0, slot) }
                    selected.append(interval)
                    selected.sort { $0.start < $1.start }
                } onRemove: {
                    selected.removeAll { sameSlot($0, slot) }
                }
            }
        }
    }

    private func selectedInterval(in slot: DateInterval) -> DateInterval? {
        selected.first { sameSlot($0, slot) }
    }

    private func sameSlot(_ interval: DateInterval, _ slot: DateInterval) -> Bool {
        interval.start >= slot.start && interval.end <= slot.end
    }

    private struct SlotGroup: Identifiable {
        let date: Date
        let slots: [DateInterval]
        var id: Date { date }
    }

    private struct EditableSlot: Identifiable {
        let id = UUID()
        let interval: DateInterval
    }

    private var groupedSlots: [SlotGroup] {
        let dictionary = Dictionary(grouping: slots) { Calendar.current.startOfDay(for: $0.start) }
        return dictionary.keys.sorted().map { SlotGroup(date: $0, slots: dictionary[$0] ?? []) }
    }
}

private struct SlotRow: View {
    let slot: DateInterval
    let selectedInterval: DateInterval?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: selectedInterval == nil ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(selectedInterval == nil ? Color.secondary : Color.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(slot.start.timeText)–\(slot.end.timeText)")
                        .fontWeight(.semibold)
                    if let selectedInterval {
                        Text("配置 \(selectedInterval.start.timeText)–\(selectedInterval.end.timeText)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
                Spacer()
                Text(Int(slot.duration / 60).durationText)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SlotTimeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let slot: DateInterval
    let onSave: (DateInterval) -> Void
    let onRemove: () -> Void

    @State private var start: Date
    @State private var end: Date

    init(
        slot: DateInterval,
        initial: DateInterval?,
        onSave: @escaping (DateInterval) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.slot = slot
        self.onSave = onSave
        self.onRemove = onRemove
        _start = State(initialValue: initial?.start ?? slot.start)
        _end = State(initialValue: initial?.end ?? min(
            slot.end,
            Calendar.current.date(byAdding: .hour, value: 1, to: slot.start) ?? slot.end
        ))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("選択した空き時間") {
                    Text("\(slot.start.shortDateText) \(slot.start.timeText)–\(slot.end.timeText)")
                }
                Section("配置する時間") {
                    DatePicker(
                        "開始",
                        selection: $start,
                        in: slot.start...latestStart,
                        displayedComponents: .hourAndMinute
                    )
                    DatePicker(
                        "終了",
                        selection: $end,
                        in: earliestEnd...slot.end,
                        displayedComponents: .hourAndMinute
                    )
                }
                Section {
                    Button("この選択を解除", role: .destructive) {
                        onRemove()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("配置時間を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("決定") {
                        onSave(DateInterval(start: start, end: end))
                        dismiss()
                    }
                }
            }
            .onChange(of: start) { _, newValue in
                if end <= newValue {
                    end = min(slot.end, Calendar.current.date(byAdding: .minute, value: 15, to: newValue) ?? slot.end)
                }
            }
        }
    }

    private var latestStart: Date {
        Calendar.current.date(byAdding: .minute, value: -15, to: slot.end) ?? slot.start
    }

    private var earliestEnd: Date {
        Calendar.current.date(byAdding: .minute, value: 15, to: start) ?? slot.end
    }
}
