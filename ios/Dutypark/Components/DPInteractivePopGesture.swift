import SwiftUI
import UIKit

enum DPInteractivePopGesturePolicy {
    static func shouldBegin(navigationDepth: Int) -> Bool {
        navigationDepth > 1
    }
}

extension View {
    /// Restores UIKit's edge-pop gesture for pushed screens that intentionally hide
    /// the system navigation bar or back button in favor of custom chrome.
    func dpInteractivePopGestureEnabled() -> some View {
        background(DPInteractivePopGestureBridge())
    }
}

private struct DPInteractivePopGestureBridge: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> DPInteractivePopGestureViewController {
        DPInteractivePopGestureViewController()
    }

    func updateUIViewController(
        _ uiViewController: DPInteractivePopGestureViewController,
        context: Context
    ) {
        uiViewController.enableGestureIfPossible()
    }
}

private final class DPInteractivePopGestureViewController: UIViewController,
    UIGestureRecognizerDelegate {
    private weak var installedNavigationController: UINavigationController?
    private weak var previousDelegate: (any UIGestureRecognizerDelegate)?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableGestureIfPossible()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        restoreGestureIfNeeded()
    }

    func enableGestureIfPossible() {
        guard let navigationController,
              let gesture = navigationController.interactivePopGestureRecognizer,
              DPInteractivePopGesturePolicy.shouldBegin(
                  navigationDepth: navigationController.viewControllers.count
              )
        else { return }

        guard gesture.delegate !== self else {
            gesture.isEnabled = true
            return
        }

        installedNavigationController = navigationController
        previousDelegate = gesture.delegate
        gesture.delegate = self
        gesture.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigationController = installedNavigationController else { return false }
        return DPInteractivePopGesturePolicy.shouldBegin(
            navigationDepth: navigationController.viewControllers.count
        )
    }

    private func restoreGestureIfNeeded() {
        guard let navigationController = installedNavigationController,
              let gesture = navigationController.interactivePopGestureRecognizer
        else {
            installedNavigationController = nil
            previousDelegate = nil
            return
        }

        if gesture.delegate === self {
            gesture.delegate = previousDelegate
            gesture.isEnabled = DPInteractivePopGesturePolicy.shouldBegin(
                navigationDepth: navigationController.viewControllers.count
            )
        }
        installedNavigationController = nil
        previousDelegate = nil
    }
}
