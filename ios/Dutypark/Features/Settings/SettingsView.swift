import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("isDarkMode") private var isDarkMode = false

    @State private var showLogoutConfirmation = false
    @State private var showChangePassword = false
    @State private var showVisibilityPicker = false
    @State private var showManagersExpanded = false
    @State private var showPhotoOptions = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedCropImage: UIImage?
    @State private var showCropSheet = false
    @State private var showDeletePhotoConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Header
                        Text("내 정보")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Basic Info Section
                        basicInfoSection

                        // Visibility Settings Section
                        visibilitySettingsSection

                        // Theme Settings Section
                        themeSettingsSection

                        // Manager Search Section
                        managerSearchSection

                        // Session Management Section
                        sessionManagementSection

                        // Social Account Section
                        socialAccountSection

                        if authManager.currentUser?.isAdmin == true {
                            adminSection
                        }

                        // Help Section
                        helpSection

                        // Policy Section
                        policySection

                        // Account Management Section
                        accountManagementSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await viewModel.loadProfile()
                    await viewModel.loadRefreshTokens()
                    await viewModel.loadManagers()
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadProfile()
                await viewModel.loadRefreshTokens()
                await viewModel.loadManagers()
            }
            .confirmationDialog("공개 범위 설정", isPresented: $showVisibilityPicker) {
                Button("전체 공개") {
                    Task { await viewModel.updateVisibility(.public) }
                }
                Button("친구 공개") {
                    Task { await viewModel.updateVisibility(.friends) }
                }
                Button("가족 공개") {
                    Task { await viewModel.updateVisibility(.family) }
                }
                Button("비공개") {
                    Task { await viewModel.updateVisibility(.private) }
                }
                Button("취소", role: .cancel) { }
            }
            .alert("로그아웃", isPresented: $showLogoutConfirmation) {
                Button("취소", role: .cancel) { }
                Button("로그아웃", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("로그아웃하시겠습니까?")
            }
            .sheet(isPresented: $showChangePassword) {
                ChangePasswordSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Basic Info Section
    private var basicInfoSection: some View {
        SettingsSection(title: "기본 정보") {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Profile with avatar
                HStack(spacing: DesignSystem.Spacing.lg) {
                    ZStack {
                        Button {
                            showPhotoOptions = true
                        } label: {
                            ProfileAvatar(
                                memberId: viewModel.profile?.id,
                                name: viewModel.profile?.name ?? "?",
                                hasProfilePhoto: viewModel.profile?.hasProfilePhoto ?? false,
                                profilePhotoVersion: viewModel.profile?.profilePhotoVersion,
                                size: 64
                            )
                            .overlay(
                                ZStack {
                                    Circle()
                                        .fill(Color.black.opacity(0.3))
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                                .opacity(viewModel.isUploadingPhoto ? 0 : 1)
                            )
                        }
                        .disabled(viewModel.isUploadingPhoto)

                        if viewModel.isUploadingPhoto {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(viewModel.profile?.name ?? "")
                            .font(.headline)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                        if let team = viewModel.profile?.team {
                            Text(team)
                                .font(.subheadline)
                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)
                        }

                        if let email = viewModel.profile?.email {
                            Text(email)
                                .font(.caption)
                                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                        }
                    }

                    Spacer()
                }
            }
        }
        .confirmationDialog("프로필 사진", isPresented: $showPhotoOptions) {
            Button("사진 선택") {
                showPhotoPicker = true
            }
            if viewModel.profile?.hasProfilePhoto == true {
                Button("사진 삭제", role: .destructive) {
                    showDeletePhotoConfirmation = true
                }
            }
            Button("취소", role: .cancel) { }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem = newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        selectedCropImage = image
                        showCropSheet = true
                    }
                }
                selectedPhotoItem = nil
            }
        }
        .sheet(isPresented: $showCropSheet) {
            if let selectedCropImage {
                ProfilePhotoCropView(
                    image: selectedCropImage,
                    onSave: { cropped in
                        Task {
                            if let jpegData = cropped.jpegData(compressionQuality: 0.8) {
                                await viewModel.uploadProfilePhoto(imageData: jpegData)
                            }
                        }
                    },
                    onDelete: viewModel.profile?.hasProfilePhoto == true ? {
                        showDeletePhotoConfirmation = true
                    } : nil,
                    onSelectAnother: {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            showPhotoPicker = true
                        }
                    }
                )
            }
        }
        .onChange(of: showCropSheet) { _, isPresented in
            if !isPresented {
                selectedCropImage = nil
            }
        }
        .alert("프로필 사진 삭제", isPresented: $showDeletePhotoConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                Task { await viewModel.deleteProfilePhoto() }
            }
        } message: {
            Text("프로필 사진을 삭제하시겠습니까?")
        }
    }

    // MARK: - Visibility Settings Section
    private var visibilitySettingsSection: some View {
        SettingsSection(title: "시간표 공개 설정") {
            Button {
                showVisibilityPicker = true
            } label: {
                HStack {
                    Text("공개 범위")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                    Spacer()

                    if let visibility = viewModel.profile?.calendarVisibility {
                        VisibilityBadge(visibility: visibility)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }
        }
    }

    // MARK: - Theme Settings Section
    private var themeSettingsSection: some View {
        SettingsSection(title: "화면 테마 설정") {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Light mode button
                Button {
                    isDarkMode = false
                    setAppearance(isDark: false)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.orange)
                        Text("라이트")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(!isDarkMode ? DesignSystem.Colors.accent.opacity(0.15) : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary))
                    .foregroundColor(!isDarkMode ? DesignSystem.Colors.accent : (colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .stroke(!isDarkMode ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1)
                    )
                }

                // Dark mode button
                Button {
                    isDarkMode = true
                    setAppearance(isDark: true)
                } label: {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "moon.fill")
                            .foregroundColor(.purple)
                        Text("다크")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(isDarkMode ? DesignSystem.Colors.accent.opacity(0.15) : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary))
                    .foregroundColor(isDarkMode ? DesignSystem.Colors.accent : (colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .stroke(isDarkMode ? DesignSystem.Colors.accent : Color.clear, lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Manager Search Section
    private var managerSearchSection: some View {
        SettingsSection(title: "관리자 찾기") {
            Button {
                withAnimation {
                    showManagersExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("팀 관리자 목록")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                    Spacer()

                    Image(systemName: showManagersExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }

            if showManagersExpanded {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(viewModel.managers, id: \.id) { manager in
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ProfileAvatar(
                                memberId: manager.id,
                                name: manager.name,
                                hasProfilePhoto: manager.hasProfilePhoto ?? false,
                                profilePhotoVersion: manager.profilePhotoVersion,
                                size: 32
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(manager.name)
                                    .font(.subheadline)
                                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                                if let team = manager.team {
                                    Text(team)
                                        .font(.caption)
                                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
                .padding(.top, DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Session Management Section
    private var sessionManagementSection: some View {
        SettingsSection(title: "접속 세션 관리") {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Delete other sessions button
                Button {
                    Task { await viewModel.deleteOtherRefreshTokens() }
                } label: {
                    HStack {
                        Spacer()
                        Text("현재 세션 제외 모두 종료")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.danger.opacity(0.1))
                    .foregroundColor(DesignSystem.Colors.danger)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                // Session list
                ForEach(viewModel.refreshTokens) { token in
                    SessionCardView(token: token) {
                        Task { await viewModel.deleteRefreshToken(token.id) }
                    }
                }
            }
        }
    }

    // MARK: - Social Account Section
    private var socialAccountSection: some View {
        SettingsSection(title: "소셜 계정 연동") {
            HStack {
                // Kakao icon
                Image(systemName: "message.fill")
                    .font(.title3)
                    .foregroundColor(.yellow)
                    .padding(DesignSystem.Spacing.sm)
                    .background(Color.yellow.opacity(0.2))
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                Text("카카오")
                    .font(.subheadline)
                    .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                Spacer()

                if viewModel.profile?.kakaoId != nil {
                    Text("연동됨")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.success)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.success.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                } else {
                    Text("연동 안됨")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }
        }
    }

    // MARK: - Help Section
    private var helpSection: some View {
        SettingsSection(title: "도움말") {
            NavigationLink {
                GuideView()
            } label: {
                settingsRow(icon: "questionmark.circle", title: "이용 안내")
            }
        }
    }

    // MARK: - Admin Section
    private var adminSection: some View {
        SettingsSection(title: "관리자") {
            NavigationLink {
                AdminDashboardView()
            } label: {
                settingsRow(icon: "shield.lefthalf.filled", title: "관리자 대시보드")
            }
        }
    }

    // MARK: - Policy Section
    private var policySection: some View {
        SettingsSection(title: "약관 및 정책") {
            NavigationLink {
                PolicyDetailView(type: .terms)
            } label: {
                settingsRow(icon: "doc.text", title: "이용약관")
            }

            NavigationLink {
                PolicyDetailView(type: .privacy)
            } label: {
                settingsRow(icon: "lock.shield", title: "개인정보 처리방침")
            }
        }
    }

    // MARK: - Account Management Section
    private var accountManagementSection: some View {
        SettingsSection(title: "회원정보 관리") {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Change password button
                if viewModel.profile?.hasPassword == true {
                    Button {
                        showChangePassword = true
                    } label: {
                        HStack {
                            Image(systemName: "key")
                                .font(.subheadline)
                            Text("비밀번호 변경")
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                        .padding(DesignSystem.Spacing.lg)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                }

                // Logout button
                Button {
                    showLogoutConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.subheadline)
                        Text("로그아웃")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .foregroundColor(DesignSystem.Colors.danger)
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.danger.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
    }

    private func settingsRow(icon: String, title: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.subheadline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
        }
        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
        .padding(DesignSystem.Spacing.lg)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    private func setAppearance(isDark: Bool) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
        }
    }
}

// MARK: - Settings Section
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                .textCase(.uppercase)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                content
            }
            .padding(DesignSystem.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
}

// MARK: - Session Card View
struct SessionCardView: View {
    let token: RefreshTokenDto
    let onDelete: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Device icon
            Image(systemName: deviceIcon)
                .font(.title3)
                .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                .frame(width: 40, height: 40)
                .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                .cornerRadius(DesignSystem.CornerRadius.sm)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(deviceDescription)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)

                    if token.isCurrentLogin == true {
                        Text("현재")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.success)
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    }
                }

                if let lastUsed = token.lastUsed {
                    Text(formatDate(lastUsed))
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }

                if let remoteAddr = token.remoteAddr {
                    Text("IP: \(remoteAddr)")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }

            Spacer()

            if token.isCurrentLogin != true {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundColor(DesignSystem.Colors.danger)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.danger.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }

    private var deviceIcon: String {
        guard let userAgent = token.userAgent else { return "questionmark.circle" }
        let os = userAgent.os.lowercased()
        if os.contains("ios") || os.contains("iphone") || os.contains("ipad") {
            return "iphone"
        } else if os.contains("android") {
            return "apps.iphone"
        } else if os.contains("mac") {
            return "laptopcomputer"
        } else if os.contains("windows") {
            return "pc"
        }
        return "desktopcomputer"
    }

    private var deviceDescription: String {
        guard let userAgent = token.userAgent else { return "알 수 없는 기기" }
        return "\(userAgent.os) - \(userAgent.browser)"
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            return outputFormatter.string(from: date)
        }

        return dateString
    }
}

// MARK: - Change Password Sheet
struct ChangePasswordSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Current password
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("현재 비밀번호")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                        SecureField("현재 비밀번호 입력", text: $currentPassword)
                            .textContentType(.password)
                            .padding(DesignSystem.Spacing.lg)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }

                    // New password
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("새 비밀번호")
                            .font(.caption)
                            .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)

                        SecureField("새 비밀번호 입력", text: $newPassword)
                            .textContentType(.newPassword)
                            .padding(DesignSystem.Spacing.lg)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                            .cornerRadius(DesignSystem.CornerRadius.md)

                        SecureField("새 비밀번호 확인", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(DesignSystem.Spacing.lg)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }

                    if newPassword != confirmPassword && !confirmPassword.isEmpty {
                        Text("비밀번호가 일치하지 않습니다")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.danger)
                    }

                    Spacer()
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("비밀번호 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("변경") {
                        changePassword()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValid: Bool {
        !currentPassword.isEmpty &&
        !newPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8
    }

    private func changePassword() {
        isSaving = true
        Task {
            let success = await viewModel.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            if success {
                dismiss()
            } else {
                errorMessage = viewModel.error ?? "비밀번호 변경에 실패했습니다"
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthManager.shared)
}
