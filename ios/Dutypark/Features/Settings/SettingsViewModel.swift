import Foundation
import UIKit
import PhotosUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var profile: MemberDto?
    @Published var refreshTokens: [RefreshTokenDto] = []
    @Published var managers: [SimpleMemberDto] = []
    @Published var isLoading = false
    @Published var isUploadingPhoto = false
    @Published var error: String?

    func loadProfile() async {
        isLoading = true

        do {
            profile = try await APIClient.shared.request(.myProfile, responseType: MemberDto.self)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadRefreshTokens() async {
        do {
            refreshTokens = try await APIClient.shared.request(.refreshTokens, responseType: [RefreshTokenDto].self)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadManagers() async {
        do {
            managers = try await APIClient.shared.request(.managers, responseType: [SimpleMemberDto].self)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateVisibility(_ visibility: CalendarVisibility) async -> Bool {
        guard let memberId = profile?.id else { return false }

        do {
            try await APIClient.shared.requestVoid(.updateVisibility(memberId: memberId, visibility: visibility.rawValue))
            await loadProfile()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteRefreshToken(_ id: Int) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteRefreshToken(id: id))
            await loadRefreshTokens()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deleteOtherRefreshTokens() async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.deleteOtherRefreshTokens)
            await loadRefreshTokens()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        do {
            try await APIClient.shared.requestVoid(.changePassword(memberId: nil, currentPassword: currentPassword, newPassword: newPassword))
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func uploadProfilePhoto(imageData: Data) async -> Bool {
        isUploadingPhoto = true
        do {
            try await APIClient.shared.uploadFile(
                path: "/members/profile-photo",
                method: .put,
                fileData: imageData,
                fileName: "profile.jpg",
                mimeType: "image/jpeg"
            )
            await loadProfile()
            isUploadingPhoto = false
            return true
        } catch {
            self.error = error.localizedDescription
            isUploadingPhoto = false
            return false
        }
    }

    func deleteProfilePhoto() async -> Bool {
        isUploadingPhoto = true
        do {
            try await APIClient.shared.requestVoid(.deleteProfilePhoto)
            await loadProfile()
            isUploadingPhoto = false
            return true
        } catch {
            self.error = error.localizedDescription
            isUploadingPhoto = false
            return false
        }
    }
}
