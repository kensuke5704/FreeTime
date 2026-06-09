import SwiftUI
import UniformTypeIdentifiers

struct TemplatesView: View {
    @EnvironmentObject private var store: FreeTimeStore
    @State private var selectedTemplate: RoutineTemplate?
    @State private var isAddingTemplate = false
    @State private var backupDocument = FreeTimeBackupDocument()
    @State private var isExportingBackup = false
    @State private var isImportingBackup = false
    @State private var pendingImportData: Data?
    @State private var confirmsRestore = false
    @State private var backupMessage: String?

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

            Section("機種変更・バックアップ") {
                LabeledContent {
                    Text(automaticBackupText)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("自動バックアップ", systemImage: "arrow.triangle.2.circlepath")
                }

                Button {
                    exportBackup()
                } label: {
                    Label("バックアップを書き出す", systemImage: "square.and.arrow.up")
                }

                Button {
                    isImportingBackup = true
                } label: {
                    Label("バックアップを読み込む", systemImage: "square.and.arrow.down")
                }

                Text("データ変更時に端末内へ自動保存します。iCloudバックアップを有効にしている場合は、機種変更時の復元対象になります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .fileExporter(
            isPresented: $isExportingBackup,
            document: backupDocument,
            contentType: .json,
            defaultFilename: "FreeTime-backup"
        ) { result in
            if case .failure(let error) = result {
                backupMessage = "書き出しに失敗しました。\n\(error.localizedDescription)"
            }
        }
        .fileImporter(
            isPresented: $isImportingBackup,
            allowedContentTypes: [.json]
        ) { result in
            importBackup(result)
        }
        .alert("バックアップを復元しますか？", isPresented: $confirmsRestore) {
            Button("復元", role: .destructive) {
                restorePendingBackup()
            }
            Button("キャンセル", role: .cancel) {
                pendingImportData = nil
            }
        } message: {
            Text("現在の予定・課題・テンプレートは、バックアップの内容に置き換わります。")
        }
        .alert(
            "バックアップ",
            isPresented: Binding(
                get: { backupMessage != nil },
                set: { if !$0 { backupMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(backupMessage ?? "")
        }
    }

    private var automaticBackupText: String {
        guard let date = store.lastAutomaticBackupDate else { return "未保存" }
        return date.formatted(.dateTime.month().day().hour().minute())
    }

    private func exportBackup() {
        do {
            backupDocument = FreeTimeBackupDocument(data: try store.backupData())
            isExportingBackup = true
        } catch {
            backupMessage = "バックアップを作成できませんでした。\n\(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            pendingImportData = try Data(contentsOf: url)
            confirmsRestore = true
        } catch {
            backupMessage = "バックアップを読み込めませんでした。\n\(error.localizedDescription)"
        }
    }

    private func restorePendingBackup() {
        guard let data = pendingImportData else { return }
        defer { pendingImportData = nil }
        do {
            try store.restoreBackup(from: data)
            backupMessage = "バックアップを復元しました。"
        } catch {
            backupMessage = "復元に失敗しました。\n\(error.localizedDescription)"
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
