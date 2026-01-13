import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    @State private var showNotifications = false
    @State private var showMenu = false
    @State private var showFriends = false
    @State private var showScheduleList = false
    @State private var showDDayList = false
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Card Section
                        if let myDetail = viewModel.myDetail {
                            profileCardSection(myDetail)
                        }

                        // Today's Schedule Section
                        todayScheduleSection

                        // Friends Management Section
                        friendsManagementSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.loadDashboard()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Dutypark")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.accent)
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Theme toggle button
                    Button(action: {}) {
                        Image(systemName: colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(colorScheme == .dark ? .yellow : .orange)
                    }

                    // Notification button
                    NotificationBellButton(action: { showNotifications = true })
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)

                    // Menu button
                    Button(action: { showMenu = true }) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                    }
                }
            }
            .task {
                await viewModel.loadDashboard()
            }
            .loading(viewModel.isLoading && viewModel.myDetail == nil)
            .sheet(isPresented: $showNotifications) {
                NotificationListView()
            }
            .confirmationDialog("메뉴", isPresented: $showMenu) {
                Button("친구 관리") {
                    showFriends = true
                }

                Button("일정 목록") {
                    showScheduleList = true
                }

                Button("D-Day 관리") {
                    showDDayList = true
                }

                Button("이용 안내") {
                    showGuide = true
                }

                Button("알림") {
                    showNotifications = true
                }

                Button("로그아웃", role: .destructive) {
                    authManager.logout()
                }

                Button("취소", role: .cancel) {}
            }
            .sheet(isPresented: $showFriends) {
                NavigationStack {
                    FriendsView()
                }
            }
            .sheet(isPresented: $showScheduleList) {
                NavigationStack {
                    ScheduleListView()
                }
            }
            .sheet(isPresented: $showDDayList) {
                NavigationStack {
                    DDayListView()
                }
            }
            .sheet(isPresented: $showGuide) {
                NavigationStack {
                    GuideView()
                }
            }
        }
    }

    // MARK: - Profile Card Section
    private func profileCardSection(_ detail: DashboardMyDetail) -> some View {
        VStack(spacing: 0) {
            // Profile Header (Clickable)
            NavigationLink(destination: SettingsView()) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ProfileAvatar(
                        memberId: detail.member.id,
                        name: detail.member.name,
                        hasProfilePhoto: detail.member.hasProfilePhoto ?? false,
                        profilePhotoVersion: detail.member.profilePhotoVersion,
                        size: 44
                    )

                    Text(detail.member.name)
                        .font(.headline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                .cornerRadius(DesignSystem.CornerRadius.md, corners: [.topLeft, .topRight])
            }
            .buttonStyle(.plain)

            // Info Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Date
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                    Text(formattedToday())
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                }

                // Duty Status
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "building.2")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                    Text("근무:")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)

                    if let duty = detail.duty {
                        DutyBadge(
                            dutyType: duty.dutyType,
                            dutyColor: duty.dutyColor,
                            isOff: duty.isOff,
                            size: .small
                        )
                    } else {
                        Text("없음")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.lg)
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.md, corners: [.bottomLeft, .bottomRight])
        }
        .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 4, x: 0, y: 2)
    }

    // MARK: - Today's Schedule Section
    private var todayScheduleSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar.badge.clock")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                Text("오늘 일정")
                    .font(.headline)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
            }
            .padding(.top, DesignSystem.Spacing.xl)

            // Schedule Content
            if let schedules = viewModel.myDetail?.schedules, !schedules.isEmpty {
                ForEach(schedules) { schedule in
                    DashboardScheduleCard(schedule: schedule)
                }
            } else {
                Text("오늘의 일정이 없습니다.")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Friends Management Section
    private var friendsManagementSection: some View {
        VStack(spacing: 0) {
            // Section Header
            NavigationLink(destination: FriendsView()) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "person.2")
                        .font(.subheadline)
                        .foregroundColor(.white)

                    Text("친구관리")
                        .font(.headline)
                        .foregroundColor(.white)

                    // Count badge
                    Text("\(viewModel.allFriends.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.friendListHeader)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xxs)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(DesignSystem.CornerRadius.sm)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.friendListHeader)
                .cornerRadius(DesignSystem.CornerRadius.md, corners: [.topLeft, .topRight])
            }
            .buttonStyle(.plain)
            .padding(.top, DesignSystem.Spacing.xl)

            // Friend Requests Section (if any)
            if !viewModel.receivedRequests.isEmpty || !viewModel.sentRequests.isEmpty {
                friendRequestsSection
            }

            // Friends List
            VStack(spacing: 0) {
                ForEach(viewModel.allFriends, id: \.member.id) { friend in
                    let friendModel = Friend(from: friend)
                    NavigationLink {
                        DutyView(member: friendModel)
                    } label: {
                        FriendListCard(
                            friend: friend,
                            onTogglePin: {
                                Task {
                                    if friend.pinOrder != nil {
                                        await viewModel.unpinFriend(memberId: friend.member.id ?? 0)
                                    } else {
                                        await viewModel.pinFriend(memberId: friend.member.id ?? 0)
                                    }
                                }
                            }
                        )
                    }
                    .buttonStyle(.plain)

                    if friend.member.id != viewModel.allFriends.last?.member.id {
                        Divider()
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary)
                    }
                }
            }
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.md, corners: [.bottomLeft, .bottomRight])
            .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Friend Requests Section
    private var friendRequestsSection: some View {
        VStack(spacing: 0) {
            // Received requests
            ForEach(viewModel.receivedRequests) { request in
                DashboardRequestCard(
                    request: request,
                    isReceived: true,
                    onAccept: {
                        Task { await viewModel.acceptFriendRequest(fromMemberId: request.fromMember.id ?? 0) }
                    },
                    onReject: {
                        Task { await viewModel.rejectFriendRequest(fromMemberId: request.fromMember.id ?? 0) }
                    },
                    onCancel: {}
                )
            }

            // Sent requests
            ForEach(viewModel.sentRequests) { request in
                DashboardRequestCard(
                    request: request,
                    isReceived: false,
                    onAccept: {},
                    onReject: {},
                    onCancel: {
                        Task { await viewModel.cancelFriendRequest(toMemberId: request.toMember.id ?? 0) }
                    }
                )
            }
        }
        .background(DesignSystem.Colors.friendRequestHeader.opacity(0.1))
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일 EEEE"
        return formatter.string(from: Date())
    }
}

