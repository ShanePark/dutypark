import Foundation
import Testing
@testable import Dutypark

struct DPProfileAvatarTests {
    @Test("profile avatars request only members that advertise a profile photo")
    func presentationUsesSharedAssetAndMemberPhotoURL() throws {
        #expect(DPProfileAvatarPresentation.defaultAssetName == "DefaultProfile")

        let url = try #require(
            DPProfileAvatarPresentation.profilePhotoURL(
                memberID: 42,
                hasProfilePhoto: true,
                version: 7
            )
        )

        #expect(url.path.hasSuffix("/members/42/profile-photo"))
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems == [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: "7"),
        ])
        #expect(
            DPProfileAvatarPresentation.profilePhotoURL(
                memberID: 42,
                hasProfilePhoto: false,
                version: 7
            ) == nil
        )
        #expect(
            DPProfileAvatarPresentation.profilePhotoURL(
                memberID: 42,
                hasProfilePhoto: nil,
                version: 7
            ) != nil
        )
        #expect(
            DPProfileAvatarPresentation.profilePhotoURL(
                memberID: nil,
                hasProfilePhoto: true,
                version: 7
            ) == nil
        )
    }

    @Test("profile image loader retries the same URL after a cancelled request")
    @MainActor
    func loaderRetriesAfterCancelledRequest() async {
        let requestCount = RequestCount()
        let loader = DPProfileImageLoader { _ in
            let count = await requestCount.increment()
            if count == 1 {
                throw URLError(.cancelled)
            }
            return Self.validImageData
        }

        let url = URL(string: "https://dutypark.test/profile-photo/\(UUID().uuidString)")!

        await loader.load(url)

        #expect(await requestCount.value == 2)
        #expect(loader.image != nil)
    }

    @Test("profile image loader stops without retrying when its task is cancelled")
    @MainActor
    func loaderStopsAfterTaskCancellation() async {
        let requestCount = RequestCount()
        let loader = DPProfileImageLoader { _ in
            _ = await requestCount.increment()
            try await Task.sleep(nanoseconds: 60_000_000_000)
            return Self.validImageData
        }

        let url = URL(string: "https://dutypark.test/profile-photo/\(UUID().uuidString)")!
        let loadTask = Task { @MainActor in
            await loader.load(url)
        }

        await requestCount.waitForFirstRequest()
        loadTask.cancel()
        await loadTask.value

        #expect(await requestCount.value == 1)
        #expect(loader.image == nil)
    }

    @Test("profile image loader does not retry a non-transient server response")
    @MainActor
    func loaderDoesNotRetryBadServerResponse() async {
        let requestCount = RequestCount()
        let loader = DPProfileImageLoader { _ in
            _ = await requestCount.increment()
            throw URLError(.badServerResponse)
        }

        let url = URL(string: "https://dutypark.test/profile-photo/\(UUID().uuidString)")!
        await loader.load(url)

        #expect(await requestCount.value == 1)
        #expect(loader.image == nil)
    }

    @Test("a cancelled stale load does not clear the current image when it enters late")
    @MainActor
    func cancelledStaleLoadDoesNotMutateCurrentState() async {
        let requestCount = RequestCount()
        let loader = DPProfileImageLoader { _ in
            _ = await requestCount.increment()
            return Self.validImageData
        }
        let currentURL = URL(string: "https://dutypark.test/profile-photo/\(UUID().uuidString)")!
        let staleURL = URL(string: "https://dutypark.test/profile-photo/\(UUID().uuidString)")!

        await loader.load(currentURL)
        #expect(loader.image != nil)

        let gate = SuspensionGate()
        let staleTask = Task { @MainActor in
            await gate.wait()
            await loader.load(staleURL)
        }
        await gate.waitUntilSuspended()
        staleTask.cancel()
        await gate.resume()
        await staleTask.value

        #expect(await requestCount.value == 1)
        #expect(loader.image != nil)
    }

    nonisolated private static let validImageData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    private actor RequestCount {
        private var count = 0
        private var firstRequestContinuation: CheckedContinuation<Void, Never>?

        func increment() -> Int {
            count += 1
            firstRequestContinuation?.resume()
            firstRequestContinuation = nil
            return count
        }

        func waitForFirstRequest() async {
            guard count == 0 else { return }
            await withCheckedContinuation { continuation in
                firstRequestContinuation = continuation
            }
        }

        var value: Int { count }
    }

    private actor SuspensionGate {
        private var waitContinuation: CheckedContinuation<Void, Never>?
        private var suspendedContinuation: CheckedContinuation<Void, Never>?
        private var isSuspended = false

        func wait() async {
            isSuspended = true
            suspendedContinuation?.resume()
            suspendedContinuation = nil
            await withCheckedContinuation { continuation in
                waitContinuation = continuation
            }
        }

        func waitUntilSuspended() async {
            guard !isSuspended else { return }
            await withCheckedContinuation { continuation in
                suspendedContinuation = continuation
            }
        }

        func resume() {
            waitContinuation?.resume()
            waitContinuation = nil
        }
    }
}
