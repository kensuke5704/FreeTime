import SwiftUI

struct SlotAllocatorView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID
    var completion: (() -> Void)?
    @State private var selected: Set<DateInterval> = []

    private var task: FreeTimeTask? { store.tasks.first { $0.id == taskID } }
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
                                    Button {
                                        if selected.contains(slot) {
                                            selected.remove(slot)
                                        } else {
                                            selected.insert(slot)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: selected.contains(slot) ? "checkmark.circle.fill" : "circle")
                                                .foregroundStyle(selected.contains(slot) ? .blue : .secondary)
                                            Text("\(slot.start.timeText)–\(slot.end.timeText)")
                                                .fontWeight(.semibold)
                                            Spacer()
                                            Text(Int(slot.duration / 60).durationText)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(selected.contains(slot) ? Color.blue.opacity(0.08) : nil)
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
                                for slot in selected {
                                    store.addTaskPlan(task: task, start: slot.start, end: slot.end)
                                }
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
        }
    }

    private struct SlotGroup: Identifiable {
        let date: Date
        let slots: [DateInterval]
        var id: Date { date }
    }

    private var groupedSlots: [SlotGroup] {
        let dictionary = Dictionary(grouping: slots) { Calendar.current.startOfDay(for: $0.start) }
        return dictionary.keys.sorted().map { SlotGroup(date: $0, slots: dictionary[$0] ?? []) }
    }
}
