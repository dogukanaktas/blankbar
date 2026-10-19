import BlankBarCore
import Foundation

struct LaunchctlError: Error, CustomStringConvertible {
    let description: String
}

/// The per-user launch agent that runs `blankbar daemon` in each login session.
struct LaunchAgent {
    let label = BlankBar.agentLabel
    let domain = "gui/\(getuid())"
    var target: String { "\(domain)/\(label)" }

    var plistURL: URL {
        System.homeDirectory.appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    var isLoaded: Bool {
        Self.launchctl(["print", target]).status == 0
    }

    /// Installed, or still loaded in launchd after its plist was deleted by hand.
    var isPresent: Bool {
        isInstalled || isLoaded
    }

    var runningPID: Int32? {
        let result = Self.launchctl(["print", target])
        guard result.status == 0 else { return nil }
        return LaunchctlOutput.runningPID(inPrint: result.output)
    }

    /// Whether `blankbar on` has paused the agent (`launchctl disable`, which persists).
    var isDisabled: Bool {
        LaunchctlOutput.isDisabled(label: label, inPrintDisabled: Self.launchctl(["print-disabled", domain]).output)
    }

    /// The executable the installed plist starts.
    var installedExecutable: String? {
        guard let data = try? Data(contentsOf: plistURL) else { return nil }
        return LaunchAgentPlist.executable(in: data)
    }

    func writePlist(executable: String) throws {
        let directory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try LaunchAgentPlist.make(label: label, executable: executable)
        try data.write(to: plistURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: plistURL.path)
    }

    func removePlist() throws {
        guard isInstalled else { return }
        try FileManager.default.removeItem(at: plistURL)
    }

    /// Clears a `disable`. Persists across logins.
    func enable() throws {
        try Self.check(Self.launchctl(["enable", target]), doing: "enable the agent")
    }

    /// Stops launchd from loading the agent, now and at future logins, until `enable`.
    func disable() throws {
        try Self.check(Self.launchctl(["disable", target]), doing: "pause the agent")
    }

    /// Loads and starts the agent; restarts it if it is loaded but not running
    /// (stopped by a signal, which KeepAlive {Crashed} does not restart).
    func bootstrap() throws {
        if isLoaded {
            if runningPID == nil { try Self.check(Self.launchctl(["kickstart", target]), doing: "start the agent") }
            return
        }
        let result = Self.launchctl(["bootstrap", domain, plistURL.path])
        guard result.status == 0 || isLoaded else {
            throw LaunchctlError(description: """
                launchctl could not start the background agent: \(result.output.isEmpty ? "exit \(result.status)" : result.output)
                If blankbar is switched off in Login Items (System Settings > General), switch it on and try again.
                """)
        }
    }

    /// Stops and unloads the agent until the next `bootstrap` or login, and waits for it to go.
    func bootout() throws {
        guard isLoaded else { return }
        let result = Self.launchctl(["bootout", target])
        // launchctl returns before launchd has let go of the job; a bootstrap fails until it has.
        var attempts = 0
        while isLoaded && attempts < 100 {
            usleep(100_000)
            attempts += 1
        }
        guard !isLoaded else {
            throw LaunchctlError(description: "launchctl could not stop the background agent: \(result.output)")
        }
    }

    /// Waits up to `timeout` for the daemon to be running.
    func waitUntilRunning(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if runningPID != nil { return true }
            usleep(100_000)
        }
        return runningPID != nil
    }

    private static func check(_ result: (status: Int32, output: String), doing action: String) throws {
        guard result.status == 0 else {
            throw LaunchctlError(description: "launchctl could not \(action): \(result.output.isEmpty ? "exit \(result.status)" : result.output)")
        }
    }

    /// Runs /bin/launchctl and returns its exit status with stdout and stderr combined.
    private static func launchctl(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, "\(error)")
        }
        // Read before waiting: a full pipe would otherwise block launchctl forever.
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return (process.terminationStatus, output)
    }
}
