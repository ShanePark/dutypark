import Testing
@testable import Dutypark

@MainActor
@Suite(.serialized)
struct AttachmentUploadCoordinatorTests {
    @Test
    func replacedPreparationCannotClearTheNewPreparationState() async {
        let model = AttachmentPickerModel(contextType: .todo)
        let coordinator = AttachmentUploadCoordinator()
        let gate = AttachmentUploadTaskGate()

        coordinator.start(model: model) {
            await gate.run(.first)
        }
        await gate.waitUntilStarted(.first)

        coordinator.start(model: model) {
            await gate.run(.second)
        }
        await gate.waitUntilStarted(.second)
        await gate.release(.first)
        await gate.waitUntilFinished(.first)
        await Task.yield()

        #expect(model.isPreparing)
        #expect(model.isBusy)

        coordinator.cancel(model: model)
        #expect(!model.isPreparing)
        await gate.release(.second)
    }
}

private actor AttachmentUploadTaskGate {
    enum Operation: Hashable, Sendable {
        case first
        case second
    }

    private var started: Set<Operation> = []
    private var finished: Set<Operation> = []
    private var releases: [Operation: CheckedContinuation<Void, Never>] = [:]
    private var startWaiters: [Operation: [CheckedContinuation<Void, Never>]] = [:]
    private var finishWaiters: [Operation: [CheckedContinuation<Void, Never>]] = [:]

    func run(_ operation: Operation) async {
        started.insert(operation)
        startWaiters.removeValue(forKey: operation)?.forEach { $0.resume() }

        await withCheckedContinuation { continuation in
            releases[operation] = continuation
        }

        finished.insert(operation)
        finishWaiters.removeValue(forKey: operation)?.forEach { $0.resume() }
    }

    func waitUntilStarted(_ operation: Operation) async {
        guard !started.contains(operation) else { return }
        await withCheckedContinuation { continuation in
            startWaiters[operation, default: []].append(continuation)
        }
    }

    func waitUntilFinished(_ operation: Operation) async {
        guard !finished.contains(operation) else { return }
        await withCheckedContinuation { continuation in
            finishWaiters[operation, default: []].append(continuation)
        }
    }

    func release(_ operation: Operation) {
        releases.removeValue(forKey: operation)?.resume()
    }
}
