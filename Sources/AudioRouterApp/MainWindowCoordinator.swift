import AppKit

@MainActor
final class MainWindowCoordinator {
    private weak var mainWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private var openWindowAction: (() -> Void)?
    private var presentationRequested = false
    private var requestScheduled = false
    private var mainWindowWasClosed = false

    deinit {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }

    func setOpenWindowAction(_ action: @escaping () -> Void) {
        openWindowAction = action
        if presentationRequested {
            schedulePresentation()
        }
    }

    func register(window: NSWindow) {
        if mainWindow !== window {
            if let closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }
            mainWindow = window
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak self, weak window] _ in
                MainActor.assumeIsolated {
                    guard let self, self.mainWindow === window else { return }
                    self.mainWindow = nil
                    self.mainWindowWasClosed = true
                    self.presentationRequested = false
                }
            }
        }

        if presentationRequested {
            DispatchQueue.main.async { [weak self] in
                self?.bringRegisteredWindowForward()
            }
        }
    }

    func showMainWindow() {
        presentationRequested = true
        schedulePresentation()
    }

    func restoreAfterActivationIfNeeded() {
        guard mainWindowWasClosed else { return }
        DispatchQueue.main.async { [weak self] in
            // Allow a menu-bar popover or Settings window to finish opening first.
            guard let self, self.mainWindowWasClosed,
                  !NSApp.windows.contains(where: { $0.isVisible && ($0.canBecomeKey || $0.canBecomeMain) }) else { return }
            self.showMainWindow()
        }
    }

    private func schedulePresentation() {
        guard !requestScheduled, openWindowAction != nil else { return }
        requestScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.requestScheduled = false
            guard self.presentationRequested else { return }

            // SwiftUI owns the scene. Reopen it before touching the native window,
            // which may have been released while the app kept routing in the background.
            self.openWindowAction?()
            self.bringRegisteredWindowForward()
        }
    }

    private func bringRegisteredWindowForward() {
        guard presentationRequested, let window = mainWindow, window.contentView != nil else { return }
        presentationRequested = false
        mainWindowWasClosed = false

        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        let behavior = window.collectionBehavior
        if !window.styleMask.contains(.fullScreen), !behavior.contains(.canJoinAllSpaces) {
            window.collectionBehavior.insert(.moveToActiveSpace)
        }
        window.makeKeyAndOrderFront(nil)
        window.collectionBehavior = behavior
    }
}
