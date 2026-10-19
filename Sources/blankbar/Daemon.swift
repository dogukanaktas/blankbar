import AppKit
import BlankBarCore
import os

/// Keeps the panel dark: whenever something lights it (login, wake, a user switch back
/// to this session), it is switched off again within milliseconds.
final class Daemon {
    private let touchBar: TouchBar
    private let log = Logger(subsystem: BlankBar.agentLabel, category: "daemon")
    // Normally one switch-off per wake or login. Far more means "off" no longer sticks
    // on this macOS; back off instead of fighting the system in a loop.
    private var limiter = RateLimiter(limit: 10, window: 60)
    private var retryScheduled = false

    init(touchBar: TouchBar) {
        self.touchBar = touchBar
    }

    func run() -> Never {
        touchBar.onStatusChange { [weak self] in
            DispatchQueue.main.async { self?.darkenIfLit(reason: "status change") }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                self?.darkenIfLit(reason: notification.name.rawValue)
            }
        }
        log.notice("blankbar \(BlankBar.version, privacy: .public) started")
        darkenIfLit(reason: "launch")

        // An app run loop, so NSWorkspace delivers its notifications; no Dock icon or menu.
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.run()
        exit(ExitCode.success.rawValue)
    }

    private func darkenIfLit(reason: String) {
        guard System.isSessionOnConsole, !touchBar.isDark else { return }
        // Includes time asleep, so events from earlier wakes expire.
        let now = Double(clock_gettime_nsec_np(CLOCK_MONOTONIC)) / 1e9
        guard limiter.allow(at: now) else {
            scheduleRetry(after: limiter.delayUntilAllowed(at: now))
            return
        }
        if touchBar.set(on: false) {
            log.notice("Touch Bar switched off (\(reason, privacy: .public))")
        } else {
            log.error("DFRBrightnessClient refused to switch the Touch Bar off (\(reason, privacy: .public))")
            // Often the panel is not ready yet right after wake or login; try again.
            scheduleRetry(after: 2)
        }
    }

    private func scheduleRetry(after delay: TimeInterval) {
        guard !retryScheduled else { return }
        retryScheduled = true
        log.error("Touch Bar relit \(self.limiter.limit, privacy: .public) times in \(Int(self.limiter.window), privacy: .public)s; pausing for \(Int(delay), privacy: .public)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 1)) { [weak self] in
            self?.retryScheduled = false
            self?.darkenIfLit(reason: "retry")
        }
    }
}
