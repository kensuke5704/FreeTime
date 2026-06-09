import SwiftUI

struct TemplatesView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var selectedTemplate: RoutineTemplate?
    @State private var isAddingTemplate = false

    var body: some View {
        List {
            if store.templates.isEmpty {
                ContentUnavailableView {
                    Label("テンプレートはありません", systemImage: "square.on.square")
                } description: {
                    Text("よく使う曜日と時間帯を登録できます。")
                } actions: {
                    Button("テンプレートを追加") {
                        isAddingTemplate = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(store.templates) { template in
                    Button {
                        selectedTemplate = template
                    } label: {
                        TemplateRow(template: template)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    let templates = offsets.map { store.templates[$0] }
                    for template in templates {
                        store.delete(template)
                    }
                }
            }
        }
        .navigationTitle("テンプレート")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingTemplate = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingTemplate) {
            TemplateEditorView()
        }
        .sheet(item: $selectedTemplate) { template in
            TemplateEditorView(template: template)
        }
    }
}

private struct TemplateRow: View {
    let template: RoutineTemplate

    private let weekdays = [
        (2, "MON"), (3, "TUE"), (4, "WED"), (5, "THU"),
        (6, "FRI"), (7, "SAT"), (1, "SUN")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(template.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text(template.automaticallyApplies ? "自動反映" : "手動")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(template.automaticallyApplies ? .blue : .secondary)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 7) {
                ForEach(weekdays, id: \.0) { weekday in
                    Text(weekday.1)
                        .font(.caption.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(
                            template.weekdays.contains(weekday.0) ? Color.blue : Color(.systemGray6),
                            in: Circle()
                        )
                        .foregroundStyle(template.weekdays.contains(weekday.0) ? .white : .secondary)
                }
            }

            ForEach(template.items.prefix(3)) { item in
                HStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(item.kind == .on ? item.color.swiftUIColor : Color(.darkGray))
                        .frame(width: 4, height: 18)
                    Text(item.title)
                    Text(item.kind.rawValue)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(item.kind == .on ? .blue : .secondary)
                    Spacer()
                    Text("\(item.startMinute.minuteText)–\(item.endMinute.minuteText)")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            if template.items.count > 3 {
                Text("ほか\(template.items.count - 3)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