// MARK: - Friend List Card
struct FriendListCard: View {
    let friend: DashboardFriendDetail
    let onTogglePin: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ProfileAvatar(
                memberId: friend.member.id,
                name: friend.member.name,
                hasProfilePhoto: friend.member.hasProfilePhoto ?? false,
                profilePhotoVersion: friend.member.profilePhotoVersion,
                size: 44
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(friend.member.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                    if friend.isFamily {
                        Image(systemName: "house.fill")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                }

                // Duty status
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "building.2")
                        .font(.caption2)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                    Text("근무:")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                    if let duty = friend.duty {
                        if duty.isOff {
                            Text("OFF")
                                .font(.caption)
                                .foregroundColor(.gray)
                        } else if let dutyType = duty.dutyType {
                            Text(dutyType)
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                        }
                    } else {
                        Text("없음")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    }
                }
            }

            Spacer()

            // Pin star button
            Button(action: onTogglePin) {
                Image(systemName: friend.pinOrder != nil ? "star.fill" : "star")
                    .font(.body)
                    .foregroundColor(friend.pinOrder != nil ? .orange : (colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted))
            }

            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - Dashboard Schedule Card
struct DashboardScheduleCard: View {
    let schedule: DashboardScheduleDto
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Time indicator
            if schedule.startDateTime != schedule.endDateTime {
                Text(formatTime(schedule.startDateTime))
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .frame(width: 44, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(schedule.content)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                if !schedule.description.isEmpty {
                    Text(schedule.description)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                        .lineLimit(2)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    if schedule.isTagged {
                        Label(schedule.owner, systemImage: "person")
                            .font(.caption2)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                    }

                    if schedule.totalDays > 1 {
                        Text("[\(schedule.daysFromStart)/\(schedule.totalDays)]")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

                    if let visibility = schedule.visibility {
                        VisibilityBadge(visibility: visibility)
                    }
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 2, x: 0, y: 1)
    }

    private func formatTime(_ dateTimeString: String) -> String {
        if dateTimeString.contains("T") {
            let parts = dateTimeString.split(separator: "T")
            if parts.count == 2 {
                let timePart = String(parts[1])
                let timeComponents = timePart.split(separator: ":")
                if timeComponents.count >= 2 {
                    return "\(timeComponents[0]):\(timeComponents[1])"
                }
            }
        }
        return ""
    }
}

// MARK: - Dashboard Request Card
struct DashboardRequestCard: View {
    let request: DashboardFriendRequestDto
    let isReceived: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    let onCancel: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            let member = isReceived ? request.fromMember : request.toMember

            ProfileAvatar(
                memberId: member.id,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto ?? false,
                profilePhotoVersion: member.profilePhotoVersion,
                size: 40
            )

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                if let team = member.team {
                    Text(team)
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }

            Spacer()

            if isReceived {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button(action: onReject) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.danger)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.danger.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    }

                    Button(action: onAccept) {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.success)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.success.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    }
                }
            } else {
                Button(action: onCancel) {
                    Text("취소")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.warning)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.warning.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager.shared)
}
