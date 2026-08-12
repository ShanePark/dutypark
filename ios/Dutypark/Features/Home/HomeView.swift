import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    private let refreshID: Int
    private let onRoute: (HomeRoute) -> Void

    init(
        service: any HomeDashboardServing = HomeDashboardService(),
        refreshID: Int = 0,
        onRoute: @escaping (HomeRoute) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(service: service))
        self.refreshID = refreshID
        self.onRoute = onRoute
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.large) {
                myDashboardPanel
                friendsDashboardPanel
            }
            .padding(DPSpacing.medium)
        }
        .background(DPColor.backgroundSecondary)
        .task(id: refreshID) {
            if refreshID == 0 {
                await viewModel.loadIfNeeded()
            } else {
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .accessibilityIdentifier("home.dashboard")
    }

    private var myDashboardPanel: some View {
        VStack(spacing: 0) {
            if let dashboard = viewModel.myDashboard {
                Button {
                    openCalendar(for: dashboard.member.id)
                } label: {
                    HStack(spacing: DPSpacing.small) {
                        HomeAvatar(
                            memberId: dashboard.member.id,
                            name: dashboard.member.name,
                            hasProfilePhoto: dashboard.member.hasProfilePhoto,
                            profilePhotoVersion: dashboard.member.profilePhotoVersion,
                            size: 40
                        )
                        Text(dashboard.member.name)
                            .font(.headline)
                            .foregroundStyle(DPColor.textOnDark)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(DPColor.textOnDark.opacity(0.75))
                    }
                    .padding(.horizontal, DPSpacing.medium)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    Text("home.openCalendar", tableName: "Home") + Text(" \(dashboard.member.name)")
                )
            } else {
                panelHeader(title: Text("home.myDashboard", tableName: "Home"), systemImage: "person.fill")
            }

            Group {
                switch viewModel.myState {
                case .idle, .loading:
                    loadingState
                case .failed:
                    errorState(title: "home.error.my") {
                        await viewModel.retryMyDashboard()
                    }
                case .loaded(let dashboard):
                    myDashboardContent(dashboard)
                }
            }
            .frame(minHeight: 150)
        }
        .homeCard()
    }

    private func myDashboardContent(_ dashboard: DashboardMyDetailDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            Label {
                Text(Date.now, format: .dateTime.year().month(.wide).day().weekday(.wide))
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: "calendar")
                    .foregroundStyle(DPColor.textMuted)
            }

            HStack(spacing: DPSpacing.small) {
                Image(systemName: "briefcase")
                    .foregroundStyle(DPColor.textMuted)
                Text("home.duty", tableName: "Home")
                    .foregroundStyle(DPColor.textSecondary)
                if let duty = dashboard.duty {
                    DutyBadge(duty: duty)
                } else {
                    Text("home.none", tableName: "Home")
                        .foregroundStyle(DPColor.textMuted)
                }
            }

            Divider()

            Label {
                Text("home.todaySchedules", tableName: "Home")
                    .font(.headline)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(DPColor.textMuted)
            }

            if dashboard.schedules.isEmpty {
                Text("home.noSchedules", tableName: "Home")
                    .font(.subheadline)
                    .foregroundStyle(DPColor.textMuted)
            } else {
                ForEach(dashboard.schedules, id: \.id) { schedule in
                    HomeScheduleRow(schedule: schedule)
                    if schedule.id != dashboard.schedules.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
    }

    private var friendsDashboardPanel: some View {
        VStack(spacing: 0) {
            panelHeader(title: Text("home.friends", tableName: "Home"), systemImage: "person.2.fill")

            Group {
                switch viewModel.friendsState {
                case .idle, .loading:
                    loadingState
                case .failed:
                    errorState(title: "home.error.friends") {
                        await viewModel.retryFriendsDashboard()
                    }
                case .loaded(let dashboard):
                    friendsDashboardContent(dashboard)
                }
            }
            .frame(minHeight: 180)
        }
        .homeCard()
    }

    private func friendsDashboardContent(_ dashboard: DashboardFriendInfoDTO) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            HStack(spacing: DPSpacing.small) {
                RequestCount(
                    title: "home.requests.received",
                    count: viewModel.receivedRequestCount,
                    systemImage: "tray.and.arrow.down"
                )
                RequestCount(
                    title: "home.requests.sent",
                    count: viewModel.sentRequestCount,
                    systemImage: "paperplane"
                )
            }

            if viewModel.sortedFriends.isEmpty {
                VStack(spacing: DPSpacing.small) {
                    Image(systemName: "person.2")
                        .font(.title)
                        .foregroundStyle(DPColor.textMuted)
                    Text("home.noFriends", tableName: "Home")
                        .font(.subheadline)
                        .foregroundStyle(DPColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DPSpacing.large)
                .accessibilityIdentifier("home.friends.empty")
            } else {
                LazyVStack(spacing: DPSpacing.small) {
                    ForEach(viewModel.sortedFriends, id: \.member.id) { friend in
                        FriendSummaryCard(friend: friend) {
                            openCalendar(for: friend.member.id)
                        }
                    }
                }
            }
        }
        .padding(DPSpacing.medium)
    }

    private func panelHeader(title: Text, systemImage: String) -> some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
            title.font(.headline)
            Spacer()
        }
        .foregroundStyle(DPColor.textOnDark)
        .padding(.horizontal, DPSpacing.medium)
        .frame(minHeight: DPSize.minimumTouchTarget)
        .background(DPColor.accent)
    }

    private var loadingState: some View {
        VStack(spacing: DPSpacing.small) {
            ProgressView()
                .tint(DPColor.accent)
            Text("home.loading", tableName: "Home")
                .font(.subheadline)
                .foregroundStyle(DPColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DPSpacing.large)
        .accessibilityIdentifier("home.loading")
    }

    private func errorState(
        title: LocalizedStringKey,
        retry: @escaping () async -> Void
    ) -> some View {
        VStack(spacing: DPSpacing.medium) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(DPColor.danger)
            Text(title, tableName: "Home")
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(DPColor.textPrimary)
            Text("home.error.message", tableName: "Home")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(DPColor.textSecondary)
            Button {
                Task { await retry() }
            } label: {
                Text("home.retry", tableName: "Home")
            }
            .buttonStyle(DPPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DPSpacing.large)
        .accessibilityIdentifier("home.error")
    }

    private func openCalendar(for memberId: MemberID?) {
        guard let memberId else { return }
        onRoute(.memberCalendar(memberId))
    }
}

