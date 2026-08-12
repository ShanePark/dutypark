import SwiftUI

struct SocialView: View {
    @StateObject private var viewModel: SocialViewModel
    @State private var isSearchPresented = false
    @State private var confirmation: SocialConfirmation?

    private let onOpenCalendar: (MemberID) -> Void

    init(
        repository: any SocialRepository = LiveSocialRepository(),
        onMutation: @escaping @MainActor (Bool) async -> Void = { _ in },
        onOpenCalendar: @escaping (MemberID) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: SocialViewModel(repository: repository, onMutation: onMutation)
        )
        self.onOpenCalendar = onOpenCalendar
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.friends.isEmpty && !viewModel.hasPendingRequests {
                ProgressView(social("social.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("social.loading")
            } else {
                friendList
            }
        }
        .navigationTitle(social("social.title"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSearchPresented = true
                } label: {
                    Label(social("social.action.addFriend"), systemImage: "person.badge.plus")
                }
                .accessibilityIdentifier("social.addFriend")
            }
            if viewModel.pinnedFriends.count > 1 {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .sheet(isPresented: $isSearchPresented) {
            FriendSearchView(viewModel: viewModel)
        }
        .alert(item: $confirmation) { confirmation in
            confirmationAlert(confirmation)
        }
        .alert(
            social("social.error.title"),
            isPresented: Binding(
                get: { viewModel.errorKey != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(social("social.action.ok")) { viewModel.dismissError() }
        } message: {
            Text(social(viewModel.errorKey ?? "social.error.generic"))
        }
        .disabled(viewModel.isPerformingAction)
    }

    private var friendList: some View {
        List {
            if viewModel.hasPendingRequests {
                Section(social("social.section.requests")) {
                    ForEach(viewModel.receivedRequests, id: \.id) { request in
                        receivedRequestRow(request)
                    }
                    ForEach(viewModel.sentRequests, id: \.id) { request in
                        sentRequestRow(request)
                    }
                }
            }

            if !viewModel.pinnedFriends.isEmpty {
                Section(social("social.section.pinned")) {
                    ForEach(viewModel.pinnedFriends, id: \.member.id) { friend in
                        friendRow(friend)
                    }
                    .onMove { source, destination in
                        Task { await viewModel.movePinned(fromOffsets: source, toOffset: destination) }
                    }
                }
            }

            Section(social("social.section.friends")) {
                if viewModel.friends.isEmpty {
                    VStack(spacing: DPSpacing.medium) {
                        Image(systemName: "person.2")
                            .font(.system(size: 32))
                            .foregroundStyle(DPColor.textMuted)
                        Text(social("social.empty.friends"))
                            .foregroundStyle(DPColor.textSecondary)
                        Button(social("social.action.addFriend")) {
                            isSearchPresented = true
                        }
                        .buttonStyle(DPPrimaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DPSpacing.large)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.unpinnedFriends, id: \.member.id) { friend in
                        friendRow(friend)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .accessibilityIdentifier("social.list")
    }

    private func receivedRequestRow(_ request: FriendRequestDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                SocialAvatar(member: request.fromMember, size: 44)
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text(request.fromMember.name)
                        .font(.body.weight(.semibold))
                    Label(
                        requestTypeLabel(request.requestType),
                        systemImage: request.requestType == .family ? "house.fill" : "person.badge.plus"
                    )
                    .font(.caption)
                    .foregroundStyle(request.requestType == .family ? DPColor.warning : DPColor.accent)
                }
                Spacer()
            }
            HStack(spacing: DPSpacing.small) {
                Button(social("social.action.accept")) {
                    Task { await viewModel.accept(request) }
                }
                .buttonStyle(.borderedProminent)
                .tint(DPColor.success)
                .frame(minHeight: DPSize.minimumTouchTarget)

                Button(social("social.action.reject"), role: .destructive) {
                    confirmation = .reject(request)
                }
                .buttonStyle(.bordered)
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { confirmation = .reject(request) } label: {
                Label(social("social.action.reject"), systemImage: "xmark")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button { Task { await viewModel.accept(request) } } label: {
                Label(social("social.action.accept"), systemImage: "checkmark")
            }
            .tint(DPColor.success)
        }
    }

    private func sentRequestRow(_ request: FriendRequestDTO) -> some View {
        HStack(spacing: DPSpacing.small) {
            SocialAvatar(member: request.toMember, size: 44)
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text(request.toMember.name)
                    .font(.body.weight(.semibold))
                Text(socialFormat("social.request.sent", requestTypeLabel(request.requestType)))
                    .font(.caption)
                    .foregroundStyle(DPColor.textSecondary)
            }
            Spacer()
            Button(social("social.action.cancel")) {
                confirmation = .cancel(request)
            }
            .buttonStyle(.bordered)
            .tint(DPColor.warning)
            .frame(minHeight: DPSize.minimumTouchTarget)
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .swipeActions(allowsFullSwipe: false) {
            Button(role: .destructive) { confirmation = .cancel(request) } label: {
                Label(social("social.action.cancel"), systemImage: "xmark")
            }
        }
    }

    private func friendRow(_ friend: DashboardFriendDetailDTO) -> some View {
        HStack(spacing: DPSpacing.small) {
            SocialAvatar(member: friend.member, size: 52)
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                HStack(spacing: DPSpacing.extraSmall) {
                    Text(friend.member.name)
                        .font(.body.weight(.semibold))
                    if friend.isFamily {
                        Image(systemName: "house.fill")
                            .foregroundStyle(DPColor.warning)
                            .accessibilityLabel(social("social.label.family"))
                    }
                }
                if let team = friend.member.team, !team.isEmpty {
                    Text(team)
                        .font(.caption)
                        .foregroundStyle(DPColor.textSecondary)
                }
                if let duty = friend.duty {
                    Label(
                        duty.dutyType ?? social("social.label.offDuty"),
                        systemImage: "briefcase"
                    )
                    .font(.caption)
                    .foregroundStyle(DPColor.textSecondary)
                }
                ForEach(Array(friend.schedules.prefix(2)), id: \.id) { schedule in
                    Label(scheduleLabel(schedule), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(DPColor.textSecondary)
                        .lineLimit(1)
                }
                if friend.schedules.count > 2 {
                    Text(socialFormat("social.label.moreSchedules", String(friend.schedules.count - 2)))
                        .font(.caption2)
                        .foregroundStyle(DPColor.textMuted)
                }
            }
            Spacer()
            Button {
                Task { await viewModel.togglePin(friend) }
            } label: {
                Image(systemName: friend.pinOrder == nil ? "star" : "star.fill")
                    .foregroundStyle(friend.pinOrder == nil ? DPColor.textMuted : DPColor.warning)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(social(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin"))

            Menu {
                if friend.isFamily {
                    Button {
                        confirmation = .removeFamily(friend)
                    } label: {
                        Label(social("social.action.removeFamily"), systemImage: "person.badge.minus")
                    }
                } else {
                    Button {
                        Task { await viewModel.sendFamilyRequest(to: friend) }
                    } label: {
                        Label(social("social.action.addFamily"), systemImage: "house")
                    }
                }
                Button(role: .destructive) {
                    confirmation = .removeFriend(friend)
                } label: {
                    Label(social("social.action.removeFriend"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .accessibilityLabel(social("social.action.more"))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = friend.member.id { onOpenCalendar(id) }
        }
        .contextMenu {
            Button {
                if let id = friend.member.id { onOpenCalendar(id) }
            } label: {
                Label(social("social.action.openCalendar"), systemImage: "calendar")
            }
            Button {
                Task { await viewModel.togglePin(friend) }
            } label: {
                Label(
                    social(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin"),
                    systemImage: friend.pinOrder == nil ? "star" : "star.slash"
                )
            }
            if friend.isFamily {
                Button { confirmation = .removeFamily(friend) } label: {
                    Label(social("social.action.removeFamily"), systemImage: "person.badge.minus")
                }
            } else {
                Button { Task { await viewModel.sendFamilyRequest(to: friend) } } label: {
                    Label(social("social.action.addFamily"), systemImage: "house")
                }
            }
            Button(role: .destructive) { confirmation = .removeFriend(friend) } label: {
                Label(social("social.action.removeFriend"), systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                Task { await viewModel.togglePin(friend) }
            } label: {
                Label(
                    social(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin"),
                    systemImage: friend.pinOrder == nil ? "star" : "star.slash"
                )
            }
            .tint(DPColor.warning)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { confirmation = .removeFriend(friend) } label: {
                Label(social("social.action.removeFriend"), systemImage: "trash")
            }
            Button {
                if friend.isFamily {
                    confirmation = .removeFamily(friend)
                } else {
                    Task { await viewModel.sendFamilyRequest(to: friend) }
                }
            } label: {
                Label(
                    social(friend.isFamily ? "social.action.removeFamily" : "social.action.addFamily"),
                    systemImage: friend.isFamily ? "person.badge.minus" : "house"
                )
            }
            .tint(DPColor.accent)
        }
    }

    private func confirmationAlert(_ confirmation: SocialConfirmation) -> Alert {
        Alert(
            title: Text(social(confirmation.titleKey)),
            message: Text(socialFormat(confirmation.messageKey, confirmation.memberName)),
            primaryButton: .destructive(Text(social(confirmation.confirmKey))) {
                Task { await perform(confirmation) }
            },
            secondaryButton: .cancel(Text(social("social.action.cancelDialog")))
        )
    }

    private func perform(_ confirmation: SocialConfirmation) async {
        switch confirmation {
        case .reject(let request): await viewModel.reject(request)
        case .cancel(let request): await viewModel.cancel(request)
        case .removeFamily(let friend): await viewModel.removeFromFamily(friend)
        case .removeFriend(let friend): await viewModel.removeFriend(friend)
        }
    }
}

private struct FriendSearchView: View {
    @ObservedObject var viewModel: SocialViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""
    @State private var candidate: SearchCandidate?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    ProgressView(social("social.search.loading"))
                } else if viewModel.searchResults.isEmpty {
                    ContentUnavailableView(
                        social("social.search.empty"),
                        systemImage: "person.crop.circle.badge.magnifyingglass"
                    )
                } else {
                    List(viewModel.searchResults, id: \.id) { member in
                        HStack(spacing: DPSpacing.small) {
                            SocialAvatar(member: member, size: 44)
                            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                                Text(member.name).font(.body.weight(.semibold))
                                if let team = member.team, !team.isEmpty {
                                    Text(team).font(.caption).foregroundStyle(DPColor.textSecondary)
                                }
                            }
                            Spacer()
                            Button(social("social.action.sendRequest")) {
                                candidate = SearchCandidate(member: member)
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(minHeight: DPSize.minimumTouchTarget)
                        }
                    }
                }
            }
            .navigationTitle(social("social.search.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $keyword, prompt: social("social.search.prompt"))
            .onSubmit(of: .search) {
                Task { await viewModel.search(keyword: keyword) }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(social("social.action.close")) { dismiss() }
                }
                if viewModel.searchTotalPages > 1 {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button {
                            Task { await viewModel.search(keyword: keyword, page: viewModel.searchPage - 1) }
                        } label: {
                            Label(social("social.search.previous"), systemImage: "chevron.left")
                        }
                        .disabled(viewModel.searchPage == 0)
                        Spacer()
                        Text(
                            socialFormat(
                                "social.search.page",
                                String(viewModel.searchPage + 1),
                                String(viewModel.searchTotalPages)
                            )
                        )
                        Spacer()
                        Button {
                            Task { await viewModel.search(keyword: keyword, page: viewModel.searchPage + 1) }
                        } label: {
                            Label(social("social.search.next"), systemImage: "chevron.right")
                        }
                        .disabled(viewModel.searchPage + 1 >= viewModel.searchTotalPages)
                    }
                }
            }
            .alert(item: $candidate) { candidate in
                Alert(
                    title: Text(social("social.confirm.sendFriend.title")),
                    message: Text(socialFormat("social.confirm.sendFriend.message", candidate.member.name)),
                    primaryButton: .default(Text(social("social.action.sendRequest"))) {
                        Task { await viewModel.sendFriendRequest(to: candidate.member) }
                    },
                    secondaryButton: .cancel(Text(social("social.action.cancelDialog")))
                )
            }
        }
        .onDisappear { viewModel.clearSearch() }
        .alert(
            social("social.error.title"),
            isPresented: Binding(
                get: { viewModel.errorKey != nil },
                set: { if !$0 { viewModel.dismissError() } }
            )
        ) {
            Button(social("social.action.ok")) { viewModel.dismissError() }
        } message: {
            Text(social(viewModel.errorKey ?? "social.error.generic"))
        }
    }
}

private struct SearchCandidate: Identifiable {
    let member: MemberPreviewDTO
    var id: MemberID { member.id ?? -1 }
}

private struct SocialAvatar: View {
    let member: MemberPreviewDTO
    let size: CGFloat

    var body: some View {
        Group {
            if member.hasProfilePhoto, let id = member.id {
                AsyncImage(url: profileURL(id: id)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    fallback
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        Circle()
            .fill(DPColor.accentSoft)
            .overlay {
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.headline)
                    .foregroundStyle(DPColor.accent)
            }
    }

    private func profileURL(id: MemberID) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(id)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(member.profilePhotoVersion))
            ])
    }
}

private enum SocialConfirmation: Identifiable {
    case reject(FriendRequestDTO)
    case cancel(FriendRequestDTO)
    case removeFamily(DashboardFriendDetailDTO)
    case removeFriend(DashboardFriendDetailDTO)

    var id: String {
        switch self {
        case .reject(let request): "reject-\(request.id)"
        case .cancel(let request): "cancel-\(request.id)"
        case .removeFamily(let friend): "family-\(friend.member.id ?? -1)"
        case .removeFriend(let friend): "friend-\(friend.member.id ?? -1)"
        }
    }

    var memberName: String {
        switch self {
        case .reject(let request): request.fromMember.name
        case .cancel(let request): request.toMember.name
        case .removeFamily(let friend), .removeFriend(let friend): friend.member.name
        }
    }

    var titleKey: String {
        switch self {
        case .reject: "social.confirm.reject.title"
        case .cancel: "social.confirm.cancel.title"
        case .removeFamily: "social.confirm.removeFamily.title"
        case .removeFriend: "social.confirm.removeFriend.title"
        }
    }

    var messageKey: String {
        switch self {
        case .reject: "social.confirm.reject.message"
        case .cancel: "social.confirm.cancel.message"
        case .removeFamily: "social.confirm.removeFamily.message"
        case .removeFriend: "social.confirm.removeFriend.message"
        }
    }

    var confirmKey: String {
        switch self {
        case .reject: "social.action.reject"
        case .cancel: "social.action.cancel"
        case .removeFamily: "social.action.removeFamily"
        case .removeFriend: "social.action.removeFriend"
        }
    }
}

private func requestTypeLabel(_ type: FriendRequestType) -> String {
    social(type == .family ? "social.request.family" : "social.request.friend")
}

private func scheduleLabel(_ schedule: ScheduleDTO) -> String {
    guard schedule.totalDays > 1 else { return schedule.content }
    return "\(schedule.content) [\(schedule.daysFromStart)/\(schedule.totalDays)]"
}

private func social(_ key: String) -> String {
    AppLocalization.string(key, table: "Social")
}

private func socialFormat(_ key: String, _ arguments: CVarArg...) -> String {
    AppLocalization.format(key, table: "Social", arguments: arguments)
}
