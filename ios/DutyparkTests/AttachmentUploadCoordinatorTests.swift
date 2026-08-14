import Testing
@testable import Dutypark

@MainActor
@Suite(.serialized)
struct AttachmentUploadCoordinatorTests {
    @Test
    func replacedPreparationCannotClearTheNewPreparationState() async {
        let model = AttachmentPickerModel(contextType: .todo)
        let coordinator = AttachmentUploadCoordinator()
        let probe = AttachmentUploadTaskProbe()

        coordinator.start(model: model) {
            await probe.markFirstStarted()
            do {
                try await Task.sleep(for: .seconds(30))
            } catch {
                try? await Task.sleep(for: .milliseconds(30))
            }
        }
        #expect(await waitUntil { await probe.firstStarted })

        coordinator.start(model: model) {
            await probe.markSecondStarted()
            try? await Task.sleep(for: .seconds(30))
        }
        #expect(await waitUntil { await probe.secondStarted })
        try? await Task.sleep(for: .milliseconds(60))

        #expect(model.isPreparing)
        #expect(model.isBusy)

        coordinator.cancel(model: model)
        #expect(!model.isPreparing)
    }

    private func waitUntil(
        _ condition: @escaping () async -> Bool
    ) async -> Bool {
        for _ in 0..<1_000 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        return false
    }
}

private actor AttachmentUploadTaskProbe {
    private(set) var firstStarted = false
    private(set) var secondStarted = false

    func markFirstStarted() {
        firstStarted = true
    }

    func markSecondStarted() {
        secondStarted = true
    }
}
