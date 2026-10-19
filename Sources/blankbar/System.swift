import BlankBarCore
import CoreGraphics
import Foundation
import os

enum System {
    /// `hw.model`, e.g. "MacBookPro17,1".
    static var model: String? {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static var hasTouchBar: Bool {
        model.map(Hardware.hasTouchBar) ?? false
    }

    /// The path this binary was started from, as given to exec (symlinks not resolved).
    static var executablePath: String {
        var size: UInt32 = 0
        _ = _NSGetExecutablePath(nil, &size)
        var buffer = [CChar](repeating: 0, count: Int(size))
        guard _NSGetExecutablePath(&buffer, &size) == 0 else { return CommandLine.arguments[0] }
        return String(cString: buffer)
    }

    /// `path` with every symlink resolved, or nil if it does not exist.
    static func resolve(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// stat(2) of `path` and each of its ancestors; lstat for the path itself when
    /// `followLast` is false, so a symlink is judged by who can replace the link.
    static func ownershipChain(_ path: String, followLast: Bool) -> [FileOwnership]? {
        var entries: [FileOwnership] = []
        let chain = ExecutablePath.chain(path)
        for (index, component) in chain.enumerated() {
            var info = stat()
            let isLast = index == chain.count - 1
            let result = isLast && !followLast ? lstat(component, &info) : stat(component, &info)
            guard result == 0 else { return nil }
            entries.append(FileOwnership(
                path: component, uid: info.st_uid, gid: info.st_gid,
                mode: UInt16(info.st_mode & 0o7777), isDirectory: info.st_mode & S_IFMT == S_IFDIR))
        }
        return entries
    }

    /// This user, root and members of the admin group: anyone who can take over the
    /// account anyway, so their write access to the agent's binary adds no risk.
    static var trustedUIDs: Set<UInt32> {
        var uids: Set<UInt32> = [getuid(), 0]
        guard let group = getgrnam("admin"), var member = group.pointee.gr_mem else { return uids }
        while let name = member.pointee {
            if let user = getpwnam(name) { uids.insert(user.pointee.pw_uid) }
            member += 1
        }
        return uids
    }

    /// Whether this process's login session owns the screen, and with it the Touch Bar.
    /// With fast user switching, another user's agent must not darken this user's bar.
    static var isSessionOnConsole: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return true }
        return (session[kCGSessionOnConsoleKey] as? Bool) ?? true
    }

    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }
}

/// Opens the Touch Bar after checking this Mac has one, or exits with a clear message.
func requireTouchBar() -> TouchBar {
    guard let model = System.model else {
        Output.fail("could not read this Mac's model", code: .unavailable)
    }
    guard Hardware.hasTouchBar(model: model) else {
        Output.fail("this Mac (\(model)) does not have a Touch Bar", code: .unavailable)
    }
    do {
        return try TouchBar()
    } catch {
        Output.fail("""
            this version of macOS does not provide the private interface blankbar uses (\(error)).
            Please report it with your Mac model and macOS version: https://github.com/dogukanaktas/blankbar/issues
            """, code: .unavailable)
    }
}

enum Output {
    static let log = Logger(subsystem: BlankBar.agentLabel, category: "cli")

    static func print(_ message: String) {
        Swift.print(message)
    }

    static func warn(_ message: String) {
        FileHandle.standardError.write(Data("blankbar: warning: \(message)\n".utf8))
    }

    /// Prints the error and records it in the unified log, where the daemon's errors are
    /// the only trace (launchd discards its stderr).
    static func fail(_ message: String, code: ExitCode = .failure) -> Never {
        log.error("\(message, privacy: .public)")
        FileHandle.standardError.write(Data("blankbar: error: \(message)\n".utf8))
        exit(code.rawValue)
    }
}
