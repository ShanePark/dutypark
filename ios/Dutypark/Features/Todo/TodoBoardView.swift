import SwiftUI
import UniformTypeIdentifiers

struct TodoBoardView: View {
    @StateObject private var viewModel = TodoViewModel()
    @Environment(\.colorScheme) var colorScheme
    @State private var showAddTodo = false
    @State private var addTodoStatus: TodoStatus = .todo
    @State private var selectedTodo: Todo?
    @State private var showTodoDetail = false
    @State private var selectedFilter: TodoFilterType = .all
    @State private var draggingTodo: Todo?
    @State private var showHelp = false

    enum TodoFilterType: String, CaseIterable {
        case all = "모든 할일"
        case todo = "할 일"
        case inProgress = "진행중"
        case completed = "완료"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Filter tabs
                    filterTabsSection

                    // Kanban board
                    kanbanBoardSection
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await viewModel.loadTodoBoard()
            }
            .sheet(isPresented: $showAddTodo) {
                AddTodoSheet(viewModel: viewModel, initialStatus: addTodoStatus)
            }
            .sheet(isPresented: $showTodoDetail) {
                if let todo = selectedTodo {
                    TodoDetailSheet(viewModel: viewModel, todo: todo)
                }
            }
            .sheet(isPresented: $showHelp) {
                TodoHelpSheet()
            }
            .task {
                await viewModel.loadTodoBoard()
            }
            .loading(viewModel.isLoading)
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            Text("할일")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

            // Total count badge
            if let total = viewModel.counts?.total {
                Text("\(total)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.accent)
                    .cornerRadius(DesignSystem.CornerRadius.full)
            }

            Spacer()

            // Help button
            Button {
                showHelp = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title3)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Filter Tabs Section
    private var filterTabsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                FilterTabButton(
                    title: "모든 할일",
                    count: viewModel.counts?.total ?? 0,
                    isSelected: selectedFilter == .all,
                    color: .gray
                ) {
                    selectedFilter = .all
                }

                FilterTabButton(
                    title: "할 일",
                    count: viewModel.counts?.todo ?? 0,
                    isSelected: selectedFilter == .todo,
                    color: .blue
                ) {
                    selectedFilter = .todo
                }

                FilterTabButton(
                    title: "진행중",
                    count: viewModel.counts?.inProgress ?? 0,
                    isSelected: selectedFilter == .inProgress,
                    color: .orange
                ) {
                    selectedFilter = .inProgress
                }

                FilterTabButton(
                    title: "완료",
                    count: viewModel.counts?.done ?? 0,
                    isSelected: selectedFilter == .completed,
                    color: .green
                ) {
                    selectedFilter = .completed
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.bottom, DesignSystem.Spacing.lg)
    }

    // MARK: - Kanban Board Section
    private var kanbanBoardSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                // TODO Column
                if selectedFilter == .all || selectedFilter == .todo {
                    KanbanColumn(
                        title: "할 일",
                        icon: "circle",
                        color: .blue,
                        items: viewModel.todoItems,
                        count: viewModel.counts?.todo ?? 0,
                        status: .todo,
                        onAdd: {
                            addTodoStatus = .todo
                            showAddTodo = true
                        },
                        onTap: { todo in
                            selectedTodo = todo
                            showTodoDetail = true
                        },
                        onStatusChange: { todo, newStatus in
                            Task { await viewModel.changeTodoStatus(id: todo.id, newStatus: newStatus) }
                        },
                        draggingTodo: $draggingTodo,
                        onDrop: handleDrop
                    )
                }

                // IN PROGRESS Column
                if selectedFilter == .all || selectedFilter == .inProgress {
                    KanbanColumn(
                        title: "진행중",
                        icon: "clock",
                        color: .orange,
                        items: viewModel.inProgressItems,
                        count: viewModel.counts?.inProgress ?? 0,
                        status: .inProgress,
                        onAdd: {
                            addTodoStatus = .inProgress
                            showAddTodo = true
                        },
                        onTap: { todo in
                            selectedTodo = todo
                            showTodoDetail = true
                        },
                        onStatusChange: { todo, newStatus in
                            Task { await viewModel.changeTodoStatus(id: todo.id, newStatus: newStatus) }
                        },
                        draggingTodo: $draggingTodo,
                        onDrop: handleDrop
                    )
                }

                // DONE Column
                if selectedFilter == .all || selectedFilter == .completed {
                    KanbanColumn(
                        title: "완료",
                        icon: "checkmark.circle",
                        color: .green,
                        items: viewModel.doneItems,
                        count: viewModel.counts?.done ?? 0,
                        status: .done,
                        onAdd: {
                            addTodoStatus = .done
                            showAddTodo = true
                        },
                        onTap: { todo in
                            selectedTodo = todo
                            showTodoDetail = true
                        },
                        onStatusChange: { todo, newStatus in
                            Task { await viewModel.changeTodoStatus(id: todo.id, newStatus: newStatus) }
                        },
                        draggingTodo: $draggingTodo,
                        onDrop: handleDrop
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, 100)
        }
    }

    private func handleDrop(_ todo: Todo, _ status: TodoStatus, _ orderedIds: [String]) {
        Task {
            if todo.status == status {
                _ = await viewModel.updateTodoPositions(status: status, orderedIds: orderedIds)
            } else {
                _ = await viewModel.changeTodoStatus(id: todo.id, newStatus: status, orderedIds: orderedIds)
            }
            draggingTodo = nil
        }
    }
}

