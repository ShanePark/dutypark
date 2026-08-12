import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var pinningMemberID: MemberID?
    private let refreshID: Int
    private let onRoute: (HomeRoute) -> Void
    private let pinRepository: any SocialRepository

    init(
        service: any HomeDashboardServing = HomeDashboardService(),
        pinRepository: any SocialRepository = LiveSocialRepository(),
        refreshID: Int = 0,
        onRoute: @escaping (HomeRoute) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: HomeViewModel(service: service))
        self.pinRepository = pinRepository
        self.refreshID = refreshID
        self.onRoute = onRoute
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DPSpacing.large) {
                myDashboardPanel
                friendsDashboardPanel
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.large)
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
                    HStack(spacing: DPSpacing.compact) {
                        HomeAvatar(
                            memberId: dashboard.member.id,
                            name: dashboard.member.name,
                            hasProfilePhoto: dashboard.member.hasProfilePhoto,
                            profilePhotoVersion: dashboard.member.profilePhotoVersion,
                            size: 36
                        )
                        Text(dashboard.member.name)
                            .font(DPTypography.heading)
                            .foregroundStyle(DPColor.textOnDark)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DPColor.textOnDarkMuted)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, DPSpacing.compact)
                    .frame(minHeight: 60)
                    .contentShape(Rectangle())
                    .background(HomePanelHeaderBackground())
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
        VStack(alignment: .leading, spacing: 0) {
            Label {
                Text(Date.now, format: .dateTime.year().month(.wide).day().weekday(.wide))
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: "calendar")
                    .font(.system(size: 20))
                    .foregroundStyle(DPColor.textMuted)
            }

            HStack(spacing: DPSpacing.small) {
                Image(systemName: "briefcase")
                    .font(.system(size: 20))
                    .foregroundStyle(DPColor.textMuted)
                Text("home.duty", tableName: "Home")
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textSecondary)
                if let duty = dashboard.duty {
                    DutyBadge(duty: duty)
                } else {
                    Text("home.none", tableName: "Home")
                        .font(DPTypography.body)
                        .foregroundStyle(DPColor.textMuted)
                }
            }
            .padding(.top, DPSpacing.compact)

            Divider()
                .padding(.top, 20)
                .padding(.bottom, DPSpacing.medium)

            Label {
                Text("home.todaySchedules", tableName: "Home")
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
            } icon: {
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 20))
                    .foregroundStyle(DPColor.textMuted)
            }
            .padding(.bottom, DPSpacing.small)

            if dashboard.schedules.isEmpty {
                Text("home.noSchedules", tableName: "Home")
                    .font(DPTypography.label)
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
        .padding(20)
    }

    private var friendsDashboardPanel: some View {
        VStack(spacing: 0) {
            panelHeader(
                title: Text("home.friends", tableName: "Home"),
                systemImage: "person.2.fill",
                count: viewModel.sortedFriends.count
            )

            Group {
                switch viewModel.friendsState {
                case .idle, .loading:
                    loadingState
                case .failed:
                    errorState(title: "home.error.friends") {
                        await viewModel.retryFriendsDashboard()
                    }
                case .loaded:
                    friendsDashboardContent
                }
            }
            .frame(minHeight: 180)
        }
        .homeCard()
    }

    private var friendsDashboardContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            HStack(spacing: DPSpacing.small) {
                RequestSummaryPill(
                    title: "home.requests.received",
                    count: viewModel.receivedRequestCount,
                    systemImage: "tray.and.arrow.down"
                )
                RequestSummaryPill(
                    title: "home.requests.sent",
                    count: viewModel.sentRequestCount,
                    systemImage: "paperplane"
                )
            }
            .padding(.bottom, DPSpacing.small)

            if viewModel.sortedFriends.isEmpty {
                VStack(spacing: DPSpacing.compact) {
                    Image(systemName: "person.2")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(DPColor.textMuted)
                    Text("home.noFriends", tableName: "Home")
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DPSpacing.extraLarge)
                .accessibilityIdentifier("home.friends.empty")
            } else {
                LazyVStack(spacing: DPSpacing.small) {
                    ForEach(viewModel.sortedFriends, id: \.member.id) { friend in
                        FriendSummaryCard(
                            friend: friend,
                            isPinning: pinningMemberID == friend.member.id,
                            openCalendar: { openCalendar(for: friend.member.id) },
                            togglePin: { await togglePin(friend) }
                        )
                    }
                }
            }
        }
        .padding(20)
    }

    private func panelHeader(title: Text, systemImage: String, count: Int? = nil) -> some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
            title.font(DPTypography.bodyMedium)
            if let count, count > 0 {
                Text("\(count)")
                    .font(DPTypography.caption)
                    .padding(.horizontal, DPSpacing.small)
                    .padding(.vertical, 2)
                    .background(DPColor.textOnDark.opacity(0.2))
                    .clipShape(Capsule())
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DPColor.textOnDarkMuted)
        }
        .foregroundStyle(DPColor.textOnDark)
        .padding(.horizontal, count == nil ? 20 : DPSpacing.large)
        .padding(.vertical, DPSpacing.compact)
        .frame(minHeight: count == nil ? 60 : 48)
        .background(HomePanelHeaderBackground())
    }

    private var loadingState: some View {
        VStack(spacing: DPSpacing.small) {
            ProgressView()
                .tint(DPColor.textPrimary)
            Text("home.loading", tableName: "Home")
                .font(DPTypography.label)
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
                .font(DPTypography.heading)
                .multilineTextAlignment(.center)
                .foregroundStyle(DPColor.textPrimary)
            Text("home.error.message", tableName: "Home")
                .font(DPTypography.label)
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

    private func togglePin(_ friend: DashboardFriendDetailDTO) async {
        guard pinningMemberID == nil, let memberID = friend.member.id else { return }
        pinningMemberID = memberID
        defer { pinningMemberID = nil }
        do {
            if friend.pinOrder == nil {
                try await pinRepository.pin(memberID)
            } else {
                try await pinRepository.unpin(memberID)
            }
            await viewModel.retryFriendsDashboard()
        } catch {
            // The card keeps the last confirmed server state when this compact
            // dashboard action fails. Full error handling remains in Friends.
        }
    }
}

private struct HomeScheduleRow: View {
    let schedule: ScheduleDTO

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
            Text(schedule.homeDisplayContent)
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
            Spacer(minLength: DPSpacing.small)
            if let time = schedule.displayTime {
                Text(time)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textMuted)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct FriendSummaryCard: View {
    let friend: DashboardFriendDetailDTO
    let isPinning: Bool
    let openCalendar: () -> Void
    let togglePin: () async -> Void

    var body: some View {
        Button(action: openCalendar) {
            HStack(alignment: .top, spacing: DPSpacing.compact) {
                HomeAvatar(
                    memberId: friend.member.id,
                    name: friend.member.name,
                    hasProfilePhoto: friend.member.hasProfilePhoto,
                    profilePhotoVersion: friend.member.profilePhotoVersion,
                    size: 64
                )

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        HStack(spacing: 6) {
                            Text(friend.member.name)
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                            if friend.isFamily {
                                Image(systemName: "house.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DPColor.warning)
                                    .accessibilityLabel(Text("home.family", tableName: "Home"))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: DPSize.minimumTouchTarget)

                    HStack(spacing: 6) {
                        Image(systemName: "briefcase")
                            .font(.system(size: 14))
                            .foregroundStyle(DPColor.textMuted)
                        Text("home.duty", tableName: "Home")
                            .foregroundStyle(DPColor.textSecondary)
                        if let duty = friend.duty {
                            Text(duty.displayName)
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                        } else {
                            Text("-")
                                .foregroundStyle(DPColor.textMuted)
                        }
                    }
                    .font(DPTypography.caption)

                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        ForEach(friend.schedules.prefix(2), id: \.id) { schedule in
                            Text(schedule.homeDisplayContent)
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.textSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .padding(.vertical, DPSpacing.extraSmall)
                        }
                        if friend.schedules.count > 2 {
                            HStack(spacing: DPSpacing.extraSmall) {
                                Text("+\(friend.schedules.count - 2)")
                                Text("home.moreSchedules", tableName: "Home")
                            }
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .padding(.leading, DPSpacing.extraSmall)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(DPSpacing.compact)
            .padding(.trailing, DPSize.minimumTouchTarget)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            if friend.pinOrder == nil {
                DPColor.backgroundCard
            } else {
                LinearGradient(
                    colors: [DPColor.backgroundSecondary, DPColor.backgroundTertiary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary, lineWidth: friend.pinOrder == nil ? 1 : 2)
        }
        .overlay(alignment: .bottomTrailing) {
            if friend.pinOrder != nil {
                Image(systemName: "line.3.horizontal")
                    .rotationEffect(.degrees(90))
                    .font(.system(size: 16))
                    .foregroundStyle(DPColor.textMuted)
                    .padding(6)
                    .background(DPColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .padding(DPSpacing.small)
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await togglePin() }
            } label: {
                Group {
                    if isPinning {
                        ProgressView()
                            .tint(DPColor.textMuted)
                    } else {
                        Image(systemName: friend.pinOrder == nil ? "star" : "star.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(friend.pinOrder == nil ? DPColor.textMuted : DPColor.warning)
                    }
                }
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isPinning)
            .accessibilityLabel(
                Text(friend.pinOrder == nil ? "social.action.pin" : "social.action.unpin", tableName: "Social")
            )
            .padding(.top, DPSpacing.compact)
            .padding(.trailing, DPSpacing.small)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
        .accessibilityHint(Text("home.openCalendar", tableName: "Home"))
    }
}

private struct RequestSummaryPill: View {
    let title: LocalizedStringKey
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(DPColor.textMuted)
            Text(title, tableName: "Home")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: DPSpacing.extraSmall)
            Text("\(count)")
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(DPColor.textPrimary)
        }
        .padding(.horizontal, DPSpacing.compact)
        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
    }
}

private struct DutyBadge: View {
    let duty: DutyDTO

    var body: some View {
        Text(duty.displayName)
            .font(DPFont.bold(size: 14, relativeTo: .subheadline))
            .foregroundStyle(parsedColor?.isLight == true ? Color.black : Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(parsedColor?.color ?? DPColor.textMuted)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.compact))
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
        .overlay { Circle().stroke(DPColor.borderPrimary, lineWidth: 2) }
        .accessibilityLabel(name)
    }

    private var fallback: some View {
        Image(systemName: "person")
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

    init?(_ value: String?) {
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
    var homeDisplayContent: String {
        var text = content
        if totalDays > 1 {
            text += " [\(daysFromStart)/\(totalDays)]"
        }
        if isTagged {
            text += " (by \(owner))"
        }
        return text
    }

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
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.extraLarge)
                    .stroke(DPColor.borderPrimary)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
    }
}

private struct HomePanelHeaderBackground: View {
    var body: some View {
        LinearGradient(
            colors: [DPColor.surfaceStrong, DPColor.surfaceStrongAlt],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
