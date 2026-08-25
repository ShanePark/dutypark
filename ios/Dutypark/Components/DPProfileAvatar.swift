import Combine
import SwiftUI
import UIKit

/// The shape used by a profile avatar. Most member surfaces use a circle, while
/// portrait rails use a rounded rectangle to match the card's crop.
nonisolated enum DPProfileAvatarShape: Sendable {
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
}

nonisolated enum DPProfileAvatarPresentation {
    static let defaultAssetName = "DefaultProfile"

    /// `hasProfilePhoto` comes from the same member/actor payload as the ID. A
    /// false value is authoritative for this render, so photo-less members do
    /// not create a request that can only end in a 404. A missing value means
    /// the payload is older than this contract, so it remains fetchable and a
    /// real photo can still win. A later payload with a new photo (and its
    /// version) changes the view task identity and retries.
    static func profilePhotoURL(
        memberID: MemberID?,
        hasProfilePhoto: Bool?,
        version: Int64
    ) -> URL? {
        guard hasProfilePhoto != false, let memberID else { return nil }
        return AppConfiguration.apiBaseURL
            .appending(path: "members/\(memberID)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(version)),
            ])
    }
}

/// Loads profile photos independently from SwiftUI's lazy view lifetime.
///
/// A lazy container can cancel an image request while a card is being
/// materialized. The loader deliberately does not remember failures, so the
/// next appearance of the same avatar can request the same URL again.
@MainActor
final class DPProfileImageLoader: ObservableObject {
    typealias DataLoader = @Sendable (URL) async throws -> Data

    @Published private(set) var image: UIImage?

    private static let maximumAttempts = 2
    private static let cache: NSCache<NSURL, NSData> = {
        let cache = NSCache<NSURL, NSData>()
        cache.totalCostLimit = 8 * 1024 * 1024
        return cache
    }()
    private let dataLoader: DataLoader
    private var activeRequestID = UUID()

    init(dataLoader: @escaping DataLoader = DPProfileImageLoader.fetchData) {
        self.dataLoader = dataLoader
    }

    /// Requests the supplied URL, retrying a transient transport failure once.
    /// Only successful, decodable responses are cached.
    func load(_ url: URL?) async {
        guard !Task.isCancelled else { return }

        let requestID = UUID()
        activeRequestID = requestID

        guard let url else {
            image = nil
            return
        }

        if let cachedData = Self.cache.object(forKey: url as NSURL) as Data?,
           let cachedImage = UIImage(data: cachedData) {
            image = cachedImage
            return
        }

        image = nil

        for attempt in 0..<Self.maximumAttempts {
            guard !Task.isCancelled else { return }

            do {
                let data = try await dataLoader(url)
                try Task.checkCancellation()

                guard activeRequestID == requestID,
                      let loadedImage = UIImage(data: data) else {
                    return
                }

                Self.cache.setObject(
                    data as NSData,
                    forKey: url as NSURL,
                    cost: data.count
                )
                image = loadedImage
                return
            } catch {
                // A cancelled task must stop immediately. A cancellation error
                // from a still-active request is treated as transient and gets
                // the one bounded retry below.
                guard !Task.isCancelled, activeRequestID == requestID else {
                    return
                }

                if attempt == Self.maximumAttempts - 1 || !Self.shouldRetry(error) {
                    image = nil
                    return
                }
            }
        }
    }

    private static func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.cachePolicy = .useProtocolCachePolicy

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func shouldRetry(_ error: Error) -> Bool {
        guard let error = error as? URLError else { return false }

        switch error.code {
        case .cancelled,
             .timedOut,
             .cannotFindHost,
             .cannotConnectToHost,
             .networkConnectionLost,
             .dnsLookupFailed,
             .notConnectedToInternet,
             .resourceUnavailable:
            return true
        default:
            return false
        }
    }
}

/// A profile image with one app-wide fallback. The fallback intentionally does
/// not include a member initial: names remain text next to the avatar, while
/// the generated silhouette keeps every profile surface visually consistent.
struct DPProfileAvatar: View {
    let memberID: MemberID?
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int64
    let size: CGSize
    var shape: DPProfileAvatarShape = .circle
    @StateObject private var imageLoader: DPProfileImageLoader

    init(
        memberID: MemberID?,
        hasProfilePhoto: Bool?,
        profilePhotoVersion: Int64,
        size: CGFloat,
        shape: DPProfileAvatarShape = .circle
    ) {
        self.memberID = memberID
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
        self.size = CGSize(width: size, height: size)
        self.shape = shape
        _imageLoader = StateObject(wrappedValue: DPProfileImageLoader())
    }

    init(
        memberID: MemberID?,
        hasProfilePhoto: Bool?,
        profilePhotoVersion: Int64,
        size: CGSize,
        shape: DPProfileAvatarShape = .circle
    ) {
        self.memberID = memberID
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
        self.size = size
        self.shape = shape
        _imageLoader = StateObject(wrappedValue: DPProfileImageLoader())
    }

    var body: some View {
        content
            .task(id: photoURL) {
                await imageLoader.load(photoURL)
            }
    }

    private var photoURL: URL? {
        DPProfileAvatarPresentation.profilePhotoURL(
            memberID: memberID,
            hasProfilePhoto: hasProfilePhoto,
            version: profilePhotoVersion
        )
    }

    @ViewBuilder
    private var content: some View {
        let image: Image = if let loadedImage = imageLoader.image {
            Image(uiImage: loadedImage)
        } else {
            Image(DPProfileAvatarPresentation.defaultAssetName)
        }

        switch shape {
        case .circle:
            image
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .background(DPColor.backgroundTertiary)
                .clipShape(Circle())
        case .roundedRectangle(let cornerRadius):
            image
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .background(DPColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