// MARK: - Filter Tab Button
struct FilterTabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if isSelected {
                    Image(systemName: "clock")
                        .font(.caption)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(isSelected ? color.opacity(0.3) : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
            }
            .foregroundColor(isSelected ? color : (colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary))
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isSelected ? color.opacity(0.15) : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard))
            .cornerRadius(DesignSystem.CornerRadius.full)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.full)
                    .stroke(isSelected ? color : (colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary), lineWidth: 1)
            )
        }
    }
}

// MARK: - Kanban Column
struct KanbanColumn: View {
    let title: String
    let icon: String
    let color: Color
    let items: [Todo]
    let count: Int
    let status: TodoStatus
    let onAdd: () -> Void
    let onTap: (Todo) -> Void
    let onStatusChange: (Todo, TodoStatus) -> Void
    @Binding var draggingTodo: Todo?
    let onDrop: (Todo, TodoStatus, [String]) -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column Header
            HStack {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundColor(color)

                Text(title)
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                Spacer()

                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xxs)
                    .background(color.opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.subheadline)
                        .foregroundColor(color)
                        .padding(DesignSystem.Spacing.sm)
                        .background(color.opacity(0.15))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.md, corners: [.topLeft, .topRight])

            // Items
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(items) { todo in
                        KanbanCard(todo: todo, columnColor: color) {
                            onTap(todo)
                        }
                        .opacity(draggingTodo?.id == todo.id ? 0.4 : 1)
                        .onDrag {
                            draggingTodo = todo
                            return NSItemProvider(object: todo.id as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: TodoDropDelegate(
                                targetTodo: todo,
                                items: items,
                                status: status,
                                draggingTodo: $draggingTodo,
                                onDrop: onDrop
                            )
                        )
                        .contextMenu {
                            if todo.status != .todo {
                                Button {
                                    onStatusChange(todo, .todo)
                                } label: {
                                    Label("할 일로 이동", systemImage: "circle")
                                }
                            }
                            if todo.status != .inProgress {
                                Button {
                                    onStatusChange(todo, .inProgress)
                                } label: {
                                    Label("진행중으로 이동", systemImage: "clock")
                                }
                            }
                            if todo.status != .done {
                                Button {
                                    onStatusChange(todo, .done)
                                } label: {
                                    Label("완료로 이동", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }

                    // Add button at bottom
                    Button(action: onAdd) {
                        HStack {
                            Image(systemName: "plus")
                                .font(.caption)
                        }
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.lg)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .onDrop(
                    of: [.text],
                    delegate: TodoDropDelegate(
                        targetTodo: nil,
                        items: items,
                        status: status,
                        draggingTodo: $draggingTodo,
                        onDrop: onDrop
                    )
                )
            }
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.md, corners: [.bottomLeft, .bottomRight])
        }
        .frame(width: 300)
        .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 4, x: 0, y: 2)
    }
}

struct TodoDropDelegate: DropDelegate {
    let targetTodo: Todo?
    let items: [Todo]
    let status: TodoStatus
    @Binding var draggingTodo: Todo?
    let onDrop: (Todo, TodoStatus, [String]) -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingTodo else { return false }

        var newItems = items.filter { $0.id != draggingTodo.id }
        if let targetTodo,
           let index = newItems.firstIndex(where: { $0.id == targetTodo.id }) {
            newItems.insert(draggingTodo, at: index)
        } else {
            newItems.append(draggingTodo)
        }

        onDrop(draggingTodo, status, newItems.map { $0.id })
        self.draggingTodo = nil
        return true
    }
}

// MARK: - Kanban Card
struct KanbanCard: View {
    let todo: Todo
    let columnColor: Color
    let onTap: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(todo.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                if !todo.content.isEmpty {
                    Text(todo.content)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                        .lineLimit(2)
                }

                HStack {
                    if let dueDate = todo.dueDate {
                        HStack(spacing: DesignSystem.Spacing.xxs) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(formatDate(dueDate))
                                .font(.caption2)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                        .background(todo.isOverdue ? DesignSystem.Colors.danger.opacity(0.2) : columnColor.opacity(0.2))
                        .foregroundColor(todo.isOverdue ? DesignSystem.Colors.danger : columnColor)
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                    }

                    Spacer()

                    if todo.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "M/d"
        return outputFormatter.string(from: date)
    }
}

#Preview {
    TodoBoardView()
}
