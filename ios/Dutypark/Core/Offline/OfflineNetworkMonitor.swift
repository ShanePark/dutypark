import Foundation
import Network
import Combine

/// A path status is only a scheduling hint. The request result remains the
/// source of truth for authentication and server availability.
nonisolated enum OfflineNetworkStatus: Equatable, Sendable {
    case unknown
    case satisfied
    case unsatisfied
    case requiresConnection

    var isSatisfied: Bool { self == .satisfied }
}
/// Owns the process-wide path monitor used to wake offline recovery. It never
/// performs an API request and therefore cannot turn an offline launch into a
/// request storm.
@MainActor
final class OfflineNetworkMonitor: ObservableObject {
    static let shared = OfflineNetworkMonitor()

    @Published private(set) var status: OfflineNetworkStatus = .unknown

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue
    private var isStarted = false

    init(
        monitor: NWPathMonitor = NWPathMonitor(),
        queue: DispatchQueue = DispatchQueue(
            label: "io.github.shanepark.dutypark.offline-network",
            qos: .utility
        )
    ) {
        self.monitor = monitor
        self.queue = queue
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            let status: OfflineNetworkStatus
            switch path.status {
            case .satisfied:
                status = .satisfied
            case .requiresConnection:
                status = .requiresConnection
            case .unsatisfied:
                status = .unsatisfied
            @unknown default:
                status = .unknown
            }
            Task { @MainActor [weak self] in
                self?.status = status
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        guard isStarted else { return }
        monitor.cancel()
        isStarted = false
        status = .unknown
    }

    deinit {
        monitor.cancel()
    }
}
