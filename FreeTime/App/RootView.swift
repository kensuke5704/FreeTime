import SwiftUI

struct RootView: View {
    @State private var selection = 0
    @State private var presentedSheet: AddSheet?

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView(openAdd: { presentedSheet = .chooser }) }
                .tabItem { Label("ホーム", systemImage: "house") }
                .tag(0)

            NavigationStack { WeekView(openAdd: { presentedSheet = .chooser }) }
                .tabItem { Label("週間", systemImage: "calendar") }
                .tag(1)

            NavigationStack { TasksView(openAdd: { presentedSheet = .task }) }
                .tabItem { Label("課題", systemImage: "checklist") }
                .tag(2)

            NavigationStack { TemplatesView() }
                .tabItem { Label("テンプレート", systemImage: "square.on.square") }
                .tag(3)

            NavigationStack { StatsView() }
                .tabItem { Label("集計", systemImage: "chart.bar") }
                .tag(4)
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .chooser:
                AddChooser { choice in presentedSheet = choice }
                    .presentationDetents([.height(230)])
                    .presentationDragIndicator(.visible)
            case .plan:
                PlanEditorView()
            case .task:
                TaskEditorView()
            }
        }
    }
}

enum AddSheet: Int, Identifiable {
    case chooser, plan, task
    var id: Int { rawValue }
}

struct AddChooser: View {
    let select: (AddSheet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("追加")
                .font(.title2.bold())
                .padding(.bottom, 4)
            Button {
                select(.plan)
            } label: {
                Label("予定を追加", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
            Button {
                select(.task)
            } label: {
                Label("課題を追加", systemImage: "checklist.checked")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .buttonStyle(.plain)
        .padding()
    }
}

struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(.blue, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        }
        .accessibilityLabel("追加")
    }
}
