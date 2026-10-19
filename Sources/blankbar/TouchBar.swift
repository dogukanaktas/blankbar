import BlankBarCore
import Foundation

enum TouchBarError: Error, CustomStringConvertible {
    case frameworkMissing(String)
    case symbolMissing(String)

    var description: String {
        switch self {
        case .frameworkMissing(let name): return "\(name).framework could not be loaded"
        case .symbolMissing(let name): return "\(name) is missing"
        }
    }
}

/// The Touch Bar panel, through the two private frameworks macOS itself uses for it:
/// DFRBrightness to switch the panel off and on, DFRFoundation to read and watch its state.
/// Everything is resolved up front, so a macOS that changed them fails here with an
/// error instead of crashing later.
final class TouchBar {
    private typealias GetStatus = @convention(c) () -> Int
    // The callback's argument is the new status. It is ignored and the status re-read,
    // so its exact integer width does not matter.
    private typealias StatusHandler = @convention(block) (Int) -> Void
    private typealias RegisterStatusCallback = @convention(c) (@escaping StatusHandler) -> Void
    private typealias Switch = @convention(c) (AnyObject, Selector) -> Bool

    private static let turnOnSelector = NSSelectorFromString("turnOn")
    private static let turnOffSelector = NSSelectorFromString("turnOff")

    private let getStatus: GetStatus
    private let registerStatusCallback: RegisterStatusCallback
    private let clientClass: NSObject.Type

    init() throws {
        _ = try Self.load("DFRBrightness")
        let foundation = try Self.load("DFRFoundation")

        guard let getStatus = dlsym(foundation, "DFRGetStatus") else {
            throw TouchBarError.symbolMissing("DFRGetStatus")
        }
        guard let register = dlsym(foundation, "DFRRegisterStatusChangeCallback") else {
            throw TouchBarError.symbolMissing("DFRRegisterStatusChangeCallback")
        }
        guard let clientClass = NSClassFromString("DFRBrightnessClient") as? NSObject.Type else {
            throw TouchBarError.symbolMissing("DFRBrightnessClient")
        }
        for selector in [Self.turnOnSelector, Self.turnOffSelector] where !clientClass.instancesRespond(to: selector) {
            throw TouchBarError.symbolMissing("DFRBrightnessClient.\(NSStringFromSelector(selector))")
        }

        self.getStatus = unsafeBitCast(getStatus, to: GetStatus.self)
        self.registerStatusCallback = unsafeBitCast(register, to: RegisterStatusCallback.self)
        self.clientClass = clientClass
    }

    private static func load(_ name: String) throws -> UnsafeMutableRawPointer {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/\(name).framework/\(name)", RTLD_NOW) else {
            throw TouchBarError.frameworkMissing(name)
        }
        return handle
    }

    var isDark: Bool {
        PanelStatus.isDark(getStatus())
    }

    /// Returns false when DFRBrightness refuses the request.
    func set(on: Bool) -> Bool {
        // A new client per call: a client reports the state it last set rather than the
        // panel's, so a kept one cannot be trusted after the system relit the panel.
        let client = clientClass.init()
        let selector = on ? Self.turnOnSelector : Self.turnOffSelector
        return unsafeBitCast(client.method(for: selector), to: Switch.self)(client, selector)
    }

    /// Calls `handler` on a DFRFoundation queue each time the panel's status changes.
    func onStatusChange(_ handler: @escaping () -> Void) {
        registerStatusCallback { _ in handler() }
    }
}