private struct HomeScheduleRow: View {
    let schedule: ScheduleDTO

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                Text(schedule.content)
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(2)
                if schedule.totalDays > 1 {
                    Text("\(schedule.daysFromStart)/\(schedule.totalDays)")
                        .font(.caption)
                        .foregroundStyle(DPColor.textMuted)
                }
                if schedule.isTagged {
                    Label(schedule.owner, systemImage: "tag")
                        .font(.caption)
                        .foregroundStyle(DPColor.textSecondary)
                }
            }
            Spacer(minLength: DPSpacing.small)
            if let time = schedule.displayTime {
                Text(time)
                    .font(.subheadline)
                    .foregroundStyle(DPColor.textMuted)
            }
        }
        .padding(.vertical, DPSpacing.extraSmall)
    }
}

private struct FriendSummaryCard: View {
    let friend: DashboardFriendDetailDTO
    let openCalendar: () -> Void

    var body: some View {
        Button(action: openCalendar) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                HomeAvatar(
                    memberId: friend.member.id,
                    name: friend.member.name,
                    hasProfilePhoto: friend.member.hasProfilePhoto,
                    profilePhotoVersion: friend.member.profilePhotoVersion,
                    size: 52
                )

                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    HStack(spacing: DPSpacing.extraSmall) {
                        Text(friend.member.name)
                            .font(.headline)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(1)
                        if friend.isFamily {
                            Image(systemName: "house.fill")
                                .foregroundStyle(DPColor.warning)
                                .accessibilityLabel(Text("home.family", tableName: "Home"))
                        }
                        if friend.pinOrder != nil {
                            Image(systemName: "star.fill")
                                .foregroundStyle(DPColor.warning)
                                .accessibilityHidden(true)
                        }
                    }

                    HStack(spacing: DPSpacing.extraSmall) {
                        Image(systemName: "briefcase")
                            .foregroundStyle(DPColor.textMuted)
                        if let duty = friend.duty {
                            Text(duty.displayName)
                                .foregroundStyle(DPColor.textSecondary)
                                .lineLimit(1)
                        } else {
                            Text("-")
                                .foregroundStyle(DPColor.textMuted)
                        }
                    }
                    .font(.subheadline)

                    ForEach(friend.schedules.prefix(2), id: \.id) { schedule in
                        Text(schedule.content)
                            .font(.caption)
                            .foregroundStyle(DPColor.textSecondary)
                            .lineLimit(1)
                    }
                    if friend.schedules.count > 2 {
                        HStack(spacing: DPSpacing.extraSmall) {
                            Text("+\(friend.schedules.count - 2)")
                            Text("home.moreSchedules", tableName: "Home")
                        }
                        .font(.caption)
                        .foregroundStyle(DPColor.textMuted)
                    }
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(DPColor.textMuted)
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .padding(DPSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(friend.pinOrder == nil ? DPColor.backgroundCard : DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: friend.pinOrder == nil ? 1 : 2)
        }
        .accessibilityHint(Text("home.openCalendar", tableName: "Home"))
    }
}

