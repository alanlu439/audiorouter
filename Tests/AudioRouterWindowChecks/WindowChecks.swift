import AppKit

@main
enum WindowChecks {
    @MainActor
    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        checkDeferredSceneRegistration()
        checkReleasedWindowReopens()
        checkDelayedWindowCreation()
        checkCloseCancelsPendingPresentation()
        checkActivationRecovery()
        print("AudioRouter window lifecycle checks passed")
    }

    @MainActor
    private static func checkDeferredSceneRegistration() {
        let coordinator = MainWindowCoordinator()
        let scene = TestScene(coordinator: coordinator)
        coordinator.showMainWindow()
        drainEvents()
        precondition(scene.openCount == 0)

        coordinator.setOpenWindowAction { scene.open() }
        drainEvents()
        precondition(scene.openCount == 1, "Early reopen requests must wait for the SwiftUI action")
        precondition(scene.window?.isVisible == true, "Registration must fulfill the pending reopen")
        scene.close()
    }

    @MainActor
    private static func checkReleasedWindowReopens() {
        let coordinator = MainWindowCoordinator()
        let scene = TestScene(coordinator: coordinator)
        coordinator.setOpenWindowAction { scene.open() }

        for iteration in 1...3 {
            coordinator.showMainWindow()
            coordinator.showMainWindow()
            drainEvents()
            precondition(scene.openCount == iteration, "Coalesce simultaneous window requests")
            precondition(scene.window?.isVisible == true, "Reopening must restore a real visible window")

            weak var closedWindow: NSWindow?
            autoreleasepool {
                closedWindow = scene.window
                scene.close()
                precondition(closedWindow?.isVisible != true, "The test must actually close the window")
            }
            drainEvents()
            precondition(closedWindow == nil, "The coordinator must not retain a closed SwiftUI window")
        }

        coordinator.showMainWindow()
        drainEvents()
        let existingWindow = scene.window
        coordinator.showMainWindow()
        drainEvents()
        precondition(scene.window === existingWindow, "A visible singleton scene must not be duplicated")
        scene.window?.orderOut(nil)
        coordinator.showMainWindow()
        drainEvents()
        precondition(scene.window?.isVisible == true, "An ordered-out window must come forward")
        scene.close()
    }

    @MainActor
    private static func checkDelayedWindowCreation() {
        let coordinator = MainWindowCoordinator()
        let scene = TestScene(coordinator: coordinator)
        coordinator.setOpenWindowAction {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { scene.open() }
        }
        coordinator.showMainWindow()
        drainEvents()
        precondition(scene.window?.isVisible == true, "Presentation must wait for asynchronous scene creation")
        scene.close()
    }

    @MainActor
    private static func checkCloseCancelsPendingPresentation() {
        let coordinator = MainWindowCoordinator()
        let scene = TestScene(coordinator: coordinator)
        coordinator.setOpenWindowAction { scene.open() }
        coordinator.showMainWindow()
        drainEvents()
        coordinator.showMainWindow()
        scene.close()
        drainEvents()
        precondition(scene.openCount == 1, "Closing a window must cancel a queued foreground request")
        precondition(scene.window == nil, "Closing must leave AudioRouter in the background")
    }

    @MainActor
    private static func checkActivationRecovery() {
        let coordinator = MainWindowCoordinator()
        let scene = TestScene(coordinator: coordinator)
        coordinator.setOpenWindowAction { scene.open() }
        coordinator.restoreAfterActivationIfNeeded()
        drainEvents()
        precondition(scene.openCount == 0, "Activation alone must not create an unrequested initial window")

        coordinator.showMainWindow()
        drainEvents()
        scene.close()
        coordinator.restoreAfterActivationIfNeeded()
        drainEvents()
        precondition(scene.window?.isVisible == true, "Activation must recover a previously closed main window")
        scene.close()

        let auxiliary = NSPanel(
            contentRect: NSRect(x: 100, y: 100, width: 120, height: 100),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        auxiliary.isReleasedWhenClosed = false
        auxiliary.orderFrontRegardless()
        let openCount = scene.openCount
        coordinator.restoreAfterActivationIfNeeded()
        drainEvents()
        precondition(scene.openCount == openCount, "Opening a menu-bar popover or Settings must not summon the dashboard")
        auxiliary.close()

        let statusWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 1, height: 1),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        statusWindow.isReleasedWhenClosed = false
        statusWindow.level = .statusBar
        statusWindow.orderFrontRegardless()
        precondition(!statusWindow.canBecomeKey && !statusWindow.canBecomeMain)
        coordinator.restoreAfterActivationIfNeeded()
        drainEvents()
        precondition(scene.window?.isVisible == true, "Status-item helper windows must not block activation recovery")
        statusWindow.close()
        scene.close()
    }

    private static func drainEvents() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
    }
}

@MainActor
private final class TestScene {
    weak var coordinator: MainWindowCoordinator?
    var window: NSWindow?
    var openCount = 0

    init(coordinator: MainWindowCoordinator) {
        self.coordinator = coordinator
    }

    func open() {
        openCount += 1
        if window == nil {
            window = NSWindow(
                contentRect: NSRect(x: 100, y: 100, width: 320, height: 200),
                styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false
            )
            window?.isReleasedWhenClosed = false
            window?.title = "AudioRouter Window Checks"
        }
        coordinator?.register(window: window!)
    }

    func close() {
        window?.close()
        window = nil
    }
}