private struct RequestCount: View {
    let title: LocalizedStringKey
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
                .foregroundStyle(DPColor.textMuted)
            VStack(alignment: .leading, spacing: 2) {
                Text(title, tableName: "Home")
                    .font(.caption)
                    .foregroundStyle(DPColor.textSecondary)
                Text("\(count)")
                    .font(.headline)
                    .foregroundStyle(DPColor.textPrimary)
            }
        }
        .padding(DPSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }
}

private struct DutyBadge: View {
    let duty: DutyDTO

    var body: some View {
        Text(duty.displayName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(parsedColor?.isLight == true ? Color.black : Color.white)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, DPSpacing.extraSmall)
            .background(parsedColor?.color ?? DPColor.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }

    private var parsedColor: HomeHexColor? {
        HomeHexColor(duty.dutyColor)
    }
}

private struct HomeAvatar: View {
    let memberId: MemberID?
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let size: CGFloat

    var body: some View {
        Group {
            if hasProfilePhoto, let url = photoURL {
                AsyncImage(url: url) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .background(DPColor.backgroundTertiary)
        .clipShape(Circle())
        .overlay { Circle().stroke(DPColor.borderPrimary, lineWidth: 1) }
        .accessibilityLabel(name)
    }

    private var fallback: some View {
        Image(systemName: "person.fill")
            .resizable()
            .scaledToFit()
            .padding(size * 0.25)
            .foregroundStyle(DPColor.textMuted)
    }

    private var photoURL: URL? {
        guard let memberId else { return nil }
        var components = URLComponents(
            url: AppConfiguration.apiBaseURL.appending(path: "members/\(memberId)/profile-photo"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: String(profilePhotoVersion))
        ]
        return components?.url
    }
}

private struct HomeHexColor {
    let red: Int
    let green: Int
    let blue: Int

    init?( _ value: String?) {
        guard var value else { return nil }
        value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }
        guard value.count == 6, let rgb = Int(value, radix: 16) else { return nil }
        red = (rgb >> 16) & 0xFF
        green = (rgb >> 8) & 0xFF
        blue = rgb & 0xFF
    }

    var color: Color {
        Color(red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255)
    }

    var isLight: Bool {
        (red * 299 + green * 587 + blue * 114) > 186_000
    }
}

private extension ScheduleDTO {
    var displayTime: String? {
        let value = startDateTime.rawValue
        guard value.count >= 16,
              String(value.prefix(10)) == curDate.rawValue
        else {
            return nil
        }
        let start = value.index(value.startIndex, offsetBy: 11)
        let end = value.index(start, offsetBy: 5)
        let time = String(value[start..<end])
        return time == "00:00" ? nil : time
    }
}

private extension DutyDTO {
    var displayName: String {
        guard let dutyType, !dutyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return String(localized: "home.offDuty", table: "Home")
        }
        return dutyType
    }
}

private extension View {
    func homeCard() -> some View {
        background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(DPColor.borderPrimary)
            }
    }
}
